import Foundation
@testable import DriftCore
import Testing

/// End-to-end tests for multi-turn entry reference resolution (#227).
/// Seeds real DB rows, populates the ConversationState window, routes the
/// resulting delete/edit calls through the registered tools, and asserts
/// the right entry is affected — especially under duplicate-name conflict.

// MARK: - Shared helpers

@MainActor
@discardableResult
private func seedEntry(
    mealType: String, foodName: String,
    calories: Double = 200, servings: Double = 1, servingSizeG: Double = 100
) -> (mlId: Int64, entry: FoodEntry)? {
    let today = DateFormatters.todayString
    var mealLog = MealLog(date: today, mealType: mealType)
    try? AppDatabase.shared.saveMealLog(&mealLog)
    guard let mlId = mealLog.id else { return nil }
    var entry = FoodEntry(
        mealLogId: mlId, foodName: foodName,
        servingSizeG: servingSizeG, servings: servings,
        calories: calories, proteinG: 10,
        loggedAt: ISO8601DateFormatter().string(from: Date()),
        date: today, mealType: mealType
    )
    try? AppDatabase.shared.saveFoodEntry(&entry)
    return (mlId, entry)
}

@MainActor
private func cleanup(_ mlIds: Int64?...) {
    for case let id? in mlIds { try? AppDatabase.shared.deleteMealLog(id: id) }
}

@MainActor
private func pushToWindow(_ entry: FoodEntry, mealType: String) {
    guard let id = entry.id else { return }
    ConversationState.shared.pushRecentEntry(.init(
        id: id, name: entry.foodName, mealType: mealType,
        calories: Int(entry.calories), loggedAt: Date()
    ))
}

// MARK: - entry_id path picks the right row under duplicate names

@Test @MainActor func deleteByEntryIdPicksCorrectRowAmongDuplicates() {
    let state = ConversationState.shared
    state.reset()
    guard let lunch = seedEntry(mealType: "lunch", foodName: "DupRice227", calories: 180),
          let dinner = seedEntry(mealType: "dinner", foodName: "DupRice227", calories: 240)
    else {
        Issue.record("Seeding failed"); return
    }
    defer { cleanup(lunch.mlId, dinner.mlId) }

    // Window lists both; AI returns entry_id of the dinner row.
    pushToWindow(lunch.entry, mealType: "lunch")
    pushToWindow(dinner.entry, mealType: "dinner")
    guard let dinnerId = dinner.entry.id else { Issue.record("dinner id missing"); return }

    let msg = DeleteFoodHandler.run(params: ToolCallParams(values: [
        "entry_id": "\(dinnerId)", "name": "rice"
    ]))
    #expect(msg.contains("Removed"))
    #expect(state.recentEntries.contains(where: { $0.id == lunch.entry.id }))
    #expect(!state.recentEntries.contains(where: { $0.id == dinnerId }))
}

// MARK: - Ordinal "last" routes to newest window row

@Test @MainActor func deleteByOrdinalLastResolvesNewestWindowRow() {
    let state = ConversationState.shared
    state.reset()
    guard let first = seedEntry(mealType: "breakfast", foodName: "OrdFirst227", calories: 100),
          let last = seedEntry(mealType: "snack", foodName: "OrdLast227", calories: 50)
    else { Issue.record("Seeding failed"); return }
    defer { cleanup(first.mlId, last.mlId) }

    pushToWindow(first.entry, mealType: "breakfast")
    pushToWindow(last.entry, mealType: "snack")
    guard let lastId = last.entry.id else { Issue.record("last id missing"); return }

    let msg = DeleteFoodHandler.run(params: ToolCallParams(values: ["name": "last"]))
    #expect(msg.contains("Removed"))
    // The newest window entry (snack OrdLast227) should now be gone
    #expect(!state.recentEntries.contains(where: { $0.id == lastId }))
}

@Test @MainActor func deleteByOrdinalFirstResolvesOldestWindowRow() {
    let state = ConversationState.shared
    state.reset()
    guard let first = seedEntry(mealType: "breakfast", foodName: "OrdAlpha227", calories: 100),
          let second = seedEntry(mealType: "lunch", foodName: "OrdBeta227", calories: 200)
    else { Issue.record("Seeding failed"); return }
    defer { cleanup(first.mlId, second.mlId) }

    pushToWindow(first.entry, mealType: "breakfast")
    pushToWindow(second.entry, mealType: "lunch")

    let msg = DeleteFoodHandler.run(params: ToolCallParams(values: ["name": "first"]))
    #expect(msg.contains("Removed"))
    #expect(!state.recentEntries.contains(where: { $0.id == first.entry.id }))
    #expect(state.recentEntries.contains(where: { $0.id == second.entry.id }))
}

