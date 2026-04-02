import Foundation

/// Unified TDEE estimation using Base + Dampened Corrections.
///
/// Base = 2000 × √(weight/70) × activityFactor (always computed)
/// Then each available data source pulls the base toward observed reality:
///   + Mifflin correction (0.4 dampening) — when age/height/sex provided
///   + Apple Health correction (0.5 dampening) — when resting + active available
///   + Weight Trend correction (0.3 dampening) — when food logging consistent
///
/// Result: conservative default that improves incrementally with data.
@MainActor
final class TDEEEstimator {
    static let shared = TDEEEstimator()

    // MARK: - Configuration

    enum Sex: String, Codable, Sendable, CaseIterable {
        case male, female
        var label: String { rawValue.capitalized }
    }

    struct TDEEConfig: Codable, Sendable {
        var activityMultiplier: Double
        var appleHealthTrust: Double
        var manualAdjustment: Double

        // Optional profile for Mifflin-St Jeor
        var age: Int?
        var heightCm: Double?
        var sex: Sex?

        static let `default` = TDEEConfig(
            activityMultiplier: 29,
            appleHealthTrust: 1.0,
            manualAdjustment: 0,
            age: nil, heightCm: nil, sex: nil
        )

        var loggingConsistencyThreshold: Double { 0.5 }

        var activityLabel: String {
            switch activityMultiplier {
            case ..<24: "Sedentary"
            case ..<27: "Lightly Active"
            case ..<30: "Moderately Active"
            case ..<33: "Very Active"
            default: "Athlete"
            }
        }

        var hasMifflinProfile: Bool {
            age != nil && heightCm != nil && sex != nil
        }

        /// Map activity slider (22-36) to Mifflin activity factor (1.2-1.9)
        var mifflinActivityFactor: Double {
            1.2 + (activityMultiplier - 22) * 0.05
        }
    }

    private static let configKey = "drift_tdee_config"

    static func loadConfig() -> TDEEConfig {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let config = try? JSONDecoder().decode(TDEEConfig.self, from: data) else {
            return .default
        }
        return config
    }

    static func saveConfig(_ config: TDEEConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
        shared.current = nil
        UserDefaults.standard.removeObject(forKey: shared.cacheKey)
    }

    // MARK: - Estimate

    struct Estimate: Codable, Sendable {
        let tdee: Double
        let source: Source
        let confidence: Confidence
        let timestamp: Date
        let activeSources: [String] // which sources contributed

        enum Source: String, Codable, Sendable {
            case appleHealth = "Apple Health"
            case weightTrend = "Weight Trend"
            case blended = "Blended"
            case mifflin = "Mifflin-St Jeor"
            case bodyWeight = "Body Weight"
        }

        enum Confidence: String, Codable, Sendable {
            case high, medium, low
        }

        var explanation: String {
            switch source {
            case .appleHealth:
                return "Resting + active energy from Apple Health (7-day avg)."
            case .weightTrend:
                return "Derived from food logs and weight trend."
            case .blended:
                return "Blended from multiple data sources."
            case .mifflin:
                return "Calculated from your profile (age, height, sex)."
            case .bodyWeight:
                return "Estimated from body weight. Add profile or log data for better accuracy."
            }
        }
    }

    private let cacheKey = "drift_tdee_cache"
    private(set) var current: Estimate?

    // MARK: - Core Formula

    /// Compute base TDEE from weight + activity slider.
    /// Anchored at 2000 kcal for 70kg, sqrt scaling for diminishing returns.
    nonisolated static func computeBase(weightKg: Double?, activityMultiplier: Double) -> Double {
        guard let w = weightKg, w > 0 else { return 2000 }
        return 2000 * sqrt(w / 70) * (activityMultiplier / 29)
    }

    /// Compute Mifflin-St Jeor TDEE when profile is available.
    nonisolated static func computeMifflin(weightKg: Double, config: TDEEConfig) -> Double? {
        guard let age = config.age, let height = config.heightCm, let sex = config.sex else { return nil }
        let bmr: Double
        switch sex {
        case .male:   bmr = 10 * weightKg + 6.25 * height - 5 * Double(age) + 5
        case .female: bmr = 10 * weightKg + 6.25 * height - 5 * Double(age) - 161
        }
        return bmr * config.mifflinActivityFactor
    }

    // MARK: - Refresh (async — uses Apple Health)

    func refresh() async {
        let config = Self.loadConfig()
        let db = AppDatabase.shared
        let weightKg = (try? db.fetchWeightEntries(from: nil))?.first?.weightKg

        // Step 1: Base
        var tdee = Self.computeBase(weightKg: weightKg, activityMultiplier: config.activityMultiplier)
        var sources: [String] = weightKg != nil ? ["Weight"] : ["Default"]
        var bestSource: Estimate.Source = weightKg != nil ? .bodyWeight : .bodyWeight

        // Step 2: Corrections

        // Mifflin correction (0.4 dampening)
        if let w = weightKg, let mifflin = Self.computeMifflin(weightKg: w, config: config) {
            tdee += (mifflin - tdee) * 0.4
            sources.append("Profile")
            bestSource = .mifflin
        }

        // Apple Health correction (0.5 dampening)
        let ahTDEE = await fetchAppleHealth7DayAvg(config: config)
        if let ah = ahTDEE {
            tdee += (ah - tdee) * 0.5
            sources.append("Apple Health")
            bestSource = sources.count >= 3 ? .blended : .appleHealth
        }

        // Weight trend correction (0.3 dampening)
        let trendTDEE = fetchWeightTrendTDEE()
        let consistency = foodLoggingConsistency()
        if let trend = trendTDEE, consistency >= config.loggingConsistencyThreshold {
            tdee += (trend - tdee) * 0.3
            sources.append("Weight Trend")
            bestSource = .blended
        }

        // Step 3: Final
        tdee = max(1200, tdee + config.manualAdjustment)

        let confidence: Estimate.Confidence = sources.count >= 3 ? .high : sources.count >= 2 ? .medium : .low
        let estimate = Estimate(tdee: tdee, source: bestSource, confidence: confidence,
                                timestamp: Date(), activeSources: sources)
        current = estimate
        cache(estimate)
        Log.app.info("TDEE: \(Int(tdee)) kcal (\(sources.joined(separator: "+")))")
    }

