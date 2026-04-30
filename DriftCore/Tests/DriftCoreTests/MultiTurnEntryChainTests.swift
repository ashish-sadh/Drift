import Foundation
@testable import DriftCore
import Testing

/// Tier 0 — pure logic, no LLM, no simulator.
/// Multi-turn entry-reference chains (#314): 3–4 turn log→log→edit/delete flows
/// simulating what the tool handlers receive after LLM processes each turn.
///
/// Run: `cd DriftCore && swift test --filter MultiTurnEntryChainTests`

// MARK: - Helpers (local to this file to keep tests self-contained)

@MainActor
@discardableResult
private func seedChainEntry(
    mealType: String, foodName: String,
    calories: Double = 200, servings: Double = 1
) -> (mlId: Int64, entry: FoodEntry)? {
    let today = DateFormatters.todayString
    var mealLog = MealLog(date: today, mealType: mealType)
    try? AppDatabase.shared.saveMealLog(&mealLog)
    guard let mlId = mealLog.id else { return nil }
    var entry = FoodEntry(
        mealLogId: mlId, foodName: foodName,
        servingSizeG: 100, servings: servings,
        calories: calories, proteinG: 8,
        loggedAt: ISO8601DateFormatter().string(from: Date()),
        date: today, mealType: mealType
    )
    try? AppDatabase.shared.saveFoodEntry(&entry)
    return (mlId, entry)
}

@MainActor
private func pushChainEntry(_ entry: FoodEntry, mealType: String) {
    guard let id = entry.id else { return }
    ConversationState.shared.pushRecentEntry(.init(
        id: id, name: entry.foodName, mealType: mealType,
        calories: Int(entry.calories), loggedAt: Date()
    ))
}

@MainActor
private func cleanupChain(_ mlIds: Int64?...) {
    for case let id? in mlIds { try? AppDatabase.shared.deleteMealLog(id: id) }
}

// MARK: - 3-turn chains: log → log → edit

@Test @MainActor func chain3Turn_LogLogEdit_EditFirstByName() {
    // Turn 1: log biryani | Turn 2: log raita | Turn 3: edit biryani quantity
    ConversationState.shared.reset()
    guard let biryani = seedChainEntry(mealType: "lunch", foodName: "BiryaniChain314", calories: 350),
          let raita = seedChainEntry(mealType: "lunch", foodName: "RaitaChain314", calories: 80)
    else { Issue.record("Seeding failed"); return }
    defer { cleanupChain(biryani.mlId, raita.mlId) }
    pushChainEntry(biryani.entry, mealType: "lunch")
    pushChainEntry(raita.entry, mealType: "lunch")

    let msg = EditMealHandler.run(params: ToolCallParams(values: [
        "target_food": "biryani", "action": "update_quantity", "new_value": "2"
    ]))
    #expect(msg.contains("Updated"), "3-turn chain: 'biryani' resolved from window to edit entry")
}

@Test @MainActor func chain3Turn_LogLogDelete_DeleteFirstByName() {
    // Turn 1: log idli | Turn 2: log sambar | Turn 3: delete idli by name
    ConversationState.shared.reset()
    guard let idli = seedChainEntry(mealType: "breakfast", foodName: "IdliChain314", calories: 58),
          let sambar = seedChainEntry(mealType: "breakfast", foodName: "SambarChain314", calories: 120)
    else { Issue.record("Seeding failed"); return }
    defer { cleanupChain(idli.mlId, sambar.mlId) }
    pushChainEntry(idli.entry, mealType: "breakfast")
    pushChainEntry(sambar.entry, mealType: "breakfast")

    let msg = DeleteFoodHandler.run(params: ToolCallParams(values: ["name": "idli"]))
    #expect(msg.contains("Removed"))
    #expect(!ConversationState.shared.recentEntries.contains(where: { $0.name == "IdliChain314" }))
    #expect(ConversationState.shared.recentEntries.contains(where: { $0.name == "SambarChain314" }))
}

@Test @MainActor func chain3Turn_LogLogEdit_EditLastByOrdinal() {
    // Turn 1: log eggs | Turn 2: log toast | Turn 3: "edit the last one" → toast
    ConversationState.shared.reset()
    guard let eggs = seedChainEntry(mealType: "breakfast", foodName: "EggsOrdChain314", calories: 150),
          let toast = seedChainEntry(mealType: "breakfast", foodName: "ToastOrdChain314", calories: 90)
    else { Issue.record("Seeding failed"); return }
    defer { cleanupChain(eggs.mlId, toast.mlId) }
    pushChainEntry(eggs.entry, mealType: "breakfast")
    pushChainEntry(toast.entry, mealType: "breakfast")

    let msg = EditMealHandler.run(params: ToolCallParams(values: [
        "target_food": "last", "action": "update_quantity", "new_value": "2"
    ]))
    #expect(msg.contains("Updated"), "Ordinal 'last' in 3-turn chain resolves to most recent window entry")
}

// MARK: - 4-turn chains: log → log → log → edit/delete

@Test @MainActor func chain4Turn_EditFirstEntryByName() {
    // Turn 1: log dal | Turn 2: log rice | Turn 3: log pickle | Turn 4: edit dal
    ConversationState.shared.reset()
    guard let dal = seedChainEntry(mealType: "lunch", foodName: "DalChain4314", calories: 180),
          let rice = seedChainEntry(mealType: "lunch", foodName: "RiceChain4314", calories: 200),
          let pickle = seedChainEntry(mealType: "lunch", foodName: "PickleChain4314", calories: 15)
    else { Issue.record("Seeding failed"); return }
    defer { cleanupChain(dal.mlId, rice.mlId, pickle.mlId) }
    pushChainEntry(dal.entry, mealType: "lunch")
    pushChainEntry(rice.entry, mealType: "lunch")
    pushChainEntry(pickle.entry, mealType: "lunch")

    let msg = EditMealHandler.run(params: ToolCallParams(values: [
        "target_food": "dal", "action": "update_quantity", "new_value": "1.5"
    ]))
    #expect(msg.contains("Updated"), "4-turn chain: 'dal' from turn 1 resolved by name at turn 4")
}

