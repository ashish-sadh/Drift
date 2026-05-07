import Foundation

/// Pure-logic weight trend calculator. No side effects, highly testable.
public enum WeightTrendCalculator {

    // MARK: - Configuration

    /// Tunable algorithm parameters. Adjust these to calibrate deficit estimates.
    public struct AlgorithmConfig: Codable, Sendable {
        /// Time-weighted EMA half-life in days. After this many days, an
        /// entry's contribution decays by 50%. Time-weighted (not entry-
        /// indexed) so cadence-independent — daily and weekly weighers
        /// with identical real trajectories see the same Trend Weight.
        public var emaHalfLifeDays: Double

        /// Default window for slope calculation (two-window endpoint method
        /// when entries-per-half allows; OLS fallback otherwise).
        public var regressionWindowDays: Int

        /// When |slope| on the default window is below this threshold,
        /// re-run on a wider window to surface low-rate trends that get
        /// drowned in daily noise. Threshold in kg/week.
        public var widenSlopeThresholdKgPerWeek: Double

        /// Wider window used when widening triggers. ~2× default by design
        /// (halves slope SE).
        public var widenWindowDays: Int

        /// Largest gap (days) between consecutive entries within the widened
        /// window that triggers clipping to post-gap data only. Prevents
        /// pre-regime data from blending into the slope after a logging pause.
        public var regimeChangeGapThresholdDays: Int

        /// Energy density of body weight change in kcal per kg.
        public var kcalPerKg: Double

        /// Weekly rate threshold (kg/week) below which we classify as "maintaining".
        public var maintainingThresholdKgPerWeek: Double

        // Legacy field retained for Codable compatibility with persisted user
        // configs. Not consumed by the calculator anymore — replaced by
        // emaHalfLifeDays. Will be removed once all stored configs migrate.
        public var emaAlpha: Double

        init(
            emaHalfLifeDays: Double,
            regressionWindowDays: Int,
            widenSlopeThresholdKgPerWeek: Double,
            widenWindowDays: Int,
            kcalPerKg: Double,
            maintainingThresholdKgPerWeek: Double,
            regimeChangeGapThresholdDays: Int = 14,
            emaAlpha: Double = 0.1
        ) {
            self.emaHalfLifeDays = emaHalfLifeDays
            self.regressionWindowDays = regressionWindowDays
            self.widenSlopeThresholdKgPerWeek = widenSlopeThresholdKgPerWeek
            self.widenWindowDays = widenWindowDays
            self.kcalPerKg = kcalPerKg
            self.maintainingThresholdKgPerWeek = maintainingThresholdKgPerWeek
            self.regimeChangeGapThresholdDays = regimeChangeGapThresholdDays
            self.emaAlpha = emaAlpha
        }

        public static let `default` = AlgorithmConfig(
            emaHalfLifeDays: 14,
            regressionWindowDays: 21,
            // Tightened 0.227 → 0.10 (2026-05-06): the prior 0.5 lbs/wk
            // threshold meant any sub-half-pound-per-week slope triggered
            // widening to 42 days, which routinely pulled in pre-regime-change
            // data and flipped the sign on users mid-direction-change. A real
            // user gaining at +0.18 kg/wk got reported as a -0.55 lbs/wk loser
            // because the 42-day widen reached into a prior losing phase.
            // 0.10 kg/wk (~0.22 lbs/wk) still filters genuine near-zero noise
            // but lets a real, consistent small slope survive without widening.
            widenSlopeThresholdKgPerWeek: 0.10,
            widenWindowDays: 42,
            kcalPerKg: 6000,
            maintainingThresholdKgPerWeek: 0.05
        )

        public static let conservative = AlgorithmConfig(
            emaHalfLifeDays: 21,
            regressionWindowDays: 21,
            widenSlopeThresholdKgPerWeek: 0.10,
            widenWindowDays: 42,
            kcalPerKg: 5500,
            maintainingThresholdKgPerWeek: 0.05
        )

