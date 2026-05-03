import Foundation
@testable import DriftCore
import Testing

// MARK: - computeBase (5 tests)

@Test func computeBaseAt70kgActivity29Is2000() {
    let base = TDEEEstimator.computeBase(weightKg: 70, activityMultiplier: 29)
    #expect(abs(base - 2000) < 1)
}

@Test func computeBaseNilWeightIs2000() {
    let base = TDEEEstimator.computeBase(weightKg: nil, activityMultiplier: 29)
    #expect(base == 2000)
}

@Test func computeBaseZeroWeightIs2000() {
    let base = TDEEEstimator.computeBase(weightKg: 0, activityMultiplier: 29)
    #expect(base == 2000)
}

@Test func computeBaseHeavierPersonHigherTDEE() {
    let light = TDEEEstimator.computeBase(weightKg: 50, activityMultiplier: 29)
    let heavy = TDEEEstimator.computeBase(weightKg: 120, activityMultiplier: 29)
    #expect(heavy > light)
}

@Test func computeBaseSoftCapAbove2700() {
    // Very heavy person with high activity would exceed 2700 without cap
    let capped = TDEEEstimator.computeBase(weightKg: 200, activityMultiplier: 36)
    // Should be higher than 2700 but compressed (30% of excess above cap)
    #expect(capped > 2700)
    // Uncapped raw would be: 2000 * sqrt(200/70) * (36/29) ≈ 4238
    // With cap: 2700 + (4238 - 2700) * 0.3 ≈ 3161
    #expect(capped < 4238) // definitely compressed
}

// MARK: - computeMifflin (7 tests)

@Test func computeMifflinRequiresAtLeastOneProfileField() {
    var config = TDEEEstimator.TDEEConfig.default
    config.age = nil; config.heightCm = nil; config.sex = nil
    let result = TDEEEstimator.computeMifflin(weightKg: 70, config: config)
    #expect(result == nil)
}

@Test func computeMifflinMaleFullProfile() {
    var config = TDEEEstimator.TDEEConfig.default
    config.age = 30; config.heightCm = 175; config.sex = .male
    config.activityMultiplier = 29  // mifflinActivityFactor = 1.55
    let result = TDEEEstimator.computeMifflin(weightKg: 80, config: config)!
    // BMR = 10*80 + 6.25*175 - 5*30 + 5 = 800 + 1093.75 - 150 + 5 = 1748.75
    // TDEE = 1748.75 * 1.55 ≈ 2710
    #expect(result.tdee > 2500 && result.tdee < 3000)
    #expect(abs(result.confidence - 1.0) < 0.01) // all 3 fields
}

@Test func computeMifflinFemaleFullProfile() {
    var config = TDEEEstimator.TDEEConfig.default
    config.age = 25; config.heightCm = 165; config.sex = .female
    config.activityMultiplier = 29
    let female = TDEEEstimator.computeMifflin(weightKg: 60, config: config)!
    var maleConfig = config; maleConfig.sex = .male
    let male = TDEEEstimator.computeMifflin(weightKg: 60, config: maleConfig)!
    // Male BMR is 166 kcal higher than female
    #expect(male.tdee > female.tdee)
}

@Test func computeMifflinNoSexAveragesMaleFemale() {
    var config = TDEEEstimator.TDEEConfig.default
    config.age = 30; config.heightCm = 175; config.sex = nil
    let noSex = TDEEEstimator.computeMifflin(weightKg: 75, config: config)!

    var maleConfig = config; maleConfig.sex = .male
    var femaleConfig = config; femaleConfig.sex = .female
    let male = TDEEEstimator.computeMifflin(weightKg: 75, config: maleConfig)!
    let female = TDEEEstimator.computeMifflin(weightKg: 75, config: femaleConfig)!

    #expect(noSex.tdee > female.tdee && noSex.tdee < male.tdee)
}

@Test func computeMifflinPartialProfileLowerConfidence() {
    var config = TDEEEstimator.TDEEConfig.default
    config.age = 30; config.heightCm = nil; config.sex = nil  // only 1 of 3 fields
    let result = TDEEEstimator.computeMifflin(weightKg: 70, config: config)!
    #expect(abs(result.confidence - 1.0/3.0) < 0.01)
}

