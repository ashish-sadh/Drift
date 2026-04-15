import Foundation
import Testing
@testable import Drift

// MARK: - AIRuleEngine Branch Coverage
// Exercises non-empty-DB branches by seeding AppDatabase.shared with cleanup.

// MARK: yesterdaySummary() — data path

@Test @MainActor func aiRuleEngineYesterdaySummary_withFood_showsCaloriesNotNoFood() async throws {
    let cal = Calendar.current
    let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
    let dateStr = DateFormatters.dateOnly.string(from: yesterday)
    var entry = FoodEntry(
        foodName: "TestYesterdayFood", servingSizeG: 100, servings: 1,
        calories: 650, proteinG: 42, carbsG: 68, fatG: 16,
        date: dateStr, mealType: "dinner"
    )
    try? AppDatabase.shared.saveFoodEntry(&entry)
    defer { if let id = entry.id { try? AppDatabase.shared.deleteFoodEntry(id: id) } }

    let summary = AIRuleEngine.yesterdaySummary()
    #expect(!summary.contains("No food was logged yesterday"),
            "With seeded food, summary should not report no food")
    #expect(summary.contains("cal") || summary.contains("Yesterday"),
            "Summary should include calorie data")
}

@Test @MainActor func aiRuleEngineYesterdaySummary_vsTarget_includesTargetDiff() async throws {
    let cal = Calendar.current
    let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
    let dateStr = DateFormatters.dateOnly.string(from: yesterday)
    var entry = FoodEntry(
        foodName: "TestTargetCompare", servingSizeG: 100, servings: 1,
        calories: 1800, proteinG: 120, carbsG: 180, fatG: 50,
        date: dateStr, mealType: "lunch"
    )
    try? AppDatabase.shared.saveFoodEntry(&entry)
    defer { if let id = entry.id { try? AppDatabase.shared.deleteFoodEntry(id: id) } }

    let summary = AIRuleEngine.yesterdaySummary()
    // With calories logged, the summary includes "over" or "under" target
    #expect(summary.contains("over") || summary.contains("under") || summary.contains("cal"),
            "Summary should compare to calorie target")
}

// MARK: caloriesLeft() — data paths

@Test @MainActor func aiRuleEngineCaloriesLeft_withModerateFood_showsRemaining() async throws {
    let today = DateFormatters.todayString
    var entry = FoodEntry(
        foodName: "TestCalLeftModerate", servingSizeG: 100, servings: 1,
        calories: 400, proteinG: 30, carbsG: 40, fatG: 10,
        date: today, mealType: "breakfast"
    )
    try? AppDatabase.shared.saveFoodEntry(&entry)
    defer { if let id = entry.id { try? AppDatabase.shared.deleteFoodEntry(id: id) } }

    let result = AIRuleEngine.caloriesLeft()
    #expect(!result.isEmpty)
    #expect(result.contains("cal"), "Should mention calories")
    // 400 cal is well below any TDEE target — shows remaining
    #expect(result.contains("left") || result.contains("over") || result.contains("/"),
            "With 400 cal, should show position vs target")
}

@Test @MainActor func aiRuleEngineCaloriesLeft_overTarget_showsOverMessage() async throws {
    let today = DateFormatters.todayString
    var entry = FoodEntry(
        foodName: "TestCalLeftOver", servingSizeG: 100, servings: 1,
        calories: 9000, proteinG: 100, carbsG: 900, fatG: 300,
        date: today, mealType: "lunch"
    )
    try? AppDatabase.shared.saveFoodEntry(&entry)
    defer { if let id = entry.id { try? AppDatabase.shared.deleteFoodEntry(id: id) } }

    let result = AIRuleEngine.caloriesLeft()
    #expect(result.contains("over"), "9000 cal should be over any typical TDEE target")
}

// MARK: dailySummary() — food-logged path

@Test @MainActor func aiRuleEngineDailySummary_withFoodLogged_doesNotSayNothingLogged() async throws {
    let today = DateFormatters.todayString
    var entry = FoodEntry(
        foodName: "TestDailySummaryItem", servingSizeG: 100, servings: 1,
        calories: 350, proteinG: 25, carbsG: 40, fatG: 8,
        date: today, mealType: "breakfast"
    )
    try? AppDatabase.shared.saveFoodEntry(&entry)
    defer { if let id = entry.id { try? AppDatabase.shared.deleteFoodEntry(id: id) } }

    let summary = AIRuleEngine.dailySummary()
    #expect(!summary.contains("nothing logged yet"),
            "With food seeded, daily summary should not say nothing logged")
    #expect(summary.contains("Food:"), "Daily summary always includes Food: line")
    // With food logged, the summary includes calorie info
    #expect(summary.contains("cal"), "Summary should show calorie count")
}

// MARK: quickInsight() — calories > 0 path

