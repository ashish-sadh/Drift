import Foundation
@testable import DriftCore
import Testing
@testable import Drift

// MARK: - Shared meal-log path regression tests
//
// Root cause of the "logged breakfast via AI chat, only saw one item" bug
// (user report 2026-04-24): QuickAddView's default `expandOnLog=false` wrote
// a single aggregated FoodEntry named after the recipe, so multi-item logs
// from AI chat collapsed into one diary row. ComboLogSheet always expanded
// (one FoodEntry per item) — divergent behaviour across entry points.
//
// Fix: both paths now call FoodLogViewModel.logRecipeItems. AI-chat-opened
// multi-item recipes default to expanded so the diary rows match the
// conversation ("log avocado toast and coffee" → two rows, not one
// "Breakfast 305 cal" blob).

@Test func logRecipeItems_writesOneEntryPerItem() async throws {
    let db = try AppDatabase.empty()
    let vm = await FoodLogViewModel(database: db)

    let items: [QuickAddView.RecipeItem] = [
        .init(name: "Avocado Toast", portionText: "1 slice",
              calories: 300, proteinG: 7, carbsG: 30, fatG: 18, fiberG: 5,
              servingSizeG: 120),
        .init(name: "Coffee (black)", portionText: "240 ml",
              calories: 5, proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0,
              servingSizeG: 240)
    ]
    await vm.logRecipeItems(items, mealType: .breakfast)

    let rows = await vm.todayEntries.sorted { $0.foodName < $1.foodName }
    #expect(rows.count == 2, "Both items must land as distinct diary rows (user report: 'only avocado toast was stored').")
    #expect(rows.map(\.foodName).sorted() == ["Avocado Toast", "Coffee (black)"])
    #expect(rows.map(\.calories).sorted() == [5, 300])
}

@Test func logRecipeItems_appliesRecipeServingsToEveryItem() async throws {
    let db = try AppDatabase.empty()
    let vm = await FoodLogViewModel(database: db)

    let items: [QuickAddView.RecipeItem] = [
        .init(name: "Egg", portionText: "1 egg",
              calories: 78, proteinG: 6, carbsG: 1, fatG: 5, fiberG: 0,
              servingSizeG: 50),
        .init(name: "Toast", portionText: "1 slice",
              calories: 80, proteinG: 3, carbsG: 14, fatG: 1, fiberG: 2,
              servingSizeG: 30)
    ]
    // Scale whole meal by 2.
    await vm.logRecipeItems(items, recipeServings: 2, mealType: .breakfast)

    let rows = await vm.todayEntries.sorted { $0.foodName < $1.foodName }
    #expect(rows.count == 2)
    // Egg × 2 = 156 cal, Toast × 2 = 160 cal.
    let egg = rows.first { $0.foodName == "Egg" }
    let toast = rows.first { $0.foodName == "Toast" }
    #expect(egg?.calories == 156)
    #expect(toast?.calories == 160)
}

@Test func logRecipeItems_honoursPerItemServings() async throws {
    let db = try AppDatabase.empty()
    let vm = await FoodLogViewModel(database: db)

    let egg = QuickAddView.RecipeItem(name: "Egg", portionText: "1 egg",
                                       calories: 78, proteinG: 6, carbsG: 1, fatG: 5, fiberG: 0,
                                       servingSizeG: 50)
    let toast = QuickAddView.RecipeItem(name: "Toast", portionText: "1 slice",
                                         calories: 80, proteinG: 3, carbsG: 14, fatG: 1, fiberG: 2,
                                         servingSizeG: 30)
    // Egg stepper = 3, Toast stepper = 1 (like a ComboLogSheet user would tap).
    await vm.logRecipeItems([egg, toast],
                            perItemServings: [egg.id: 3, toast.id: 1],
                            mealType: .breakfast)

    let rows = await vm.todayEntries
    let eggRow = rows.first { $0.foodName == "Egg" }
    let toastRow = rows.first { $0.foodName == "Toast" }
    #expect(eggRow?.calories == 234, "Egg × 3 = 234 cal")
    #expect(toastRow?.calories == 80, "Toast × 1 = 80 cal")
}

@Test func logRecipeItems_skipsZeroServings() async throws {
    let db = try AppDatabase.empty()
    let vm = await FoodLogViewModel(database: db)

    let egg = QuickAddView.RecipeItem(name: "Egg", portionText: "",
                                       calories: 78, proteinG: 6, carbsG: 1, fatG: 5, fiberG: 0,
                                       servingSizeG: 50)
    let toast = QuickAddView.RecipeItem(name: "Toast", portionText: "",
                                         calories: 80, proteinG: 3, carbsG: 14, fatG: 1, fiberG: 2,
                                         servingSizeG: 30)
    // Toast with 0 servings (unchecked in ComboLogSheet) must be skipped
    // rather than written as a 0-cal row.
    await vm.logRecipeItems([egg, toast],
                            perItemServings: [egg.id: 1, toast.id: 0],
                            mealType: .breakfast)

    let rows = await vm.todayEntries
    #expect(rows.count == 1)
    #expect(rows.first?.foodName == "Egg")
}
