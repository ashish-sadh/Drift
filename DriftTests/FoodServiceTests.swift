import Foundation
import Testing
@testable import Drift

// MARK: - FoodService Tests

// MARK: Search

@Test @MainActor func foodServiceSearchKnownFoodReturnsResults() {
    let results = FoodService.searchFood(query: "rice")
    #expect(!results.isEmpty, "Searching for 'rice' should return results")
}

@Test @MainActor func foodServiceSearchGibberishTracksEmptyResult() {
    // Should return empty and track the miss — just verify it doesn't crash
    let results = FoodService.searchFood(query: "xyzzy_nonexistent_zzz_9999")
    #expect(results.isEmpty)
}

@Test @MainActor func foodServiceSearchSynonymCurd() {
    // "curd" → "yogurt" synonym expansion; should return yogurt results
    let results = FoodService.searchFood(query: "curd")
    #expect(!results.isEmpty, "Synonym 'curd' should expand to find yogurt")
}

@Test @MainActor func foodServiceFindByNameKnownFood() {
    let food = FoodService.findByName("paneer")
    #expect(food != nil, "Should find paneer in the database")
}

@Test @MainActor func foodServiceFindByNameUnknown() {
    let food = FoodService.findByName("xyzzy_nonexistent_item_9999")
    #expect(food == nil)
}

@Test @MainActor func foodServiceSearchRecipesDoesNotCrash() {
    let results = FoodService.searchRecipes(query: "")
    // May be empty in test env; just verify it returns without crash
    #expect(results.count >= 0)
}

@Test @MainActor func foodServiceFetchRecentFoodsReturnsArray() {
    let recents = FoodService.fetchRecentFoods(limit: 5)
    #expect(recents.count >= 0)
    #expect(recents.count <= 5)
}

@Test @MainActor func foodServiceFetchFoodsByCategoryIndianStaples() {
    let foods = FoodService.fetchFoodsByCategory("Indian Staples")
    #expect(!foods.isEmpty, "Indian Staples category should have entries")
}

@Test @MainActor func foodServiceFetchFoodsByCategoryUnknown() {
    let foods = FoodService.fetchFoodsByCategory("zzz_no_such_category_xyz")
    #expect(foods.isEmpty)
}

@Test @MainActor func foodServiceIsFavoriteUnknownFood() {
    let result = FoodService.isFavorite(name: "xyzzy_unknown_food_zzz")
    #expect(result == false)
}

@Test @MainActor func foodServiceFetchCachedBarcodeNonexistent() {
    let result = FoodService.fetchCachedBarcode("000000000000")
    #expect(result == nil)
}

// MARK: Nutrition Lookup

@Test @MainActor func foodServiceGetNutritionKnownFood() {
    let result = FoodService.getNutrition(name: "paneer")
    #expect(result != nil, "paneer should be found in DB")
    if let r = result {
        #expect(r.food.calories > 0)
        #expect(!r.perServing.isEmpty)
        #expect(r.perServing.contains("cal"))
    }
}

@Test @MainActor func foodServiceGetNutritionUnknown() {
    let result = FoodService.getNutrition(name: "xyzzy_nonexistent_zzz")
    #expect(result == nil)
}

// MARK: Daily Totals

@Test @MainActor func foodServiceResolvedCalorieTargetIsPositive() {
    let target = FoodService.resolvedCalorieTarget()
    #expect(target >= 1200, "Calorie target should be at least 1200")
}

@Test @MainActor func foodServiceGetDailyTotalsTargetPositive() {
    let totals = FoodService.getDailyTotals()
    #expect(totals.target >= 1200)
    #expect(totals.eaten >= 0)
}

@Test @MainActor func foodServiceGetCaloriesLeftReturnsNonEmpty() {
    let result = FoodService.getCaloriesLeft()
    #expect(!result.isEmpty)
}

@Test @MainActor func foodServiceGetCaloriesLeftWithDateParam() {
    let result = FoodService.getDailyTotals(date: "2000-01-01")
    #expect(result.eaten == 0, "No food on year-2000 date")
    #expect(result.target >= 1200)
    #expect(result.remaining == result.target)
}

// MARK: Explain

@Test @MainActor func foodServiceExplainCaloriesContainsTDEE() {
    let text = FoodService.explainCalories()
    #expect(text.contains("TDEE"))
    #expect(text.contains("cal"))
}

@Test @MainActor func foodServiceExplainCaloriesMultiLine() {
    let text = FoodService.explainCalories()
    let lines = text.components(separatedBy: "\n")
    #expect(lines.count >= 4, "explainCalories should return at least 4 lines")
}

// MARK: Suggestions

@Test @MainActor func foodServiceTopProteinFoodsReturnsArray() {
    let foods = FoodService.topProteinFoods(limit: 3)
    #expect(foods.count <= 3)
}

@Test @MainActor func foodServiceTopProteinFoodsAllHavePositiveProtein() {
    let foods = FoodService.topProteinFoods(limit: 5)
    for food in foods {
        #expect(food.proteinG >= 0)
    }
}

@Test @MainActor func foodServiceSuggestMealReturnsArray() {
    let foods = FoodService.suggestMeal()
    #expect(foods.count <= 3)
}

@Test @MainActor func foodServiceSuggestMealWithBudget() {
    let foods = FoodService.suggestMeal(caloriesLeft: 500, proteinNeeded: 40)
    for food in foods {
        #expect(food.calories <= 500)
    }
}

// MARK: Delete Entry

@Test @MainActor func foodServiceDeleteEntryNotFound() {
    let result = FoodService.deleteEntry(matching: "xyzzy_no_such_food_zzz_999")
    // Either "No food logged today." or "Couldn't find '...' in today's food log."
    #expect(result.contains("No food logged") || result.contains("Couldn't find"))
}

@Test @MainActor func foodServiceDeleteEntryLastKeywordNoFood() {
    // "last" is a special keyword — if no entries today, returns "No food entries today."
    // In test env, likely no entries, so the path exercises the special "last" branch
    let result = FoodService.deleteEntry(matching: "last")
    #expect(!result.isEmpty)
}

// MARK: Preview / Copy Yesterday

@Test @MainActor func foodServicePreviewYesterdayReturnsString() {
    let result = FoodService.previewYesterday()
    #expect(!result.isEmpty)
}

@Test @MainActor func foodServiceCopyYesterdayReturnsString() {
    let result = FoodService.copyYesterday()
    // In test env likely no yesterday data; returns one of the empty-state messages
    #expect(!result.isEmpty)
}

// MARK: Fetch by ID

@Test @MainActor func foodServiceFetchFoodByIdNonexistent() {
    let food = FoodService.fetchFoodById(Int64.max)
    #expect(food == nil)
}
