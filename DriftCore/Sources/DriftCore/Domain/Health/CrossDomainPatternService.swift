import Foundation

/// One detected cross-domain pattern — a statistically meaningful
/// correlation between two on-device daily metrics over a window.
public struct CrossDomainPattern: Sendable, Equatable {
    public let metricA: String
    public let metricB: String
    public let r: Double
    public let n: Int
    public let windowDays: Int
    public let summary: String

    public init(
        metricA: String,
        metricB: String,
        r: Double,
        n: Int,
        windowDays: Int,
        summary: String
    ) {
        self.metricA = metricA
        self.metricB = metricB
        self.r = r
        self.n = n
        self.windowDays = windowDays
        self.summary = summary
    }
}

/// Unordered pair of metric keys — `(a, b) == (b, a)`. Used so we don't
/// scan the same pair twice and can put it in a `Set` for the excluded list.
public struct UnorderedMetricPair: Hashable, Sendable {
    public let a: String
    public let b: String
    public init(_ x: String, _ y: String) {
        if x <= y { self.a = x; self.b = y } else { self.a = y; self.b = x }
    }
}

/// Proactive cross-domain pattern detector. Scans the matrix of paired
/// daily series across food/weight/exercise/glucose, returns the strongest
/// statistically-significant correlations the user hasn't asked about. #739.
///
/// Filter: `|r| ≥ minR` AND `n ≥ minPairs` AND `p < alpha` via a two-tailed
/// Fisher z-transform test. Sleep & biomarker domains aren't included yet
/// — sleep historical data lives in HealthKit (async, out of scope) and
/// biomarkers are sparse lab reports, not daily series.
@MainActor
public enum CrossDomainPatternService {

    /// Metrics with on-device daily resolution. Mirrors
    /// `CrossDomainInsightTool.supportedMetrics` minus the pending entries.
    nonisolated static let scannedMetrics: [String] = [
        "weight", "calories", "protein", "carbs", "fat", "fiber",
        "workout_volume", "glucose_avg"
    ]

    /// Pairs that are trivially correlated by definition (`calories ≈
    /// 4·protein + 4·carbs + 9·fat`) — reporting them is noise, not signal.
    nonisolated static let excludedPairs: Set<UnorderedMetricPair> = [
        UnorderedMetricPair("calories", "protein"),
        UnorderedMetricPair("calories", "carbs"),
        UnorderedMetricPair("calories", "fat"),
    ]

    nonisolated static let minR: Double = 0.4
    nonisolated static let minPairs: Int = 14
    nonisolated static let alpha: Double = 0.05
    nonisolated static let maxResults: Int = 3

    // MARK: - Public entry points

    /// Detect the top patterns over the given window. Returns 0–3 patterns
    /// sorted by descending `|r|`. Empty = nothing strong enough to report.
    ///
    /// Applies a Bonferroni correction across pairs that *actually have
    /// enough data to test* — not the enumerated pair count. Users without
    /// a CGM shouldn't pay a correction penalty for the 7 pairs touching
    /// `glucose_avg` they could never test anyway.
    ///
    /// Implementation fetches each metric's daily series once and reuses
    /// it across all pairs — 8 DB reads instead of one per pair.
    public static func detect(windowDays: Int = 30, now: Date = Date()) -> [CrossDomainPattern] {
        let (start, end) = CrossDomainInsightTool.dateWindow(windowDays: windowDays, now: now)
        var seriesByMetric: [String: [String: Double]] = [:]
        for metric in scannedMetrics {
            seriesByMetric[metric] = CrossDomainInsightTool.fetchDailySeries(
                metric: metric, startDate: start, endDate: end
            )
        }
        let testable = generatePairs().filter { a, b in
            let aKeys = seriesByMetric[a]?.keys ?? Dictionary<String, Double>().keys
            let bKeys = seriesByMetric[b]?.keys ?? Dictionary<String, Double>().keys
            return Set(aKeys).intersection(bKeys).count >= minPairs
        }
        let adjustedAlpha = alpha / Double(max(testable.count, 1))
        var detected: [CrossDomainPattern] = []
        for (a, b) in testable {
            if let p = analyzePure(
                metricA: a, metricB: b,
                seriesA: seriesByMetric[a] ?? [:],
                seriesB: seriesByMetric[b] ?? [:],
                windowDays: windowDays,
                alpha: adjustedAlpha
            ) {
                detected.append(p)
            }
        }
        return Array(
            detected
                .sorted { abs($0.r) > abs($1.r) }
                .prefix(maxResults)
        )
    }

