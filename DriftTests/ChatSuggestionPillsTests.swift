import Foundation
import Testing
@testable import Drift

private func totals(eaten: Int = 0, remaining: Int = 2000, protein: Int = 0) -> DailyTotals {
    DailyTotals(eaten: eaten, target: eaten + remaining, remaining: remaining,
                proteinG: protein, carbsG: 0, fatG: 0, fiberG: 0)
}

// MARK: - Time-window pill selection (10 combos)

@Test @MainActor func pills_breakfastWindow_noBreakfastLogged_showsLogBreakfast() {
    let p = AIChatViewModel.pillsForTimeAndMeals(hour: 8, loggedMeals: [], totals: totals(), workoutToday: false, screen: .food)
    #expect(p.contains("Log breakfast"))
}

@Test @MainActor func pills_breakfastWindow_breakfastAlreadyLogged_noLogBreakfast() {
    let p = AIChatViewModel.pillsForTimeAndMeals(hour: 8, loggedMeals: ["breakfast"], totals: totals(eaten: 400), workoutToday: false, screen: .food)
    #expect(!p.contains("Log breakfast"))
}

@Test @MainActor func pills_lunchWindow_noLunchLogged_showsLogLunch() {
    let p = AIChatViewModel.pillsForTimeAndMeals(hour: 12, loggedMeals: ["breakfast"], totals: totals(eaten: 400), workoutToday: false, screen: .food)
    #expect(p.contains("Log lunch"))
}

@Test @MainActor func pills_lunchWindow_lunchLogged_noLogLunch() {
    let p = AIChatViewModel.pillsForTimeAndMeals(hour: 12, loggedMeals: ["breakfast", "lunch"], totals: totals(eaten: 800), workoutToday: false, screen: .food)
    #expect(!p.contains("Log lunch"))
}

@Test @MainActor func pills_dinnerWindow_noDinnerLogged_showsLogDinner() {
    let p = AIChatViewModel.pillsForTimeAndMeals(hour: 18, loggedMeals: ["breakfast", "lunch"], totals: totals(eaten: 1200), workoutToday: false, screen: .food)
    #expect(p.contains("Log dinner"))
}

@Test @MainActor func pills_dinnerWindow_dinnerLogged_noLogDinner() {
    let p = AIChatViewModel.pillsForTimeAndMeals(hour: 18, loggedMeals: ["breakfast", "lunch", "dinner"], totals: totals(eaten: 1800), workoutToday: false, screen: .food)
    #expect(!p.contains("Log dinner"))
}

@Test @MainActor func pills_lateEvening_workoutToday_showsDailySummary() {
    let p = AIChatViewModel.pillsForTimeAndMeals(hour: 21, loggedMeals: ["breakfast", "lunch", "dinner"], totals: totals(eaten: 2000), workoutToday: true, screen: .food)
    #expect(p.contains("Daily summary"))
    #expect(p.contains("How's my protein?"))
}

@Test @MainActor func pills_lateEvening_noWorkout_noRecapPills() {
    let p = AIChatViewModel.pillsForTimeAndMeals(hour: 21, loggedMeals: [], totals: totals(), workoutToday: false, screen: .food)
    #expect(!p.contains("Daily summary") || !p.contains("How's my protein?"))
}

@Test @MainActor func pills_nothingEaten_earlyMorning_showsLogBreakfast() {
    let p = AIChatViewModel.pillsForTimeAndMeals(hour: 6, loggedMeals: [], totals: totals(), workoutToday: false, screen: .dashboard)
    #expect(p.contains("Log breakfast"))
}

@Test @MainActor func pills_exerciseScreen_omitsSmartWorkout() {
    let p = AIChatViewModel.pillsForTimeAndMeals(hour: 10, loggedMeals: [], totals: totals(), workoutToday: false, screen: .exercise)
    #expect(!p.contains("Start smart workout"))
}