    // MARK: - Sync path (no Apple Health)

    func cachedOrSync() -> Estimate {
        if let current { return current }
        if let cached = loadCache() { self.current = cached; return cached }

        let config = Self.loadConfig()
        let db = AppDatabase.shared
        let weightKg = (try? db.fetchWeightEntries(from: nil))?.first?.weightKg

        // Step 1: Base
        var tdee = Self.computeBase(weightKg: weightKg, activityMultiplier: config.activityMultiplier)
        var sources: [String] = weightKg != nil ? ["Weight"] : ["Default"]
        var bestSource: Estimate.Source = .bodyWeight

        // Step 2: Mifflin correction
        if let w = weightKg, let mifflin = Self.computeMifflin(weightKg: w, config: config) {
            tdee += (mifflin - tdee) * 0.4
            sources.append("Profile")
            bestSource = .mifflin
        }

        // Step 2b: Weight trend correction
        let trendTDEE = fetchWeightTrendTDEE()
        let consistency = foodLoggingConsistency()
        if let trend = trendTDEE, consistency >= config.loggingConsistencyThreshold {
            tdee += (trend - tdee) * 0.3
            sources.append("Weight Trend")
            bestSource = .blended
        }

        // Step 3: Final
        tdee = max(1200, tdee + config.manualAdjustment)

        let confidence: Estimate.Confidence = sources.count >= 2 ? .medium : .low
        let est = Estimate(tdee: tdee, source: bestSource, confidence: confidence,
                           timestamp: Date(), activeSources: sources)
        current = est; return est
    }

    // MARK: - Apple Health (smart multi-signal, 7-day average)

    private func fetchAppleHealth7DayAvg(config: TDEEConfig) async -> Double? {
        #if targetEnvironment(simulator)
        return nil
        #else
        let hk = HealthKitService.shared
        guard hk.isAvailable else { return nil }

        // Step correction: 0.04 kcal/step baseline, don't scale DOWN for lighter people
        let db = AppDatabase.shared
        let weightKg = (try? db.fetchWeightEntries(from: nil))?.first?.weightKg ?? 70
        let kcalPerStep = 0.04 * max(1.0, weightKg / 70)

        var dailyTotals: [Double] = []
        let calendar = Calendar.current

        for dayOffset in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            guard let burn = try? await hk.fetchCaloriesBurned(for: date) else { continue }
            let steps = (try? await hk.fetchSteps(for: date)) ?? 0

            let resting = burn.basal
            guard resting > 500 else { continue }

            let stepDerivedActive = steps * kcalPerStep
            let active = max(burn.active, stepDerivedActive)
            dailyTotals.append(resting + active)
        }

        guard dailyTotals.count >= 3 else { return nil }
        let avg = dailyTotals.reduce(0, +) / Double(dailyTotals.count)
        return avg * config.appleHealthTrust
        #endif
    }

    // MARK: - Weight Trend + Food Logs (Adaptive TDEE)

    private func fetchWeightTrendTDEE() -> Double? {
        let db = AppDatabase.shared
        guard let entries = try? db.fetchWeightEntries(from: nil), entries.count >= 7 else { return nil }
        let input = entries.map { (date: $0.date, weightKg: $0.weightKg) }
        guard let trend = WeightTrendCalculator.calculateTrend(entries: input) else { return nil }

        let deficit = trend.estimatedDailyDeficit
        let today = Date()
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: today) ?? today

        guard let avgIntake = try? db.averageDailyCalories(
            from: DateFormatters.dateOnly.string(from: twoWeeksAgo),
            to: DateFormatters.dateOnly.string(from: today)),
              avgIntake > 500 else { return nil }

        let tdee = avgIntake - deficit
        return tdee > 800 ? tdee : nil
    }

    // MARK: - Food Logging Consistency

    func foodLoggingConsistency() -> Double {
        let db = AppDatabase.shared
        let today = Date()
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: today) ?? today
        guard let count = try? db.daysWithFoodLogged(
            from: DateFormatters.dateOnly.string(from: twoWeeksAgo),
            to: DateFormatters.dateOnly.string(from: today)) else { return 0 }
        return Double(count) / 14.0
    }

    // MARK: - Cache

    private func cache(_ estimate: Estimate) {
        if let data = try? JSONEncoder().encode(estimate) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadCache() -> Estimate? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let est = try? JSONDecoder().decode(Estimate.self, from: data) else { return nil }
        if Date().timeIntervalSince(est.timestamp) > 6 * 3600 { return nil }
        return est
    }
}