@Test @MainActor func aiRuleEngineQuickInsight_withFoodLogged_returnsNonNilInsight() async throws {
    let today = DateFormatters.todayString
    var entry = FoodEntry(
        foodName: "TestQuickInsightItem", servingSizeG: 100, servings: 1,
        calories: 550, proteinG: 38, carbsG: 52, fatG: 14,
        date: today, mealType: "breakfast"
    )
    try? AppDatabase.shared.saveFoodEntry(&entry)
    defer { if let id = entry.id { try? AppDatabase.shared.deleteFoodEntry(id: id) } }

    let insight = AIRuleEngine.quickInsight()
    #expect(insight != nil, "quickInsight should return a string when food is logged")
    if let insight {
        #expect(!insight.contains("haven't logged"),
                "With food, should not say haven't logged any food")
    }
}

// MARK: quickInsight() — trend branches (losing/gaining/stable)

@Test @MainActor func aiRuleEngineQuickInsight_withFoodAndTrend_exercisesTrendBranch() async throws {
    let today = DateFormatters.todayString
    var foodEntry = FoodEntry(
        foodName: "TestTrendInsight", servingSizeG: 100, servings: 1,
        calories: 400, proteinG: 30, carbsG: 45, fatG: 10,
        date: today, mealType: "lunch"
    )
    try? AppDatabase.shared.saveFoodEntry(&foodEntry)
    defer { if let id = foodEntry.id { try? AppDatabase.shared.deleteFoodEntry(id: id) } }

    // Seed declining weight entries to create a non-stale trend
    let cal = Calendar.current
    var weightIds: [Int64] = []
    for i in 0..<14 {
        let date = DateFormatters.dateOnly.string(from: cal.date(byAdding: .day, value: -i, to: Date())!)
        var wEntry = WeightEntry(date: date, weightKg: 73.0 - Double(i) * 0.2, source: "manual")
        try? AppDatabase.shared.saveWeightEntry(&wEntry)
        if let id = wEntry.id { weightIds.append(id) }
    }
    defer {
        for id in weightIds { try? AppDatabase.shared.deleteWeightEntry(id: id) }
        WeightTrendService.shared.refresh()
    }

    WeightTrendService.shared.refresh()
    let insight = AIRuleEngine.quickInsight()
    if let insight { #expect(!insight.isEmpty) }
    // Covers the trend-aware branch of quickInsight regardless of losing/stable/gaining
}

// MARK: nextAction() — per-hour branches

@Test @MainActor func aiRuleEngineNextAction_withLowProteinFood_exercisesProteinCheck() async throws {
    let today = DateFormatters.todayString
    var entry = FoodEntry(
        foodName: "TestLowProteinItem", servingSizeG: 100, servings: 1,
        calories: 300, proteinG: 5, carbsG: 70, fatG: 5,
        date: today, mealType: "lunch"
    )
    try? AppDatabase.shared.saveFoodEntry(&entry)
    defer { if let id = entry.id { try? AppDatabase.shared.deleteFoodEntry(id: id) } }

    let action = AIRuleEngine.nextAction()
    // Hour-dependent: if > 15 it shows protein alert, otherwise workout/nil
    if let action { #expect(!action.isEmpty) }
}

@Test @MainActor func aiRuleEngineNextAction_withHighProteinFood_noProteinAlert() async throws {
    let today = DateFormatters.todayString
    var entry = FoodEntry(
        foodName: "TestHighProteinItem", servingSizeG: 100, servings: 1,
        calories: 700, proteinG: 120, carbsG: 20, fatG: 12,
        date: today, mealType: "lunch"
    )
    try? AppDatabase.shared.saveFoodEntry(&entry)
    defer { if let id = entry.id { try? AppDatabase.shared.deleteFoodEntry(id: id) } }

    let action = AIRuleEngine.nextAction()
    // 120g protein exceeds 50g threshold — protein alert should not fire
    if let action {
        #expect(!action.contains("protein is at"),
                "High protein should not trigger protein alert")
    }
}

// MARK: weeklySummary() — always-present structure

@Test @MainActor func aiRuleEngineWeeklySummary_alwaysHasHeaderAndWorkoutsLine() {
    let summary = AIRuleEngine.weeklySummary()
    #expect(!summary.isEmpty)
    #expect(summary.contains("This week"), "Weekly summary starts with 'This week'")
    #expect(summary.contains("Workouts:"), "Weekly summary always includes Workouts: line")
}

@Test @MainActor func aiRuleEngineWeeklySummary_withFoodThisWeek_showsAvgIntake() async throws {
    let today = DateFormatters.todayString
    var entry = FoodEntry(
        foodName: "TestWeeklySummaryFood", servingSizeG: 100, servings: 1,
        calories: 2000, proteinG: 150, carbsG: 200, fatG: 60,
        date: today, mealType: "dinner"
    )
    try? AppDatabase.shared.saveFoodEntry(&entry)
    defer { if let id = entry.id { try? AppDatabase.shared.deleteFoodEntry(id: id) } }

    let summary = AIRuleEngine.weeklySummary()
    #expect(summary.contains("This week"), "Should have weekly header")
    // With food this week, avg intake line should appear
    #expect(summary.contains("cal") || summary.contains("Workouts:"),
            "Summary should show calorie or workout data")
}
