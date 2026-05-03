import Foundation
@testable import DriftCore
import Testing

@Test func sleepFood_earlyDinnerBetterSleep() {
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (18.0, 7.5), (18.5, 8.0), (17.5, 7.8),   // early dinner
        (21.0, 6.0), (22.0, 5.5), (21.5, 6.2),   // late dinner
        (18.0, 7.2), (21.0, 6.1), (17.5, 7.9), (22.0, 5.8)
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    #expect(result.earlyDinnerCount >= 3)
    #expect(result.lateDinnerCount >= 3)
    if let early = result.earlyDinnerAvgSleep, let late = result.lateDinnerAvgSleep {
        #expect(early > late, "early dinner should correlate with more sleep")
    }
    #expect(result.totalPairs == 10)
}

@Test func sleepFood_insufficientGroupsFallsToPearson() {
    // Only one early dinner day — should fall back to Pearson
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (17.0, 8.0),              // only 1 early
        (21.0, 6.0), (22.0, 5.5), (21.5, 6.2), (20.5, 6.5), (21.0, 6.0)
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    #expect(result.earlyDinnerCount == 1)
    #expect(result.pearsonR != nil, "should compute pearson when groups too small")
}

@Test func sleepFood_uniformTimingReturnsNilPearson() {
    // All meals at same hour → zero variance → pearsonR = nil
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (20.0, 6.5), (20.0, 7.0), (20.0, 6.8), (20.0, 7.2), (20.0, 6.9)
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    #expect(result.pearsonR == nil, "flat meal-hour series → undefined correlation")
}

@Test func sleepFood_formatResultIncludesDiff() {
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (18.0, 7.5), (18.5, 8.0), (17.5, 7.8),
        (21.0, 6.0), (22.0, 5.5), (21.5, 6.2),
        (18.0, 7.2), (21.0, 6.1), (17.5, 7.9), (22.0, 5.8)
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    let text = SleepFoodCorrelationTool.formatResult(result)
    #expect(text.contains("longer"), "output should mention sleep difference")
    #expect(text.contains("8pm") || text.contains("7pm"), "should mention meal time cutoff")
}

@Test func sleepFood_emptyPairsAnalyzesCleanly() {
    let result = SleepFoodCorrelationTool.analyze(pairs: [])
    #expect(result.totalPairs == 0)
    #expect(result.lateDinnerAvgSleep == nil)
    #expect(result.earlyDinnerAvgSleep == nil)
    #expect(result.pearsonR == nil)
}

// MARK: - formatResult branch coverage

@Test func sleepFood_formatResult_lateDinnerBetterSleep() {
    // Late dinner nights have MORE sleep than early — should produce the "interestingly" branch
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (17.0, 5.5), (17.5, 5.8), (17.0, 5.2),   // early dinner, less sleep
        (21.0, 8.0), (22.0, 8.5), (21.5, 7.8),   // late dinner, more sleep
        (17.0, 5.4), (21.0, 8.2), (17.5, 5.6), (22.0, 7.9)
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    let text = SleepFoodCorrelationTool.formatResult(result)
    #expect(text.contains("Interestingly") || text.contains("longer on late dinner"),
            "should take the late-better branch, got: \(text)")
}

@Test func sleepFood_formatResult_noDifferenceBetweenEarlyAndLate() {
    // Roughly equal sleep regardless of dinner time
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (17.0, 7.0), (17.5, 7.1), (17.0, 6.9),
        (21.0, 7.0), (22.0, 7.1), (21.5, 6.9),
        (17.0, 7.0), (21.0, 7.0), (17.5, 7.1), (22.0, 7.0)
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    let text = SleepFoodCorrelationTool.formatResult(result)
    #expect(text.contains("doesn't strongly affect") || text.contains("Dinner timing"),
            "should note no meaningful difference, got: \(text)")
}

@Test func sleepFood_formatResult_pearsonNegativeStrongPattern() {
    // Small groups (< 3 each) so falls through to Pearson, with strong negative correlation
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (17.0, 8.5),              // 1 early
        (21.0, 6.0), (22.0, 5.5), (23.0, 5.0), (21.5, 5.8), (22.5, 5.2)  // 5 late
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    let text = SleepFoodCorrelationTool.formatResult(result)
    // With strong negative r, should recommend finishing meal earlier
    if let r = result.pearsonR, r < -0.3 {
        #expect(text.contains("shorter sleep") || text.contains("2–3 hours"),
                "strong negative correlation should produce recommendation, got: \(text)")
    } else {
        #expect(text.contains("No strong pattern") || text.contains("factor"),
                "weak correlation should note no pattern, got: \(text)")
    }
}

@Test func sleepFood_formatResult_pearsonNilMessage() {
    // Uniform meal timing → pearsonR nil → specific message
    let pairs: [(lastMealHour: Double, sleepHours: Double)] = [
        (20.0, 6.5), (20.0, 7.0)  // only 2 pairs, same hour → nil pearson
    ]
    let result = SleepFoodCorrelationTool.analyze(pairs: pairs)
    #expect(result.pearsonR == nil)
    let text = SleepFoodCorrelationTool.formatResult(result)
    #expect(text.contains("Couldn't compute") || text.contains("consistent"),
            "nil pearsonR should produce fallback message, got: \(text)")
}