    /// Analyze one specific pair against on-device data. Public so the
    /// dashboard card or tests can probe individual pairs. `alpha` defaults
    /// to the uncorrected level — `detect` passes a Bonferroni-corrected
    /// value when scanning all pairs at once.
    public static func analyze(metricA: String, metricB: String, windowDays: Int, now: Date = Date(), alpha: Double = 0.05) -> CrossDomainPattern? {
        guard metricA != metricB else { return nil }
        if excludedPairs.contains(UnorderedMetricPair(metricA, metricB)) { return nil }
        let (start, end) = CrossDomainInsightTool.dateWindow(windowDays: windowDays, now: now)
        let seriesA = CrossDomainInsightTool.fetchDailySeries(metric: metricA, startDate: start, endDate: end)
        let seriesB = CrossDomainInsightTool.fetchDailySeries(metric: metricB, startDate: start, endDate: end)
        return analyzePure(
            metricA: metricA, metricB: metricB,
            seriesA: seriesA, seriesB: seriesB,
            windowDays: windowDays,
            alpha: alpha
        )
    }

    // MARK: - Pure analysis (no DB)

    /// DB-free version. Takes two metric→value series keyed by date,
    /// inner-joins on shared dates, and returns a pattern when all
    /// thresholds pass. Used by tests for deterministic stats coverage.
    /// `alpha` defaults to the uncorrected level; multi-pair callers
    /// (i.e. `detect`) pass a Bonferroni-corrected value.
    nonisolated static func analyzePure(
        metricA: String,
        metricB: String,
        seriesA: [String: Double],
        seriesB: [String: Double],
        windowDays: Int,
        alpha: Double = CrossDomainPatternService.alpha
    ) -> CrossDomainPattern? {
        let shared = Set(seriesA.keys).intersection(seriesB.keys).sorted()
        guard shared.count >= minPairs else { return nil }
        let xs = shared.compactMap { seriesA[$0] }
        let ys = shared.compactMap { seriesB[$0] }
        guard xs.count == shared.count, ys.count == shared.count else { return nil }
        guard let r = CrossDomainInsightTool.pearsonR(xs: xs, ys: ys) else { return nil }
        guard abs(r) >= minR else { return nil }
        guard isSignificant(r: r, n: xs.count, alpha: alpha) else { return nil }
        let summary = formatPattern(
            metricA: metricA, metricB: metricB,
            r: r, n: xs.count, windowDays: windowDays
        )
        return CrossDomainPattern(
            metricA: metricA, metricB: metricB,
            r: r, n: xs.count, windowDays: windowDays,
            summary: summary
        )
    }

    // MARK: - Statistical significance

    /// Two-tailed Fisher z-transform significance test for Pearson r.
    /// `z = atanh(r) · sqrt(n − 3)`; `|z| ≥ criticalZ(alpha)` → reject H₀.
    nonisolated static func isSignificant(r: Double, n: Int, alpha: Double) -> Bool {
        guard n >= 4 else { return false }
        if abs(r) >= 1.0 { return true }
        let z = atanh(r) * Double(n - 3).squareRoot()
        return abs(z) >= criticalZ(alpha: alpha)
    }

