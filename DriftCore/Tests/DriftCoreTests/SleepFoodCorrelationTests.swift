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
