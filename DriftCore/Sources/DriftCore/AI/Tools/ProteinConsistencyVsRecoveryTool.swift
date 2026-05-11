import Foundation
import DriftCore

/// Cross-domain analytical tool. Pairs daily protein intake with HRV /
/// sleep recovery across a window, surfacing whether the user's protein
/// consistency tracks their recovery score. Read-only, on-device.
///
/// Design:
/// - Pull `proteinG` per day from `fetchDailyNutrition`.
/// - Pull HRV and sleep-hours per day via `HealthDataProvider`.
/// - Build a daily recovery score = `0.5 × normalized(HRV) + 0.5 × normalized(sleep_hours)`.
///   Normalization is min-max over the in-window paired set so the score
///   has the same scale for everyone (0–1) without needing per-user
///   baselines.
/// - Compute Pearson r between same-day protein and recovery; also split
///   the window into halves and compare protein CV + mean recovery.
/// - Require ≥10 paired days (matches SleepFoodCorrelationTool floor).
@MainActor
public enum ProteinConsistencyVsRecoveryTool {

    nonisolated static let toolName = "protein_consistency_vs_recovery"

    static func syncRegistration(registry: ToolRegistry = .shared) {
        registry.register(schema)
    }

    static var schema: ToolSchema {
        ToolSchema(
            id: "insights.protein_consistency_vs_recovery",
            name: toolName,
            service: "insights",
            description: "User asks whether inconsistent protein intake is affecting their recovery — 'is my protein affecting my recovery?', 'does my protein variance matter?', 'do my recovery days line up with high-protein days?', 'is my protein steady enough for recovery?'.",
            parameters: [
                ToolParam("window_days", "number", "Lookback window in days (14–90, default 28)", required: false)
            ],
            handler: { params in
                let window = clampWindow(params.int("window_days"))
                return .text(await run(windowDays: window))
            }
        )
    }

    // MARK: - Entry point (async — fetches from HealthKit)

    public static func run(windowDays: Int) async -> String {
        guard let hk = DriftPlatform.health else {
            return "No recovery data available. Connect your Apple Watch in the Health app to enable this analysis."
        }

        let pairs = await fetchPairedSeries(windowDays: windowDays, hk: hk)

        guard pairs.count >= minPairs else {
            return "Not enough data yet — \(pairs.count) day\(pairs.count == 1 ? "" : "s") with both protein logged and recovery tracked, need at least \(minPairs). Keep logging meals and check back."
        }

        return formatResult(analyze(pairs: pairs))
    }

    // MARK: - Data fetch

    public struct DayObservation: Sendable, Equatable {
        public let proteinG: Double
        public let hrvMs: Double
        public let sleepHours: Double

        public init(proteinG: Double, hrvMs: Double, sleepHours: Double) {
            self.proteinG = proteinG
            self.hrvMs = hrvMs
            self.sleepHours = sleepHours
        }
    }

    static func fetchPairedSeries(
        windowDays: Int, hk: HealthDataProvider
    ) async -> [DayObservation] {
        let (startDate, endDate) = CrossDomainInsightTool.dateWindow(windowDays: windowDays)
        let dates = CrossDomainInsightTool.datesInRange(startDate: startDate, endDate: endDate)
        let cal = Calendar.current
        let fmt = DateFormatters.dateOnly

        var pairs: [DayObservation] = []
        for dateStr in dates {
            guard let dailyNutrition = try? AppDatabase.shared.fetchDailyNutrition(for: dateStr),
                  dailyNutrition.proteinG > 0 else { continue }
            guard let date = fmt.date(from: dateStr) else { continue }
            let dayStart = cal.startOfDay(for: date)
            let hrv = (try? await hk.fetchHRV(for: dayStart)) ?? 0
            let sleep = (try? await hk.fetchSleepHours(for: dayStart)) ?? 0
            // Skip days where the watch wasn't worn — 0 readings on either
            // axis fake a strong correlation otherwise. Same pattern as
            // SleepFoodCorrelationTool #736.
            guard hrv > 0, sleep > 0 else { continue }
            pairs.append(DayObservation(proteinG: dailyNutrition.proteinG, hrvMs: hrv, sleepHours: sleep))
        }
        return pairs
    }

    // MARK: - Pure analysis (testable)

    public struct ConsistencyResult: Sendable, Equatable {
        public let totalPairs: Int
        public let proteinMean: Double
        public let proteinCV: Double               // coefficient of variation (std/mean)
        public let recoveryMean: Double            // 0–1 composite
        public let proteinRecoveryR: Double?       // Pearson r, nil if flat
        public let highProteinRecoveryMean: Double?
        public let lowProteinRecoveryMean: Double?
        public let highProteinCount: Int
        public let lowProteinCount: Int
    }

    nonisolated public static func analyze(pairs: [DayObservation]) -> ConsistencyResult {
        guard !pairs.isEmpty else {
            return ConsistencyResult(
                totalPairs: 0, proteinMean: 0, proteinCV: 0, recoveryMean: 0,
                proteinRecoveryR: nil,
                highProteinRecoveryMean: nil, lowProteinRecoveryMean: nil,
                highProteinCount: 0, lowProteinCount: 0
            )
        }
        let proteins = pairs.map(\.proteinG)
        let proteinMean = mean(proteins)
        let proteinStd = stddev(proteins, mean: proteinMean)
        let proteinCV = proteinMean > 0 ? proteinStd / proteinMean : 0

        let recoveryScores = computeRecoveryScores(pairs: pairs)
        let recoveryMean = mean(recoveryScores)
        let r = CrossDomainInsightTool.pearsonR(xs: proteins, ys: recoveryScores)

        // Split protein by median; compare recovery means across halves.
        let median = proteins.sorted()[proteins.count / 2]
        var highIdx: [Int] = []
        var lowIdx: [Int] = []
        for (i, p) in proteins.enumerated() {
            if p >= median { highIdx.append(i) } else { lowIdx.append(i) }
        }
        let highRecovery = highIdx.isEmpty ? nil : mean(highIdx.map { recoveryScores[$0] })
        let lowRecovery = lowIdx.isEmpty ? nil : mean(lowIdx.map { recoveryScores[$0] })

        return ConsistencyResult(
            totalPairs: pairs.count,
            proteinMean: proteinMean,
            proteinCV: proteinCV,
            recoveryMean: recoveryMean,
            proteinRecoveryR: r,
            highProteinRecoveryMean: highRecovery,
            lowProteinRecoveryMean: lowRecovery,
            highProteinCount: highIdx.count,
            lowProteinCount: lowIdx.count
        )
    }