// MARK: - Stale entry_id degrades to name-match

@Test @MainActor func staleEntryIdFallsBackToNameMatch() {
    let state = ConversationState.shared
    state.reset()
    guard let seeded = seedEntry(mealType: "lunch", foodName: "FallbackRice227", calories: 160) else {
        Issue.record("Seeding failed"); return
    }
    defer { cleanup(seeded.mlId) }
    pushToWindow(seeded.entry, mealType: "lunch")

    // Inject a stale id that isn't in the window — resolver should reject it
    // and the name-match path should still delete the real row.
    let msg = DeleteFoodHandler.run(params: ToolCallParams(values: [
        "entry_id": "99999999",
        "name": "FallbackRice227"
    ]))
    #expect(msg.contains("Removed"))
}

// MARK: - edit_meal by entry_id skips meal-period filter

@Test @MainActor func editByEntryIdSucceedsWithoutMealPeriod() {
    let state = ConversationState.shared
    state.reset()
    guard let seeded = seedEntry(mealType: "dinner", foodName: "EditById227", calories: 300, servings: 1) else {
        Issue.record("Seeding failed"); return
    }
    defer { cleanup(seeded.mlId) }
    pushToWindow(seeded.entry, mealType: "dinner")
    guard let entryId = seeded.entry.id else { Issue.record("entry id missing"); return }

    let msg = EditMealHandler.run(params: ToolCallParams(values: [
        "entry_id": "\(entryId)",
        "action": "update_quantity",
        "new_value": "3"
    ]))
    #expect(msg.contains("Updated"))
    #expect(msg.contains("3 servings"))
}

// MARK: - Empty args prompts for clarification (no crash)

@Test @MainActor func editWithNoTargetAndNoEntryIdAsksForClarification() {
    ConversationState.shared.reset()
    let msg = EditMealHandler.run(params: ToolCallParams(values: ["action": "remove"]))
    #expect(msg.lowercased().contains("which"))
}

// MARK: - Name-based window resolution (#314)

@Test @MainActor func nameResolves_UniqueWindowMatch_ByNameKey() {
    let state = ConversationState.shared
    state.reset()
    guard let seeded = seedEntry(mealType: "lunch", foodName: "Chicken Tikka314", calories: 280)
    else { Issue.record("Seeding failed"); return }
    defer { cleanup(seeded.mlId) }
    pushToWindow(seeded.entry, mealType: "lunch")

    // LLM passes name: "chicken" (no entry_id) — window has "Chicken Tikka314"
    let msg = DeleteFoodHandler.run(params: ToolCallParams(values: ["name": "chicken"]))
    #expect(msg.contains("Removed"), "Name-based window match should resolve and delete")
}

@Test @MainActor func nameResolves_UniqueWindowMatch_ByTargetFoodKey() {
    let state = ConversationState.shared
    state.reset()
    guard let seeded = seedEntry(mealType: "dinner", foodName: "Pasta Bolognese314", calories: 420)
    else { Issue.record("Seeding failed"); return }
    defer { cleanup(seeded.mlId) }
    pushToWindow(seeded.entry, mealType: "dinner")

    let msg = EditMealHandler.run(params: ToolCallParams(values: [
        "target_food": "pasta", "action": "update_quantity", "new_value": "2"
    ]))
    #expect(msg.contains("Updated"), "Partial name 'pasta' should resolve 'Pasta Bolognese314' from window")
}

@Test @MainActor func nameResolves_CaseInsensitive() {
    let state = ConversationState.shared
    state.reset()
    guard let seeded = seedEntry(mealType: "breakfast", foodName: "Rice Pilaf314", calories: 210)
    else { Issue.record("Seeding failed"); return }
    defer { cleanup(seeded.mlId) }
    pushToWindow(seeded.entry, mealType: "breakfast")

    let msg = DeleteFoodHandler.run(params: ToolCallParams(values: ["name": "RICE"]))
    #expect(msg.contains("Removed"), "Case-insensitive match should resolve 'RICE' → 'Rice Pilaf314'")
}

