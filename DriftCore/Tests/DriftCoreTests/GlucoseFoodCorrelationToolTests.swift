import Foundation
@testable import DriftCore
import Testing

// MARK: - Helpers

private func makeEntry(_ name: String, at ts: String) -> FoodEntry {
    FoodEntry(foodName: name, servingSizeG: 100, calories: 200, loggedAt: ts)
}

private func makeReading(_ mgdl: Double, at ts: String) -> GlucoseReading {
    GlucoseReading(timestamp: ts, glucoseMgdl: mgdl, source: "test")
}

// MARK: - correlate() — pure analysis

@Test func glucoseFood_riceSpikesHigherThanEggs() {
    // Rice: pre=90, post=140 (+50) on two separate days
    // Eggs:  pre=85, post=88  (+3)  on two separate days
    let food = [
        makeEntry("rice", at: "2026-04-27T12:00:00Z"),
        makeEntry("rice", at: "2026-04-28T12:00:00Z"),
        makeEntry("eggs", at: "2026-04-27T08:00:00Z"),
        makeEntry("eggs", at: "2026-04-28T08:00:00Z"),
    ]
    let glucose = [
        makeReading(90,  at: "2026-04-27T11:30:00Z"),
        makeReading(140, at: "2026-04-27T13:00:00Z"),
        makeReading(90,  at: "2026-04-28T11:30:00Z"),
        makeReading(140, at: "2026-04-28T13:00:00Z"),
        makeReading(85,  at: "2026-04-27T07:30:00Z"),
        makeReading(88,  at: "2026-04-27T09:00:00Z"),
        makeReading(85,  at: "2026-04-28T07:30:00Z"),
        makeReading(88,  at: "2026-04-28T09:00:00Z"),
    ]
    let result = GlucoseFoodCorrelationTool.correlate(foodEntries: food, glucoseReadings: glucose)
    #expect(result.count == 2, "both foods have 2 samples each")
    #expect(result[0].foodName == "rice", "rice should rank first (highest delta)")
    #expect(result[0].avgDeltaMgdl > 40, "rice delta ~+50 mg/dL")
    #expect(result[1].foodName == "eggs")
    #expect(result[1].avgDeltaMgdl < 10, "eggs delta ~+3 mg/dL")
}

@Test func glucoseFood_foodThatLowersGlucoseRanksLast() {
    // Salad: pre=120, post=100 (−20) on two days — lowers glucose
    // Rice:  pre=90,  post=140 (+50) on two days — spikes
    let food = [
        makeEntry("rice",  at: "2026-04-27T12:00:00Z"),
        makeEntry("rice",  at: "2026-04-28T12:00:00Z"),
        makeEntry("salad", at: "2026-04-27T18:00:00Z"),
        makeEntry("salad", at: "2026-04-28T18:00:00Z"),
    ]
    let glucose = [
        makeReading(90,  at: "2026-04-27T11:30:00Z"),
        makeReading(140, at: "2026-04-27T13:00:00Z"),
        makeReading(90,  at: "2026-04-28T11:30:00Z"),
        makeReading(140, at: "2026-04-28T13:00:00Z"),
        makeReading(120, at: "2026-04-27T17:30:00Z"),
        makeReading(100, at: "2026-04-27T19:00:00Z"),
        makeReading(120, at: "2026-04-28T17:30:00Z"),
        makeReading(100, at: "2026-04-28T19:00:00Z"),
    ]
    let result = GlucoseFoodCorrelationTool.correlate(foodEntries: food, glucoseReadings: glucose)
    #expect(result.count == 2)
    #expect(result.first?.foodName == "rice")
    #expect(result.last?.foodName == "salad")
    #expect(result.last?.avgDeltaMgdl ?? 0 < -10, "salad lowers glucose")
}

@Test func glucoseFood_singleSampleFoodFilteredOut() {
    // Only 1 paired observation for bread → must be filtered (requires ≥ 2)
    let food = [
        makeEntry("bread", at: "2026-04-28T10:00:00Z"),
    ]
    let glucose = [
        makeReading(95,  at: "2026-04-28T09:30:00Z"),
        makeReading(120, at: "2026-04-28T11:00:00Z"),
    ]
    let result = GlucoseFoodCorrelationTool.correlate(foodEntries: food, glucoseReadings: glucose)
    #expect(result.isEmpty, "single sample per food should be filtered out")
}

