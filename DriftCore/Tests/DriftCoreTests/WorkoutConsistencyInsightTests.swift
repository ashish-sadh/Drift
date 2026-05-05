import Foundation
@testable import DriftCore
import Testing

// MARK: - WorkoutConsistencyInsight Tests (Tier 0)
// Tests BehaviorInsightService.workoutConsistencyVariant() — pure logic,
// no database. Covers: nil guard, streak, on-track, behind, zero-this-week.

private func fakeWeeks(_ counts: [Int]) -> [(weekStart: Date, count: Int)] {
    let cal = Calendar.current
    let now = cal.dateInterval(of: .weekOfYear, for: Date())!.start
    return counts.enumerated().map { idx, count in
        let offset = counts.count - 1 - idx
        let weekStart = cal.date(byAdding: .weekOfYear, value: -offset, to: now)!
        return (weekStart, count)
    }
}

@MainActor
@Test func workoutConsistency_noHistory_returnsNil() {
    // All zeros = no history
    let insight = BehaviorInsightService.workoutConsistencyVariant(
        weeklyCounts: fakeWeeks([0, 0, 0, 0, 0]),
        weeklyGoal: 3, daysLeftInWeek: 5)
    #expect(insight == nil)
}

@MainActor
@Test func workoutConsistency_emptyArray_returnsNil() {
    let insight = BehaviorInsightService.workoutConsistencyVariant(
        weeklyCounts: [], weeklyGoal: 3, daysLeftInWeek: 5)
    #expect(insight == nil)
}

@MainActor
@Test func workoutConsistency_onTrack_noStreakYet() {
    // 3 this week (meets goal), prior weeks had <3 → no streak milestone
    let insight = BehaviorInsightService.workoutConsistencyVariant(
        weeklyCounts: fakeWeeks([1, 0, 2, 1, 3]),
        weeklyGoal: 3, daysLeftInWeek: 3)
    #expect(insight?.title == "Workout goal hit")
    #expect(insight?.isPositive == true)
}

@MainActor
@Test func workoutConsistency_streakMilestone_twoWeeks() {
    // Prior week met goal, this week meets goal → streak = 2
    let insight = BehaviorInsightService.workoutConsistencyVariant(
        weeklyCounts: fakeWeeks([0, 0, 1, 3, 3]),
        weeklyGoal: 3, daysLeftInWeek: 2)
    #expect(insight?.title.contains("2 weeks") == true)
    #expect(insight?.isPositive == true)
}

@MainActor
@Test func workoutConsistency_streakMilestone_threeWeeks() {
    let insight = BehaviorInsightService.workoutConsistencyVariant(
        weeklyCounts: fakeWeeks([0, 3, 3, 3, 3]),
        weeklyGoal: 3, daysLeftInWeek: 4)
    // 3 prior weeks met goal + this week = streak 4
    #expect(insight?.title.contains("4 weeks") == true)
    #expect(insight?.isPositive == true)
}

@MainActor
@Test func workoutConsistency_behind_partial() {
    // 1 workout this week, goal is 3, 4 days left
    let insight = BehaviorInsightService.workoutConsistencyVariant(
        weeklyCounts: fakeWeeks([3, 2, 1, 3, 1]),
        weeklyGoal: 3, daysLeftInWeek: 4)
    #expect(insight?.title == "Workout goal in reach")
    #expect(insight?.isPositive == false)
    #expect(insight?.detail.contains("2 to go") == true)
}

@MainActor
@Test func workoutConsistency_behind_zeroThisWeek_withHistory() {
    // 0 workouts this week, history exists, days left
    let insight = BehaviorInsightService.workoutConsistencyVariant(
        weeklyCounts: fakeWeeks([3, 2, 1, 2, 0]),
        weeklyGoal: 3, daysLeftInWeek: 5)
    #expect(insight?.title == "Start your workout week")
    #expect(insight?.isPositive == false)
}

@MainActor
@Test func workoutConsistency_noDaysLeft_returnsNil() {
    // Week is over and goal not met — no nagging after the fact
    let insight = BehaviorInsightService.workoutConsistencyVariant(
        weeklyCounts: fakeWeeks([3, 3, 2, 1, 1]),
        weeklyGoal: 3, daysLeftInWeek: 0)
    #expect(insight == nil)
}

@MainActor
@Test func workoutConsistency_streakBreaksOnMissedWeek() {
    // Prior weeks: 3, 0, 3 — streak breaks at 0 so priorStreak = 1 only
    let insight = BehaviorInsightService.workoutConsistencyVariant(
        weeklyCounts: fakeWeeks([3, 0, 3, 3, 3]),
        weeklyGoal: 3, daysLeftInWeek: 3)
    // priorStreak = consecutive from newest prior = 2 (weeks at idx 2,3), + this week = 3
    // [3,0,3,3] prior: reversed = [3,3,0,3] → streak = 2, total = 3
    #expect(insight?.title.contains("3 weeks") == true)
}