        public static let responsive = AlgorithmConfig(
            emaHalfLifeDays: 7,
            regressionWindowDays: 14,
            widenSlopeThresholdKgPerWeek: 0.227,
            widenWindowDays: 28,
            kcalPerKg: 7700,
            maintainingThresholdKgPerWeek: 0.05
        )
    }

    // MARK: - Public Types

    public struct WeightTrend: Sendable {
        public let currentEMA: Double
        public let previousEMA: Double
        public let weeklyRateKg: Double
        public let estimatedDailyDeficit: Double
        public let trendDirection: TrendDirection
        public let projection30Day: Double?
        public let dataPoints: [WeightDataPoint]
        public let weightChanges: WeightChanges
        public let config: AlgorithmConfig
        /// Actual window (days) used to compute weeklyRateKg — may differ from
        /// config.regressionWindowDays when widening or gap-clipping applies.
        public let rateWindowDays: Int

        init(currentEMA: Double, previousEMA: Double, weeklyRateKg: Double, estimatedDailyDeficit: Double, trendDirection: TrendDirection, projection30Day: Double?, dataPoints: [WeightDataPoint], weightChanges: WeightChanges, config: AlgorithmConfig, rateWindowDays: Int) {
            self.currentEMA = currentEMA
            self.previousEMA = previousEMA
            self.weeklyRateKg = weeklyRateKg
            self.estimatedDailyDeficit = estimatedDailyDeficit
            self.trendDirection = trendDirection
            self.projection30Day = projection30Day
            self.dataPoints = dataPoints
            self.weightChanges = weightChanges
            self.config = config
            self.rateWindowDays = rateWindowDays
        }
    }

    public struct WeightDataPoint: Sendable {
        public let date: Date
        public let dateString: String
        public let actualWeight: Double?
        public let emaWeight: Double

        init(date: Date, dateString: String, actualWeight: Double?, emaWeight: Double) {
            self.date = date
            self.dateString = dateString
            self.actualWeight = actualWeight
            self.emaWeight = emaWeight
        }
    }

    public struct WeightChanges: Sendable {
        public let threeDay: Double?
        public let sevenDay: Double?
        public let fourteenDay: Double?
        public let thirtyDay: Double?
        public let ninetyDay: Double?

        init(threeDay: Double?, sevenDay: Double?, fourteenDay: Double?, thirtyDay: Double?, ninetyDay: Double?) {
            self.threeDay = threeDay
            self.sevenDay = sevenDay
            self.fourteenDay = fourteenDay
            self.thirtyDay = thirtyDay
            self.ninetyDay = ninetyDay
        }
    }

    public enum TrendDirection: Sendable {
        case losing, maintaining, gaining

        public var displayText: String {
            switch self {
            case .losing: "Decrease"
            case .maintaining: "Stable"
            case .gaining: "Increase"
            }
        }

        public var systemImage: String {
            switch self {
            case .losing: "arrow.down.right"
            case .maintaining: "arrow.right"
            case .gaining: "arrow.up.right"
            }
        }
    }

    // MARK: - Core Calculation