@Test func glucoseFood_noGlucoseAroundFoodTime() {
    // Glucose readings exist but all > 3h away from the food log → no pairing
    let food = [
        makeEntry("pasta", at: "2026-04-28T12:00:00Z"),
        makeEntry("pasta", at: "2026-04-28T19:00:00Z"),
    ]
    let glucose = [
        makeReading(90, at: "2026-04-28T08:00:00Z"),  // 4h before lunch — outside window
        makeReading(95, at: "2026-04-28T23:00:00Z"),  // 4h after dinner — outside window
    ]
    let result = GlucoseFoodCorrelationTool.correlate(foodEntries: food, glucoseReadings: glucose)
    #expect(result.isEmpty, "no glucose within ±2h → no correlation pairs")
}

@Test func glucoseFood_emptyReadingsReturnsEmpty() {
    let food = [makeEntry("rice", at: "2026-04-28T12:00:00Z")]
    let result = GlucoseFoodCorrelationTool.correlate(foodEntries: food, glucoseReadings: [])
    #expect(result.isEmpty)
}

@Test func glucoseFood_emptyFoodEntriesReturnsEmpty() {
    let readings = [makeReading(100, at: "2026-04-28T12:00:00Z")]
    let result = GlucoseFoodCorrelationTool.correlate(foodEntries: [], glucoseReadings: readings)
    #expect(result.isEmpty)
}

@Test func glucoseFood_sampleCountAccumulates() {
    // Rice logged 3 times, each with surrounding glucose → sampleCount should be 3
    let food = [
        makeEntry("rice", at: "2026-04-26T12:00:00Z"),
        makeEntry("rice", at: "2026-04-27T12:00:00Z"),
        makeEntry("rice", at: "2026-04-28T12:00:00Z"),
    ]
    let glucose = [
        makeReading(90, at: "2026-04-26T11:30:00Z"), makeReading(130, at: "2026-04-26T13:00:00Z"),
        makeReading(90, at: "2026-04-27T11:30:00Z"), makeReading(130, at: "2026-04-27T13:00:00Z"),
        makeReading(90, at: "2026-04-28T11:30:00Z"), makeReading(130, at: "2026-04-28T13:00:00Z"),
    ]
    let result = GlucoseFoodCorrelationTool.correlate(foodEntries: food, glucoseReadings: glucose)
    #expect(result.count == 1)
    #expect(result.first?.sampleCount == 3)
}

// MARK: - format()

@Test func glucoseFood_formatIncludesFoodNameAndDelta() {
    let correlations = [
        GlucoseFoodCorrelationTool.FoodCorrelation(foodName: "rice", avgDeltaMgdl: 45, sampleCount: 3),
        GlucoseFoodCorrelationTool.FoodCorrelation(foodName: "eggs", avgDeltaMgdl: 3, sampleCount: 2),
    ]
    let text = GlucoseFoodCorrelationTool.format(correlations: correlations, readingCount: 20, windowDays: 30)
    #expect(text.contains("Rice") || text.contains("rice"))
    #expect(text.contains("+45"))
    #expect(text.contains("spikes"))
    #expect(text.contains("neutral"))
}

@Test func glucoseFood_formatEmptyReturnsOverlapMessage() {
    let text = GlucoseFoodCorrelationTool.format(correlations: [], readingCount: 10, windowDays: 30)
    #expect(text.lowercased().contains("overlap") || text.lowercased().contains("not enough"))
}

// MARK: - run() with empty DB (no crash, returns need-more-data message)

@Test @MainActor func glucoseFood_runEmptyDbReturnsNeedMoreData() {
    let result = GlucoseFoodCorrelationTool.run(lookbackDays: 30)
    #expect(result.lowercased().contains("need") || result.lowercased().contains("data"),
            "empty DB should return a need-more-data message, got: \(result)")
}

// MARK: - Registration

@Test @MainActor func glucoseFood_toolRegistered() {
    GlucoseFoodCorrelationTool.syncRegistration()
    let tool = ToolRegistry.shared.tool(named: GlucoseFoodCorrelationTool.toolName)
    #expect(tool != nil)
    #expect(tool?.service == "insights")
}