    /// Composite recovery score per day, normalized 0–1 across the in-window
    /// observations. Equal-weight HRV + sleep — both are widely-accepted
    /// recovery proxies; combining them blunts single-axis noise (a high-HRV
    /// short-sleep night and vice versa).
    nonisolated public static func computeRecoveryScores(pairs: [DayObservation]) -> [Double] {
        let hrvs = pairs.map(\.hrvMs)
        let sleeps = pairs.map(\.sleepHours)
        let hrvN = minMaxNormalize(hrvs)
        let sleepN = minMaxNormalize(sleeps)
        return zip(hrvN, sleepN).map { ($0 + $1) / 2.0 }
    }

    nonisolated static func minMaxNormalize(_ xs: [Double]) -> [Double] {
        guard let lo = xs.min(), let hi = xs.max(), hi > lo else {
            return xs.map { _ in 0.5 }
        }
        return xs.map { ($0 - lo) / (hi - lo) }
    }

    nonisolated static func mean(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return 0 }
        return xs.reduce(0, +) / Double(xs.count)
    }

    nonisolated static func stddev(_ xs: [Double], mean m: Double) -> Double {
        guard xs.count > 1 else { return 0 }
        let variance = xs.reduce(0.0) { $0 + ($1 - m) * ($1 - m) } / Double(xs.count - 1)
        return variance.squareRoot()
    }

    // MARK: - Formatting

    nonisolated static func formatResult(_ result: ConsistencyResult) -> String {
        var lines: [String] = []
        let cvLabel = cvBucket(result.proteinCV)
        lines.append("Based on \(result.totalPairs) days:")
        lines.append("  Protein: avg \(Int(result.proteinMean.rounded()))g, CV \(String(format: "%.2f", result.proteinCV)) (\(cvLabel)).")

        // Group-mean comparison wins if we have a clean split.
        if let high = result.highProteinRecoveryMean, let low = result.lowProteinRecoveryMean,
           result.highProteinCount >= 3, result.lowProteinCount >= 3 {
            let diff = high - low
            lines.append("  High-protein days (≥median, \(result.highProteinCount)n): recovery score \(String(format: "%.2f", high))")
            lines.append("  Low-protein days  (<median, \(result.lowProteinCount)n): recovery score \(String(format: "%.2f", low))")
            if diff > effectThreshold {
                lines.append("Recovery is higher on days you hit more protein. Aim to keep daily protein closer to your average.")
            } else if diff < -effectThreshold {
                lines.append("Curiously, recovery is higher on lower-protein days — other factors (training load, stress) likely dominate.")
            } else {
                lines.append(cvLabel == "high" ?
                    "Your protein varies a lot but recovery doesn't track it cleanly — try steadying intake to isolate the signal." :
                    "Protein and recovery don't move together in this window — your protein is already stable enough.")
            }
            return lines.joined(separator: "\n")
        }

        // Pearson fallback when split is too thin.
        guard let r = result.proteinRecoveryR else {
            return "Protein or recovery is too flat to compute a correlation — keep logging for a more varied dataset."
        }
        let rStr = String(format: "%+.2f", r)
        let strength = CrossDomainInsightTool.strengthLabel(r)
        let direction = CrossDomainInsightTool.directionLabel(r)
        lines.append("Protein vs recovery correlation r=\(rStr) (\(strength) \(direction)).")
        if abs(r) >= effectThreshold {
            lines.append(r > 0 ?
                "Higher-protein days tend to come with better recovery." :
                "Higher-protein days tend to come with worse recovery — likely a confound, not protein itself.")
        } else {
            lines.append("No strong link — recovery isn't driven by daily protein in this window.")
        }
        return lines.joined(separator: "\n")
    }

    /// CV thresholds tuned to nutrition variance — a 0.20 CV on a ~120g/day
    /// average means ±24g day-to-day, which is the granularity at which
    /// dietary advice typically kicks in.
    nonisolated public static func cvBucket(_ cv: Double) -> String {
        if cv < 0.15 { return "steady" }
        if cv < 0.30 { return "moderate" }
        return "high"
    }

    /// Minimum paired-day count before we'll emit a recommendation. Matches
    /// `SleepFoodCorrelationTool.minPairs` so users see a consistent floor
    /// across analytical tools.
    nonisolated public static let minPairs: Int = 10

    /// Effect threshold for the high-vs-low protein recovery-score gap.
    /// 0.10 on a 0–1 normalized scale is ~half-a-standard-deviation — below
    /// it the noise floor swamps the signal.
    nonisolated public static let effectThreshold: Double = 0.10

    /// Window clamp — too short and the variance estimate is noise; too long
    /// and protein-goal shifts mid-window contaminate the CV.
    nonisolated static func clampWindow(_ raw: Int?) -> Int {
        max(14, min(90, raw ?? 28))
    }
}
