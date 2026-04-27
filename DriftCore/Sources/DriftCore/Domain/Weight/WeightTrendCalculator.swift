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
            emaAlpha: Double = 0.1
        ) {
            self.emaHalfLifeDays = emaHalfLifeDays
            self.regressionWindowDays = regressionWindowDays
            self.widenSlopeThresholdKgPerWeek = widenSlopeThresholdKgPerWeek
            self.widenWindowDays = widenWindowDays
            self.kcalPerKg = kcalPerKg
            self.maintainingThresholdKgPerWeek = maintainingThresholdKgPerWeek
            self.emaAlpha = emaAlpha
        }

        public static let `default` = AlgorithmConfig(
            emaHalfLifeDays: 14,
            regressionWindowDays: 21,
            widenSlopeThresholdKgPerWeek: 0.227,  // ≈ 0.5 lbs/wk
            widenWindowDays: 42,
            kcalPerKg: 6000,
            maintainingThresholdKgPerWeek: 0.05
        )

        public static let conservative = AlgorithmConfig(
            emaHalfLifeDays: 21,
            regressionWindowDays: 21,
            widenSlopeThresholdKgPerWeek: 0.227,
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

        init(currentEMA: Double, previousEMA: Double, weeklyRateKg: Double, estimatedDailyDeficit: Double, trendDirection: TrendDirection, projection30Day: Double?, dataPoints: [WeightDataPoint], weightChanges: WeightChanges, config: AlgorithmConfig) {
            self.currentEMA = currentEMA
            self.previousEMA = previousEMA
            self.weeklyRateKg = weeklyRateKg
            self.estimatedDailyDeficit = estimatedDailyDeficit
            self.trendDirection = trendDirection
            self.projection30Day = projection30Day
            self.dataPoints = dataPoints
            self.weightChanges = weightChanges
            self.config = config
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

        // Slope: two-window endpoint method (preferred) → OLS fallback →
        // 2-point fallback. Adaptive widening when the default-window slope
        // is below threshold and we have enough history. See
        // weeklyRateForWindow() docs for the per-method criteria.
        let primary = weeklyRateForWindow(
            dataPoints: dataPoints, windowDays: config.regressionWindowDays
        )
        let weeklyRateKg: Double
        if let primary, abs(primary) >= config.widenSlopeThresholdKgPerWeek {
            weeklyRateKg = primary
        } else if let widened = weeklyRateForWindow(
            dataPoints: dataPoints, windowDays: config.widenWindowDays
        ), dataPoints.first.map({ daysBetween($0.date, Date()) >= config.widenWindowDays }) ?? false {
            // Wider window only kicks in when we actually have ≥widenWindowDays
            // of history — otherwise it just reproduces the primary result.
            weeklyRateKg = widened
        } else {
            weeklyRateKg = primary ?? 0
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
            config: config
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

    /// Two-window endpoint slope: average the first 7-day window's weights
    /// vs the last 7-day window's weights, take the difference per week.
    /// Robust to daily noise (sqrt(7) variance reduction within each
    /// window) AND catches regime changes (compares actual endpoints, not
    /// a lagging EMA). Returns nil if either endpoint window has fewer
    /// than 2 entries — caller should fall back to plain OLS.
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

        let firstAvg = firstWeights.reduce(0, +) / Double(firstWeights.count)
        let lastAvg = lastWeights.reduce(0, +) / Double(lastWeights.count)

        // Distance between window centers (in weeks). For a 21-day window
        // with 7-day endpoints, the centers are ~14 days apart (2 weeks).
        let weeksBetweenCenters = Double(windowDays - endpointSpan) / 7.0
        guard weeksBetweenCenters > 0 else { return nil }
        return (lastAvg - firstAvg) / weeksBetweenCenters
    }

    /// Whole-day count between two dates (positive when `b` is after `a`).
    /// Wraps Calendar.current to avoid the verbose dateComponents call site.
    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0
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