@Test @MainActor func chain4Turn_DeleteMiddleEntryByName() {
    // Turn 1: log chapati | Turn 2: log paneer | Turn 3: log lassi | Turn 4: delete paneer
    ConversationState.shared.reset()
    guard let chapati = seedChainEntry(mealType: "dinner", foodName: "ChapatiChain314", calories: 120),
          let paneer = seedChainEntry(mealType: "dinner", foodName: "PaneerChain314", calories: 260),
          let lassi = seedChainEntry(mealType: "dinner", foodName: "LassiChain314", calories: 180)
    else { Issue.record("Seeding failed"); return }
    defer { cleanupChain(chapati.mlId, paneer.mlId, lassi.mlId) }
    pushChainEntry(chapati.entry, mealType: "dinner")
    pushChainEntry(paneer.entry, mealType: "dinner")
    pushChainEntry(lassi.entry, mealType: "dinner")

    let msg = DeleteFoodHandler.run(params: ToolCallParams(values: ["name": "paneer"]))
    #expect(msg.contains("Removed"), "Middle entry 'paneer' resolved by name in 4-turn chain")
    let window = ConversationState.shared.recentEntries
    #expect(!window.contains(where: { $0.name == "PaneerChain314" }))
    #expect(window.contains(where: { $0.name == "ChapatiChain314" }))
    #expect(window.contains(where: { $0.name == "LassiChain314" }))
}

// MARK: - Edit then delete chain

@Test @MainActor func chain_EditThenDelete_ByName() {
    // Turn 1: log roti | Turn 2: log sabzi | Turn 3: edit roti | Turn 4: delete roti
    ConversationState.shared.reset()
    guard let roti = seedChainEntry(mealType: "dinner", foodName: "RotiEditDel314", calories: 100, servings: 1),
          let sabzi = seedChainEntry(mealType: "dinner", foodName: "SabziEditDel314", calories: 150)
    else { Issue.record("Seeding failed"); return }
    defer { cleanupChain(roti.mlId, sabzi.mlId) }
    pushChainEntry(roti.entry, mealType: "dinner")
    pushChainEntry(sabzi.entry, mealType: "dinner")

    // Turn 3: edit roti quantity — resolves by name
    let editMsg = EditMealHandler.run(params: ToolCallParams(values: [
        "target_food": "roti", "action": "update_quantity", "new_value": "3"
    ]))
    #expect(editMsg.contains("Updated"))

    // Turn 4: delete roti — still in window after quantity edit
    let deleteMsg = DeleteFoodHandler.run(params: ToolCallParams(values: ["name": "roti"]))
    #expect(deleteMsg.contains("Removed"), "Entry should still be resolvable from window after a quantity edit")
}

// MARK: - Duplicate names: name resolver falls to nil, DB search handles

@Test @MainActor func chain3Turn_DuplicateNames_NameResolverNil_DBSearchRuns() {
    // Two "coffee" entries → name resolver returns nil → DB name-search handles it
    ConversationState.shared.reset()
    guard let coffee1 = seedChainEntry(mealType: "breakfast", foodName: "CoffeeDup314", calories: 30),
          let coffee2 = seedChainEntry(mealType: "snack", foodName: "CoffeeDup314", calories: 30)
    else { Issue.record("Seeding failed"); return }
    defer { cleanupChain(coffee1.mlId, coffee2.mlId) }
    pushChainEntry(coffee1.entry, mealType: "breakfast")
    pushChainEntry(coffee2.entry, mealType: "snack")

    let window = ConversationState.shared.recentEntries
    let resolved = FoodEntryRefResolver.resolveByName("coffee", in: window)
    #expect(resolved == nil, "Duplicate names must not resolve — ambiguous → falls to DB name search")
}

// MARK: - Entry_id from context block takes priority over name match

@Test @MainActor func chain_EntryIdPriorityOverNameMatch() {
    // Window has chicken at lunch AND chicken at dinner.
    // LLM correctly passes entry_id for dinner row — must use that, not ambiguous name.
    ConversationState.shared.reset()
    guard let lunch = seedChainEntry(mealType: "lunch", foodName: "ChickenPri314", calories: 220),
          let dinner = seedChainEntry(mealType: "dinner", foodName: "ChickenPri314", calories: 310)
    else { Issue.record("Seeding failed"); return }
    defer { cleanupChain(lunch.mlId, dinner.mlId) }
    pushChainEntry(lunch.entry, mealType: "lunch")
    pushChainEntry(dinner.entry, mealType: "dinner")
    guard let dinnerId = dinner.entry.id else { Issue.record("dinner id missing"); return }

    let msg = DeleteFoodHandler.run(params: ToolCallParams(values: [
        "entry_id": "\(dinnerId)", "name": "chicken"
    ]))
    #expect(msg.contains("Removed"))
    // Lunch entry should survive; dinner entry deleted
    #expect(ConversationState.shared.recentEntries.contains(where: { $0.id == lunch.entry.id }))
    #expect(!ConversationState.shared.recentEntries.contains(where: { $0.id == dinnerId }))
}
