import Foundation

/// Pure-logic weight trend calculator. No side effects, highly testable.
public enum WeightTrendCalculator {

    // MARK: - Configuration

    /// Tunable algorithm parameters. Adjust these to calibrate deficit estimates.
    public struct AlgorithmConfig: Codable, Sendable {
        /// EMA smoothing factor. Higher = more responsive, noisier.
        public var emaAlpha: Double

        /// Number of days of EMA data to use for linear regression.
        public var regressionWindowDays: Int

        /// Energy density of body weight change in kcal per kg.
        public var kcalPerKg: Double

        /// Weekly rate threshold (kg/week) below which we classify as "maintaining".
        public var maintainingThresholdKgPerWeek: Double

        init(emaAlpha: Double, regressionWindowDays: Int, kcalPerKg: Double, maintainingThresholdKgPerWeek: Double) {
            self.emaAlpha = emaAlpha
            self.regressionWindowDays = regressionWindowDays
            self.kcalPerKg = kcalPerKg
            self.maintainingThresholdKgPerWeek = maintainingThresholdKgPerWeek
        }

        public static let `default` = AlgorithmConfig(
            emaAlpha: 0.1,
            regressionWindowDays: 21,
            kcalPerKg: 6000,
            maintainingThresholdKgPerWeek: 0.05
        )

        public static let conservative = AlgorithmConfig(
            emaAlpha: 0.08,
            regressionWindowDays: 21,
            kcalPerKg: 5500,
            maintainingThresholdKgPerWeek: 0.05
        )

        public static let responsive = AlgorithmConfig(
            emaAlpha: 0.15,
            regressionWindowDays: 14,
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

        var dataPoints: [WeightDataPoint] = []
        var ema = filtered[0].weight

        for entry in filtered {
            ema = config.emaAlpha * entry.weight + (1 - config.emaAlpha) * ema
            dataPoints.append(WeightDataPoint(
                date: entry.date,
                dateString: entry.dateString,
                actualWeight: entry.weight,
                emaWeight: ema
            ))
        }

        guard let lastPoint = dataPoints.last else { return nil }
        let currentEMA = lastPoint.emaWeight
        let previousEMA = dataPoints.count >= 2 ? dataPoints[dataPoints.count - 2].emaWeight : currentEMA

        guard let windowStart = Calendar.current.date(byAdding: .day, value: -config.regressionWindowDays, to: Date()) else { return nil }
        let recentPoints = dataPoints.filter { $0.date >= windowStart }

        // Slope is computed on RAW filtered weights, NOT on the EMA series.
        // Regressing on EMA values measures how fast the EMA is catching up to
        // reality (which may move opposite to actual weight when the user's
        // regime recently changed) instead of how the user's actual weight is
        // changing. Outlier removal (above) provides robustness; regression
        // itself averages remaining noise (slope variance ~ σ²/N³).
        let weeklyRateKg: Double
        if recentPoints.count >= 3 {
            weeklyRateKg = linearRegressionSlopeOnActualWeight(points: recentPoints) * 7
        } else if dataPoints.count >= 2 {
            let last = dataPoints[dataPoints.count - 1]
            let prev = dataPoints[dataPoints.count - 2]
            let lastW = last.actualWeight ?? last.emaWeight
            let prevW = prev.actualWeight ?? prev.emaWeight
            let days = Calendar.current.dateComponents([.day], from: prev.date, to: last.date).day ?? 1
            weeklyRateKg = days > 0 ? (lastW - prevW) / Double(days) * 7 : 0
        } else {
            weeklyRateKg = 0
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