    /// Two-tailed critical `|z|` for any alpha — needed because Bonferroni
    /// produces alphas like `0.05 / 25 = 0.002` that aren't in a fixed
    /// lookup. Uses the Abramowitz & Stegun 26.2.23 rational approximation
    /// to `Φ⁻¹(1 − alpha/2)`; max absolute error ~4.5e-4, more than enough
    /// for the significance gate.
    nonisolated static func criticalZ(alpha: Double) -> Double {
        let pTail = min(max(alpha, 1e-12), 0.5) / 2.0
        let t = (-2.0 * log(pTail)).squareRoot()
        let c0 = 2.515517, c1 = 0.802853, c2 = 0.010328
        let d1 = 1.432788, d2 = 0.189269, d3 = 0.001308
        return t - (c0 + c1 * t + c2 * t * t) / (1.0 + d1 * t + d2 * t * t + d3 * t * t * t)
    }

    // MARK: - Pair enumeration

    /// All unordered metric pairs, excluding self-pairs and the
    /// `excludedPairs` set. Order is stable (sorted by metric name) so the
    /// pattern report is deterministic for equal-strength ties.
    nonisolated static func generatePairs() -> [(String, String)] {
        var out: [(String, String)] = []
        for i in 0..<scannedMetrics.count {
            for j in (i + 1)..<scannedMetrics.count {
                let pair = UnorderedMetricPair(scannedMetrics[i], scannedMetrics[j])
                if !excludedPairs.contains(pair) {
                    out.append((scannedMetrics[i], scannedMetrics[j]))
                }
            }
        }
        return out
    }

    // MARK: - Formatting

    /// One-line natural-language summary of a detected pattern. Uses a
    /// hand-picked phrasing for the most actionable pairs; falls back to a
    /// generic correlation summary otherwise.
    nonisolated static func formatPattern(
        metricA: String, metricB: String,
        r: Double, n: Int, windowDays: Int
    ) -> String {
        let stats = "(r=\(formatR(r)), \(n) paired days over \(windowDays))"
        if let custom = customPhrasing(metricA: metricA, metricB: metricB, r: r) {
            return "\(custom) \(stats)."
        }
        let strength = CrossDomainInsightTool.strengthLabel(r)
        let direction = CrossDomainInsightTool.directionLabel(r)
        let prettyA = CrossDomainInsightTool.prettyName(metricA)
        let prettyB = CrossDomainInsightTool.prettyName(metricB)
        return "\(strength.capitalized) \(direction) correlation between \(prettyA) and \(prettyB) \(stats)."
    }

    /// Hand-tuned phrasing for the highest-actionability pairs. Returns
    /// `nil` to fall back to the generic correlation sentence.
    nonisolated static func customPhrasing(metricA: String, metricB: String, r: Double) -> String? {
        let pair = UnorderedMetricPair(metricA, metricB)
        let positive = r > 0
        switch pair {
        case UnorderedMetricPair("workout_volume", "weight"):
            return positive
                ? "Your weight runs higher on heavier-volume training days"
                : "Your weight tends to drop on heavier-volume training days"
        case UnorderedMetricPair("workout_volume", "protein"):
            return positive
                ? "You log more protein on training days"
                : "Your protein dips on training days"
        case UnorderedMetricPair("workout_volume", "calories"):
            return positive
                ? "You eat more on training days"
                : "You eat less on training days"
        case UnorderedMetricPair("carbs", "glucose_avg"):
            return positive
                ? "Higher-carb days run higher average glucose"
                : "Your glucose runs lower on higher-carb days"
        case UnorderedMetricPair("fiber", "glucose_avg"):
            return positive
                ? "Higher-fiber days run higher average glucose"
                : "Higher-fiber days run lower average glucose"
        case UnorderedMetricPair("protein", "weight"):
            return positive
                ? "Higher-protein days line up with higher weight readings"
                : "Higher-protein days line up with lower weight readings"
        case UnorderedMetricPair("calories", "weight"):
            return positive
                ? "Higher-calorie days line up with higher weight readings"
                : "Higher-calorie days line up with lower weight readings"
        case UnorderedMetricPair("fat", "glucose_avg"):
            return positive
                ? "Higher-fat days run higher average glucose"
                : "Higher-fat days run lower average glucose"
        default:
            return nil
        }
    }

    nonisolated static func formatR(_ r: Double) -> String {
        String(format: "%+.2f", r)
    }
}
