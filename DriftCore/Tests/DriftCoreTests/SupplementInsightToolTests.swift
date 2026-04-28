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
