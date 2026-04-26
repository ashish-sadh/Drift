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
