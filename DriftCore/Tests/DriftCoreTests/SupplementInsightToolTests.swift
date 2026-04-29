import Foundation
@testable import DriftCore
import Testing

@Test func supplementInsight_fullAdherence() {
    let dates = Set(["2026-04-01", "2026-04-02", "2026-04-03", "2026-04-04", "2026-04-05"])
    let stats = SupplementInsightTool.adherenceStats(
        takenDates: dates, startDate: "2026-04-01", endDate: "2026-04-05", today: "2026-04-05")
    #expect(stats.takenDays == 5)
    #expect(stats.totalDays == 5)
    #expect(stats.adherencePct == 100)
    #expect(stats.currentStreak == 5)
    #expect(stats.longestStreak == 5)
    #expect(stats.lastMissedDate == nil)
}

@Test func supplementInsight_zeroAdherence() {
    let stats = SupplementInsightTool.adherenceStats(
        takenDates: [], startDate: "2026-04-01", endDate: "2026-04-05", today: "2026-04-05")
    #expect(stats.takenDays == 0)
    #expect(stats.adherencePct == 0)
    #expect(stats.currentStreak == 0)
    #expect(stats.longestStreak == 0)
    #expect(stats.lastMissedDate == "2026-04-05")
}

@Test func supplementInsight_partialAdherence() {
    // Taken Mon/Wed/Fri out of 5 days = 60%
    let taken: Set<String> = ["2026-04-01", "2026-04-03", "2026-04-05"]
    let stats = SupplementInsightTool.adherenceStats(
        takenDates: taken, startDate: "2026-04-01", endDate: "2026-04-05", today: "2026-04-05")
    #expect(stats.takenDays == 3)
    #expect(stats.adherencePct == 60)
    #expect(stats.lastMissedDate == "2026-04-04", "last miss before today is Apr 4")
}

@Test func supplementInsight_streakCalculation() {
    // Missed Apr 2, taken Apr 3-5 → current streak = 3
    let taken: Set<String> = ["2026-04-01", "2026-04-03", "2026-04-04", "2026-04-05"]
    let stats = SupplementInsightTool.adherenceStats(
        takenDates: taken, startDate: "2026-04-01", endDate: "2026-04-05", today: "2026-04-05")
    #expect(stats.currentStreak == 3)
    #expect(stats.longestStreak == 3)
}

@Test func supplementInsight_longestStreakAcrossWindow() {
    // Best run is Apr 3-5 (3 days); current streak is 0 (missed today)
    let taken: Set<String> = ["2026-04-01", "2026-04-03", "2026-04-04", "2026-04-05"]
    let stats = SupplementInsightTool.adherenceStats(
        takenDates: taken, startDate: "2026-04-01", endDate: "2026-04-06", today: "2026-04-06")
    #expect(stats.currentStreak == 0, "today (Apr 6) not taken")
    #expect(stats.longestStreak == 3)
}

// MARK: - Routing gold set (parseResponse — no LLM, deterministic)

@Test func supplementInsight_routing_withSupplementName() {
    let intent = IntentClassifier.parseResponse(#"{"tool":"supplement_insight","supplement":"creatine"}"#)
    #expect(intent?.tool == "supplement_insight")
    #expect(intent?.params["supplement"] == "creatine")
}

@Test func supplementInsight_routing_vitaminDStreak() {
    let intent = IntentClassifier.parseResponse(#"{"tool":"supplement_insight","supplement":"vitamin d","window_days":"14"}"#)
    #expect(intent?.tool == "supplement_insight")
    #expect(intent?.params["supplement"] == "vitamin d")
    #expect(intent?.params["window_days"] == "14")
}

@Test func supplementInsight_routing_overallAdherence() {
    // No supplement param → overall adherence query
    let intent = IntentClassifier.parseResponse(#"{"tool":"supplement_insight"}"#)
    #expect(intent?.tool == "supplement_insight")
    #expect(intent?.params["supplement"] == nil)
}

@Test func supplementInsight_routing_omega3ThisWeek() {
    let intent = IntentClassifier.parseResponse(#"{"tool":"supplement_insight","supplement":"omega 3","window_days":"7"}"#)
    #expect(intent?.tool == "supplement_insight")
    #expect(intent?.params["supplement"] == "omega 3")
    #expect(intent?.params["window_days"] == "7")
}

@Test func supplementInsight_routing_magnesiumThirtyDays() {
    let intent = IntentClassifier.parseResponse(#"{"tool":"supplement_insight","supplement":"magnesium","window_days":"30"}"#)
    #expect(intent?.tool == "supplement_insight")
    #expect(intent?.params["supplement"] == "magnesium")
    #expect(intent?.params["window_days"] == "30")
}

// MARK: - clampWindow

@Test func supplementInsight_clampWindow_defaultsToThirty() {
    #expect(SupplementInsightTool.clampWindow(nil) == 30)
}

@Test func supplementInsight_clampWindow_smallValueClampsToSeven() {
    #expect(SupplementInsightTool.clampWindow(3) == 7)
    #expect(SupplementInsightTool.clampWindow(10) == 7)
}

@Test func supplementInsight_clampWindow_midRangeClampsToFourteen() {
    #expect(SupplementInsightTool.clampWindow(11) == 14)
    #expect(SupplementInsightTool.clampWindow(21) == 14)
}

@Test func supplementInsight_clampWindow_largeValueClampsToThirty() {
    #expect(SupplementInsightTool.clampWindow(22) == 30)
    #expect(SupplementInsightTool.clampWindow(90) == 30)
}

// MARK: - formatSingle

@Test func supplementInsight_formatSingle_perfectAdherenceLabel() {
    let stats = SupplementInsightTool.AdherenceStats(
        takenDays: 7, totalDays: 7, adherencePct: 100,
        currentStreak: 7, longestStreak: 7, lastMissedDate: nil)
    let text = SupplementInsightTool.formatSingle(name: "Creatine", stats: stats, windowDays: 7)
    #expect(text.contains("Perfect adherence"))
}

@Test func supplementInsight_formatSingle_lowAdherenceTip() {
    let stats = SupplementInsightTool.AdherenceStats(
        takenDays: 2, totalDays: 7, adherencePct: 28,
        currentStreak: 0, longestStreak: 2, lastMissedDate: "2026-04-28")
    let text = SupplementInsightTool.formatSingle(name: "Vitamin D", stats: stats, windowDays: 7)
    #expect(text.contains("same time each day"))
}