    public static func calculateTrend(
        entries: [(date: String, weightKg: Double)],
        config: AlgorithmConfig = loadConfig()
    ) -> WeightTrend? {
        guard !entries.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let sorted = entries
            .compactMap { entry -> (date: Date, dateString: String, weight: Double)? in
                guard let date = formatter.date(from: entry.date) else { return nil }
                return (date, entry.date, entry.weightKg)
            }
            .sorted { $0.date < $1.date }

        guard !sorted.isEmpty else { return nil }

        // Outlier removal: gap-aware threshold (allows more deviation after long gaps)
        let weights = sorted.map(\.weight)
        let median = weights.sorted()[weights.count / 2]
        let filtered = sorted.filter { entry in
            let deviation = abs(entry.weight - median) / median
            let gapDays = sorted.compactMap { other -> Int? in
                guard other.date != entry.date else { return nil }
                return abs(Calendar.current.dateComponents([.day], from: entry.date, to: other.date).day ?? 0)
            }.min() ?? 0
            let gapAllowance = (Double(gapDays) / 7.0) * (1.5 / median)
            let threshold = min(0.15 + gapAllowance, 0.50)
            return deviation <= threshold
        }
        guard !filtered.isEmpty else { return nil }

        // Time-weighted EMA: decay factor depends on elapsed days between
        // entries, not on entry count. A weekly weigher and a daily weigher
        // with the same actual trajectory now produce the same EMA — half-
        // life is a property of time, not log frequency. (Was: entry-indexed
        // alpha, which made weekly weighers' Trend Weight lag ~25% behind
        // reality due to seed weight retention.)
        var dataPoints: [WeightDataPoint] = []
        var ema = filtered[0].weight
        var prevDate = filtered[0].date
        dataPoints.append(WeightDataPoint(
            date: filtered[0].date,
            dateString: filtered[0].dateString,
            actualWeight: filtered[0].weight,
            emaWeight: ema
        ))
        for entry in filtered.dropFirst() {
            let deltaDays = max(
                1.0,
                Double(Calendar.current.dateComponents([.day], from: prevDate, to: entry.date).day ?? 1)
            )
            // alpha = 1 - (1/2)^(Δt / halfLife). At Δt = halfLife, alpha = 0.5,
            // meaning the new entry contributes 50% and the prior EMA 50%.
            let alpha = 1.0 - pow(0.5, deltaDays / config.emaHalfLifeDays)
            ema = alpha * entry.weight + (1 - alpha) * ema
            dataPoints.append(WeightDataPoint(
                date: entry.date,
                dateString: entry.dateString,
                actualWeight: entry.weight,
                emaWeight: ema
            ))
            prevDate = entry.date
        }

        guard let lastPoint = dataPoints.last else { return nil }
        let currentEMA = lastPoint.emaWeight
        let previousEMA = dataPoints.count >= 2 ? dataPoints[dataPoints.count - 2].emaWeight : currentEMA

        // Slope: median-based two-window endpoint method on raw weights.
        // (median + actual time centers — see slopeViaTwoWindowEndpoints).
        // Median is robust to single-day water-weight outliers; actual time
        // centers reflect real elapsed time, not nominal window arithmetic.
        // EMA-based regression considered for dense loggers but rejected:
        // re-introduces the lag-on-regime-change bug that drove the original
        // move away from EMA. Median two-window already produces smooth,
        // responsive output without that tradeoff. Adaptive widen still
        // applies for sub-threshold slopes.
        let primary = weeklyRateForWindow(
            dataPoints: dataPoints, windowDays: config.regressionWindowDays
        )
        let weeklyRateKg: Double
        let rateWindowDays: Int
        if let primary, abs(primary) >= config.widenSlopeThresholdKgPerWeek {
            weeklyRateKg = primary
            rateWindowDays = config.regressionWindowDays
        } else {
            let hasEnoughHistory = dataPoints.first.map { daysBetween($0.date, Date()) >= config.widenWindowDays } ?? false
            if hasEnoughHistory,
               let widenStart = Calendar.current.date(byAdding: .day, value: -config.widenWindowDays, to: Date()) {
                let widenedPoints = dataPoints.filter { $0.date >= widenStart }
                let usablePoints = largestGapBetweenConsecutive(widenedPoints) > config.regimeChangeGapThresholdDays
                    ? pointsAfterLastGap(widenedPoints, gapThresholdDays: config.regimeChangeGapThresholdDays)
                    : widenedPoints
                let usableSpan = usablePoints.count >= 2
                    ? daysBetween(usablePoints.first!.date, usablePoints.last!.date)
                    : 0
                if let widened = weeklyRateForWindow(dataPoints: usablePoints, windowDays: config.widenWindowDays) {
                    // Regime-change guard (no-gap variant): if the widened
                    // slope flips sign relative to a meaningful primary, trust
                    // the primary. The widen path is for noise reduction at
                    // near-zero slopes — not for overruling a real recent
                    // direction change. Without this, a user who switched
                    // from losing to gaining (or vice versa) and logs
                    // continuously (no gap to trigger pointsAfterLastGap)
                    // gets the wrong sign on weekly rate and deficit. The
                    // gap-based regime detection above only handles the
                    // discontinuous case.
                    let primaryIsMeaningful = abs(primary ?? 0) >= config.maintainingThresholdKgPerWeek
                    let signsDiffer = primary.map { ($0 > 0) != (widened > 0) } ?? false
                    if primaryIsMeaningful, signsDiffer, let p = primary {
                        weeklyRateKg = p
                        rateWindowDays = config.regressionWindowDays
                    } else {
                        weeklyRateKg = widened
                        rateWindowDays = max(usableSpan, config.regressionWindowDays)
                    }
                } else {
                    weeklyRateKg = primary ?? 0
                    rateWindowDays = config.regressionWindowDays
                }
            } else {
                weeklyRateKg = primary ?? 0
                rateWindowDays = config.regressionWindowDays
            }
        }

        let estimatedDailyDeficit = weeklyRateKg * config.kcalPerKg / 7

        let trendDirection: TrendDirection
        if weeklyRateKg < -config.maintainingThresholdKgPerWeek {
            trendDirection = .losing
        } else if weeklyRateKg > config.maintainingThresholdKgPerWeek {
            trendDirection = .gaining
        } else {
            trendDirection = .maintaining
        }

        // Project from the latest ACTUAL weight, not from the (possibly lagging)
        // EMA. Using the EMA as the base of projection compounds the lag —
        // user sees a "projected weight" that's anchored to a stale value.
        let latestActualWeight = dataPoints.last?.actualWeight ?? currentEMA
        let projection30Day: Double? = dataPoints.count >= 3
            ? latestActualWeight + (weeklyRateKg / 7 * 30)
            : nil

        return WeightTrend(
            currentEMA: currentEMA,
            previousEMA: previousEMA,
            weeklyRateKg: weeklyRateKg,
            estimatedDailyDeficit: estimatedDailyDeficit,
            trendDirection: trendDirection,
            projection30Day: projection30Day,
            dataPoints: dataPoints,
            weightChanges: calculateWeightChanges(dataPoints: dataPoints),
            config: config,
            rateWindowDays: rateWindowDays
        )
    }