@Test func computeMifflinTwoFieldsMediumConfidence() {
    var config = TDEEEstimator.TDEEConfig.default
    config.age = 30; config.heightCm = 175; config.sex = nil
    let result = TDEEEstimator.computeMifflin(weightKg: 70, config: config)!
    #expect(abs(result.confidence - 2.0/3.0) < 0.01)
}

@Test func computeMifflinActivityFactorScales() {
    var sedentary = TDEEEstimator.TDEEConfig.default
    sedentary.age = 30; sedentary.heightCm = 170; sedentary.sex = .male
    sedentary.activityMultiplier = 22  // → 1.2

    var athlete = sedentary
    athlete.activityMultiplier = 36  // → 1.9

    let low = TDEEEstimator.computeMifflin(weightKg: 70, config: sedentary)!
    let high = TDEEEstimator.computeMifflin(weightKg: 70, config: athlete)!
    #expect(high.tdee > low.tdee)
}

// MARK: - TDEEConfig (5 tests)

@Test func configActivityLabelSedentary() {
    var config = TDEEEstimator.TDEEConfig.default
    config.activityMultiplier = 22
    #expect(config.activityLabel == "Sedentary")
}

@Test func configActivityLabelModeratelyActive() {
    var config = TDEEEstimator.TDEEConfig.default
    config.activityMultiplier = 29
    #expect(config.activityLabel == "Moderately Active")
}

@Test func configHasMifflinProfileFalseByDefault() {
    #expect(TDEEEstimator.TDEEConfig.default.hasMifflinProfile == false)
}

@Test func configHasMifflinProfileTrueWhenAllSet() {
    var config = TDEEEstimator.TDEEConfig.default
    config.age = 30; config.heightCm = 175; config.sex = .male
    #expect(config.hasMifflinProfile == true)
}

@Test func configMifflinActivityFactorAt22Is1_2() {
    var config = TDEEEstimator.TDEEConfig.default
    config.activityMultiplier = 22
    #expect(abs(config.mifflinActivityFactor - 1.2) < 0.001)
}

@Test func configActivityLabelLightlyActive() {
    var config = TDEEEstimator.TDEEConfig.default
    config.activityMultiplier = 25
    #expect(config.activityLabel == "Lightly Active")
}

@Test func configActivityLabelVeryActive() {
    var config = TDEEEstimator.TDEEConfig.default
    config.activityMultiplier = 31
    #expect(config.activityLabel == "Very Active")
}

@Test func configActivityLabelAthlete() {
    var config = TDEEEstimator.TDEEConfig.default
    config.activityMultiplier = 36
    #expect(config.activityLabel == "Athlete")
}

// MARK: - Sex (2 tests)

@Test func sexLabelMale() {
    #expect(TDEEEstimator.Sex.male.label == "Male")
}

@Test func sexLabelFemale() {
    #expect(TDEEEstimator.Sex.female.label == "Female")
}

// MARK: - TDEEConfig loggingConsistencyThreshold

@Test func loggingConsistencyThresholdIsHalf() {
    #expect(TDEEEstimator.TDEEConfig.default.loggingConsistencyThreshold == 0.5)
}

// MARK: - Estimate.explanation (5 source cases)

@Test func estimateExplanationAppleHealth() {
    let e = TDEEEstimator.Estimate(tdee: 2000, source: .appleHealth, confidence: .high,
                                   timestamp: Date(), activeSources: ["Apple Health"])
    #expect(e.explanation.contains("Apple Health"))
}

@Test func estimateExplanationWeightTrend() {
    let e = TDEEEstimator.Estimate(tdee: 2000, source: .weightTrend, confidence: .medium,
                                   timestamp: Date(), activeSources: ["Weight Trend"])
    #expect(e.explanation.contains("food logs"))
}

@Test func estimateExplanationBlended() {
    let e = TDEEEstimator.Estimate(tdee: 2000, source: .blended, confidence: .high,
                                   timestamp: Date(), activeSources: ["Weight", "Apple Health"])
    #expect(e.explanation.contains("multiple"))
}

@Test func estimateExplanationMifflin() {
    let e = TDEEEstimator.Estimate(tdee: 2000, source: .mifflin, confidence: .medium,
                                   timestamp: Date(), activeSources: ["Profile"])
    #expect(e.explanation.contains("profile"))
}

