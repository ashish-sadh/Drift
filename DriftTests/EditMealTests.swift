import Foundation
import Testing
@testable import Drift

// MARK: - FoodService.editMealEntry Tests
// Seeds AppDatabase.shared with today's meal logs, exercises edit paths,
// cleans up via MealLog cascade.

@MainActor
@discardableResult
private func seedTodayMeal(
    mealType: String,
    foodName: String,
    servingSizeG: Double = 100,
    servings: Double = 1,
    calories: Double = 200,
    proteinG: Double = 10
) -> Int64? {
    let today = DateFormatters.todayString
    var mealLog = MealLog(date: today, mealType: mealType)
    try? AppDatabase.shared.saveMealLog(&mealLog)
    guard let mlId = mealLog.id else { return nil }
    var entry = FoodEntry(
        mealLogId: mlId, foodName: foodName,
        servingSizeG: servingSizeG, servings: servings,
        calories: calories, proteinG: proteinG,
        loggedAt: ISO8601DateFormatter().string(from: Date()),
        date: today, mealType: mealType
    )
    try? AppDatabase.shared.saveFoodEntry(&entry)
    return mlId
}

@MainActor
private func cleanupMeal(_ id: Int64?) {
    guard let id else { return }
    try? AppDatabase.shared.deleteMealLog(id: id)
}

// MARK: Remove

@Test @MainActor func editMealRemoveFromSpecificMeal() {
    let mlId = seedTodayMeal(mealType: "lunch", foodName: "TestRice4Edit", calories: 260)
    defer { cleanupMeal(mlId) }

    let result = FoodService.editMealEntry(
        mealPeriod: "lunch", targetFood: "TestRice4Edit",
        action: "remove", newValue: nil
    )
    #expect(result.contains("Removed"))
    #expect(result.contains("lunch"))
}

// MARK: Update Quantity

@Test @MainActor func editMealUpdateServings() {
    let mlId = seedTodayMeal(mealType: "dinner", foodName: "TestChicken4Edit", servings: 1)
    defer { cleanupMeal(mlId) }

    let result = FoodService.editMealEntry(
        mealPeriod: "dinner", targetFood: "TestChicken4Edit",
        action: "update_quantity", newValue: "2"
    )
    #expect(result.contains("Updated"))
    #expect(result.contains("2 servings"))
}

@Test @MainActor func editMealUpdateGramsConvertsToServings() {
    // 200g entry seeded — change to 400g should become servings = 2
    let mlId = seedTodayMeal(mealType: "breakfast", foodName: "TestOats4Edit", servingSizeG: 200, servings: 1)
    defer { cleanupMeal(mlId) }

    let result = FoodService.editMealEntry(
        mealPeriod: "breakfast", targetFood: "TestOats4Edit",
        action: "update_quantity", newValue: "400g"
    )
    #expect(result.contains("Updated"))
    #expect(result.contains("2 servings"))
}

// MARK: Errors

@Test @MainActor func editMealFoodNotFound() {
    // No need to seed — searching for something that doesn't exist
    let result = FoodService.editMealEntry(
        mealPeriod: "lunch", targetFood: "xyzzy_does_not_exist_9999",
        action: "remove", newValue: nil
    )
    // Either "No food logged today." or "No lunch logged today." or "Couldn't find"
    #expect(result.contains("No food") || result.contains("No lunch") || result.contains("Couldn't find"))
}

@Test @MainActor func editMealUpdateMissingNewValue() {
    let mlId = seedTodayMeal(mealType: "snack", foodName: "TestSnack4Edit")
    defer { cleanupMeal(mlId) }

    let result = FoodService.editMealEntry(
        mealPeriod: "snack", targetFood: "TestSnack4Edit",
        action: "update_quantity", newValue: nil
    )
    #expect(result.contains("Missing") || result.contains("quantity"))
}