    // MARK: - Config Persistence

    private static let configKey = "drift_algorithm_config"

    public static func loadConfig() -> AlgorithmConfig {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let config = try? JSONDecoder().decode(AlgorithmConfig.self, from: data) else {
            return .default
        }
        return config
    }

    public static func saveConfig(_ config: AlgorithmConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    // MARK: - Linear Regression

    /// OLS slope (kg/day) over (date, weight) pairs. Shared by the EMA-based
    /// and actual-weight-based regression entry points.
    private static func slopeOfSeries(_ samples: [(date: Date, weight: Double)]) -> Double {
        guard samples.count >= 2 else { return 0 }

        let referenceDate = samples[0].date
        let n = Double(samples.count)

        var sumX: Double = 0, sumY: Double = 0, sumXY: Double = 0, sumX2: Double = 0
        for s in samples {
            let x = Double(Calendar.current.dateComponents([.day], from: referenceDate, to: s.date).day ?? 0)
            let y = s.weight
            sumX += x; sumY += y; sumXY += x * y; sumX2 += x * x
        }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return 0 }
        return (n * sumXY - sumX * sumY) / denominator
    }

    /// Slope (kg/day) of the EMA-smoothed series. Public for tests and
    /// algorithm-preview tools, but **not** used to compute weeklyRate /
    /// surplus / projection — see linearRegressionSlopeOnActualWeight.
    /// EMA-based regression lags on regime changes by half-life; the
    /// production path uses two-window-on-raw-weights to stay responsive.
    public static func linearRegressionSlope(points: [WeightDataPoint]) -> Double {
        slopeOfSeries(points.map { (date: $0.date, weight: $0.emaWeight) })
    }