@Test @MainActor func nameResolves_AmbiguousReturnsNilFallsToNameSearch() {
    let state = ConversationState.shared
    state.reset()
    guard let a = seedEntry(mealType: "lunch", foodName: "Chicken Curry314", calories: 300),
          let b = seedEntry(mealType: "dinner", foodName: "Chicken Rice314", calories: 350)
    else { Issue.record("Seeding failed"); return }
    defer { cleanup(a.mlId, b.mlId) }
    pushToWindow(a.entry, mealType: "lunch")
    pushToWindow(b.entry, mealType: "dinner")

    // Two "chicken" entries → name resolver returns nil → DB name search runs instead
    let window = state.recentEntries
    let resolved = FoodEntryRefResolver.resolveByName("chicken", in: window)
    #expect(resolved == nil, "Ambiguous name match must return nil, not pick one arbitrarily")
}

@Test @MainActor func nameResolves_UnrelatedFood_ReturnsNil() {
    let state = ConversationState.shared
    state.reset()
    guard let seeded = seedEntry(mealType: "lunch", foodName: "Dal Makhani314", calories: 190)
    else { Issue.record("Seeding failed"); return }
    defer { cleanup(seeded.mlId) }
    pushToWindow(seeded.entry, mealType: "lunch")

    let window = state.recentEntries
    let resolved = FoodEntryRefResolver.resolveByName("chicken", in: window)
    #expect(resolved == nil, "Non-matching food name should not resolve")
}

@Test @MainActor func nameResolves_EmptyPhrase_ReturnsNil() {
    ConversationState.shared.reset()
    let window = ConversationState.shared.recentEntries
    #expect(FoodEntryRefResolver.resolveByName("", in: window) == nil)
}

@Test @MainActor func nameResolves_3TurnChain_LogLogEdit() {
    // Simulates: log chicken → log rice → edit chicken by name reference
    let state = ConversationState.shared
    state.reset()
    guard let chicken = seedEntry(mealType: "lunch", foodName: "ChickenRef314", calories: 250, servings: 1),
          let rice = seedEntry(mealType: "lunch", foodName: "RiceRef314", calories: 180, servings: 1)
    else { Issue.record("Seeding failed"); return }
    defer { cleanup(chicken.mlId, rice.mlId) }
    pushToWindow(chicken.entry, mealType: "lunch")
    pushToWindow(rice.entry, mealType: "lunch")

    // Turn 3: edit "ChickenRef314" by name, no entry_id provided
    let msg = EditMealHandler.run(params: ToolCallParams(values: [
        "target_food": "ChickenRef",
        "action": "update_quantity",
        "new_value": "2"
    ]))
    #expect(msg.contains("Updated"), "Name-based window lookup should edit chicken entry in 3-turn chain")
}

@Test @MainActor func nameResolves_3TurnChain_LogLogDelete() {
    let state = ConversationState.shared
    state.reset()
    guard let first = seedEntry(mealType: "dinner", foodName: "SaagDel314", calories: 200),
          let second = seedEntry(mealType: "dinner", foodName: "NaanDel314", calories: 280)
    else { Issue.record("Seeding failed"); return }
    defer { cleanup(first.mlId, second.mlId) }
    pushToWindow(first.entry, mealType: "dinner")
    pushToWindow(second.entry, mealType: "dinner")

    // Turn 3: delete saag by name reference
    let msg = DeleteFoodHandler.run(params: ToolCallParams(values: ["name": "SaagDel"]))
    #expect(msg.contains("Removed"))
    #expect(!state.recentEntries.contains(where: { $0.name == "SaagDel314" }))
    #expect(state.recentEntries.contains(where: { $0.name == "NaanDel314" }))
}

@Test @MainActor func nameResolves_AfterDelete_EntryNotResolvableFromWindow() {
    let state = ConversationState.shared
    state.reset()
    guard let seeded = seedEntry(mealType: "snack", foodName: "DeletedSnack314", calories: 120)
    else { Issue.record("Seeding failed"); return }
    defer { cleanup(seeded.mlId) }
    pushToWindow(seeded.entry, mealType: "snack")

    _ = DeleteFoodHandler.run(params: ToolCallParams(values: ["name": "DeletedSnack"]))

    // After delete, window should not hold the evicted entry
    let window = state.recentEntries
    #expect(!window.contains(where: { $0.name == "DeletedSnack314" }),
        "Deleted entry must be evicted from window")
}