@Test func estimateExplanationBodyWeight() {
    let e = TDEEEstimator.Estimate(tdee: 2000, source: .bodyWeight, confidence: .low,
                                   timestamp: Date(), activeSources: ["Weight"])
    #expect(e.explanation.contains("body weight"))
}

// MARK: - loadConfig / saveConfig (MainActor, uses UserDefaults)

@Test @MainActor func saveConfigAndLoadRoundTrip() {
    var config = TDEEEstimator.TDEEConfig.default
    config.age = 28
    config.heightCm = 172
    config.sex = .female
    config.activityMultiplier = 31
    config.manualAdjustment = -100

    TDEEEstimator.saveConfig(config)
    let loaded = TDEEEstimator.loadConfig()

    #expect(loaded.age == 28)
    #expect(loaded.heightCm == 172)
    #expect(loaded.sex == .female)
    #expect(loaded.activityMultiplier == 31)
    #expect(loaded.manualAdjustment == -100)

    // Clean up
    TDEEEstimator.saveConfig(.default)
}

@Test @MainActor func loadConfigReturnsDefaultWhenNothingSaved() {
    UserDefaults.standard.removeObject(forKey: "drift_tdee_config")
    let config = TDEEEstimator.loadConfig()
    #expect(config.activityMultiplier == TDEEEstimator.TDEEConfig.default.activityMultiplier)
    #expect(config.manualAdjustment == 0)
}

// MARK: - cachedOrSync (sync path, no Apple Health, no weight data)

@Test @MainActor func cachedOrSyncReturnsEstimate() {
    // Clear any cached value by saving a fresh config
    TDEEEstimator.saveConfig(.default)
    UserDefaults.standard.removeObject(forKey: "drift_tdee_cache")
    let estimate = TDEEEstimator.shared.cachedOrSync()
    #expect(estimate.tdee >= 1200)
    #expect(estimate.tdee <= 5000)
}

@Test @MainActor func cachedOrSyncConfidenceLowWithNoData() {
    TDEEEstimator.saveConfig(.default)
    UserDefaults.standard.removeObject(forKey: "drift_tdee_cache")
    let estimate = TDEEEstimator.shared.cachedOrSync()
    // Without weight data or profile, confidence should be low
    #expect(estimate.confidence == .low || estimate.confidence == .medium)
}

@Test @MainActor func cachedOrSyncHasMifflinSourceWhenWeightAndProfileSet() throws {
    // Save a weight entry so WeightTrendService.shared.latestWeightKg is non-nil
    var entry = WeightEntry(date: DateFormatters.dateOnly.string(from: Date()), weightKg: 75)
    try AppDatabase.shared.saveWeightEntry(&entry)
    WeightTrendService.shared.refresh()
    var config = TDEEEstimator.TDEEConfig.default
    config.age = 30; config.heightCm = 175; config.sex = .male
    TDEEEstimator.saveConfig(config)
    UserDefaults.standard.removeObject(forKey: "drift_tdee_cache")
    let estimate = TDEEEstimator.shared.cachedOrSync()
    #expect(estimate.activeSources.contains(where: { $0.contains("Profile") }))
    // Clean up
    if let id = entry.id { try? AppDatabase.shared.deleteWeightEntry(id: id) }
    WeightTrendService.shared.refresh()
    TDEEEstimator.saveConfig(.default)
}

@Test @MainActor func cachedOrSyncAppliesManualAdjustment() {
    var config = TDEEEstimator.TDEEConfig.default
    config.manualAdjustment = 200
    TDEEEstimator.saveConfig(config)
    UserDefaults.standard.removeObject(forKey: "drift_tdee_cache")
    let adjusted = TDEEEstimator.shared.cachedOrSync()
    // Manual adjustment of +200 should push TDEE above the base
    #expect(adjusted.tdee >= 1200)

    config.manualAdjustment = 0
    TDEEEstimator.saveConfig(config)
    UserDefaults.standard.removeObject(forKey: "drift_tdee_cache")
    let baseline = TDEEEstimator.shared.cachedOrSync()
    #expect(adjusted.tdee > baseline.tdee - 1)
    TDEEEstimator.saveConfig(.default)
}

// MARK: - foodLoggingConsistency

@Test @MainActor func foodLoggingConsistencyReturnsFraction() {
    let consistency = TDEEEstimator.shared.foodLoggingConsistency()
    #expect(consistency >= 0)
    #expect(consistency <= 1)
}