    /// Slope (kg/day) of the raw actual-weight series. Filters out points
    /// without an actualWeight (synthesized/missing-data points). This is
    /// the slope that drives weeklyRate, daily deficit, and projection —
    /// regressing on raw weights avoids the EMA-lag inversion that
    /// happens when a user's weight regime recently changed direction.
    public static func linearRegressionSlopeOnActualWeight(points: [WeightDataPoint]) -> Double {
        let samples: [(date: Date, weight: Double)] = points.compactMap {
            guard let w = $0.actualWeight else { return nil }
            return (date: $0.date, weight: w)
        }
        return slopeOfSeries(samples)
    }

    /// Two-window endpoint slope: median of first 7-day window vs median of
    /// last 7-day window, scaled by the actual time delta between window
    /// centers. Two robustness fixes vs. the original mean-based version:
    /// 1. **Median, not mean** — daily weight is noisy (water/glycogen swings
    ///    of ±1.5 lb common). With 7 samples per window, one outlier shifts
    ///    the mean by 0.21 lb but leaves the median unchanged. A single
    ///    after-salty-meal weighing was producing -0.71 lbs/wk reports on
    ///    near-flat trajectories before this change.
    /// 2. **Actual time-weighted centers** — the original assumed window
    ///    centers were exactly `(windowDays - 7)/7` weeks apart. If the
    ///    first window has 3 entries clustered at one end and the last has
    ///    7 evenly spread, real centers can be ~17 days apart, not 14.
    /// Returns nil if either endpoint window has fewer than 2 entries —
    /// caller should fall back to OLS.
    ///
    /// Returns slope in **kg/week** (not kg/day, unlike slopeOfSeries).
    static func slopeViaTwoWindowEndpoints(
        points: [WeightDataPoint],
        windowDays: Int
    ) -> Double? {
        guard let last = points.last else { return nil }
        let endpointSpan = 7
        guard let firstWindowEnd = Calendar.current.date(byAdding: .day, value: -(windowDays - endpointSpan), to: last.date),
              let lastWindowStart = Calendar.current.date(byAdding: .day, value: -endpointSpan, to: last.date) else {
            return nil
        }
        let firstWindow = points.filter { $0.date <= firstWindowEnd }
        let lastWindow = points.filter { $0.date >= lastWindowStart }
        guard firstWindow.count >= 2, lastWindow.count >= 2 else { return nil }

        let firstWeights = firstWindow.compactMap { $0.actualWeight }
        let lastWeights = lastWindow.compactMap { $0.actualWeight }
        guard firstWeights.count >= 2, lastWeights.count >= 2 else { return nil }

        // Median: robust to single-day water-weight outliers.
        let firstMedian = median(of: firstWeights)
        let lastMedian = median(of: lastWeights)

        // Actual time centers (mean of timestamps inside each window).
        let firstCenter = meanDate(of: firstWindow)
        let lastCenter = meanDate(of: lastWindow)
        let weeksBetween = lastCenter.timeIntervalSince(firstCenter) / (7 * 86400)
        guard weeksBetween > 0 else { return nil }
        return (lastMedian - firstMedian) / weeksBetween
    }

    /// Median of a numeric array. For even-count, returns mean of the two
    /// middle elements. Caller guarantees non-empty.
    static func median(of values: [Double]) -> Double {
        let sorted = values.sorted()
        let n = sorted.count
        if n % 2 == 1 { return sorted[n / 2] }
        return (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
    }

    /// Mean of timestamps in a points array. Caller guarantees non-empty.
    static func meanDate(of points: [WeightDataPoint]) -> Date {
        let avg = points.map { $0.date.timeIntervalSinceReferenceDate }
            .reduce(0, +) / Double(points.count)
        return Date(timeIntervalSinceReferenceDate: avg)
    }

    /// Whole-day count between two dates (positive when `b` is after `a`).
    /// Wraps Calendar.current to avoid the verbose dateComponents call site.
    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// Largest gap in days between any two consecutive entries in `points`.
    /// Returns 0 for fewer than 2 points.
    static func largestGapBetweenConsecutive(_ points: [WeightDataPoint]) -> Int {
        guard points.count >= 2 else { return 0 }
        return zip(points, points.dropFirst())
            .map { daysBetween($0.date, $1.date) }
            .max() ?? 0
    }

    /// Returns all entries that follow the last gap exceeding `gapThresholdDays`.
    /// If no such gap exists, returns `points` unchanged.
    static func pointsAfterLastGap(_ points: [WeightDataPoint], gapThresholdDays: Int) -> [WeightDataPoint] {
        guard points.count >= 2 else { return points }
        for i in stride(from: points.count - 2, through: 0, by: -1) {
            if daysBetween(points[i].date, points[i + 1].date) > gapThresholdDays {
                return Array(points[(i + 1)...])
            }
        }
        return points
    }

    /// Compute weekly rate (kg/wk) for a given window of `dataPoints` ending
    /// at the latest entry. Tries two-window endpoint method first
    /// (robust to noise + regime-change-correct), falls back to plain OLS
    /// on raw weights when too few entries per endpoint, falls back to a
    /// 2-point delta when the window is sparse. Returns nil only when
    /// fewer than 2 points exist anywhere — slope is meaningless then.
    static func weeklyRateForWindow(
        dataPoints: [WeightDataPoint],
        windowDays: Int
    ) -> Double? {
        guard let windowStart = Calendar.current.date(byAdding: .day, value: -windowDays, to: Date()) else { return nil }
        let windowed = dataPoints.filter { $0.date >= windowStart }

        if let twoWindow = slopeViaTwoWindowEndpoints(points: windowed, windowDays: windowDays) {
            return twoWindow
        }
        if windowed.count >= 3 {
            return linearRegressionSlopeOnActualWeight(points: windowed) * 7
        }
        if dataPoints.count >= 2 {
            let last = dataPoints[dataPoints.count - 1]
            let prev = dataPoints[dataPoints.count - 2]
            let lastW = last.actualWeight ?? last.emaWeight
            let prevW = prev.actualWeight ?? prev.emaWeight
            let days = daysBetween(prev.date, last.date)
            return days > 0 ? (lastW - prevW) / Double(days) * 7 : nil
        }
        return nil
    }

    // MARK: - Weight Changes

    public static func calculateWeightChanges(dataPoints: [WeightDataPoint]) -> WeightChanges {
        guard let latest = dataPoints.last, let latestActual = latest.actualWeight else {
            return WeightChanges(threeDay: nil, sevenDay: nil, fourteenDay: nil, thirtyDay: nil, ninetyDay: nil)
        }

        func changeOverDays(_ days: Int) -> Double? {
            guard let target = Calendar.current.date(byAdding: .day, value: -days, to: latest.date) else { return nil }
            let closest = dataPoints.min { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) }
            guard let closest, closest.date != latest.date,
                  let closestActual = closest.actualWeight else { return nil }
            let daysDiff = abs(Calendar.current.dateComponents([.day], from: closest.date, to: target).day ?? 0)
            guard daysDiff <= 3 else { return nil }
            return latestActual - closestActual
        }

        return WeightChanges(
            threeDay: changeOverDays(3), sevenDay: changeOverDays(7),
            fourteenDay: changeOverDays(14), thirtyDay: changeOverDays(30),
            ninetyDay: changeOverDays(90)
        )
    }
}
