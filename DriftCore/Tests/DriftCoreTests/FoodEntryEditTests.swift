import Foundation
import Testing
import GRDB
@testable import DriftCore

// MARK: - FoodEntryEditTests (Tier 0)
// Tests AppDatabase update methods for food entry editing.
// Uses in-memory DB — no shared state.

private func makeTestDB() throws -> AppDatabase {
    let queue = try DatabaseQueue()
    var migrator = DatabaseMigrator()
    Migrations.registerAll(&migrator)
    try migrator.migrate(queue)
    return try AppDatabase(queue)
}

private func insertEntry(db: AppDatabase, food: String = "Rice", servings: Double = 1.0, calories: Double = 200) throws -> Int64 {
    var log = MealLog(date: "2026-05-01", mealType: "lunch")
    try db.saveMealLog(&log)
    let logId = log.id!
    var entry = FoodEntry(
        mealLogId: logId, foodName: food, servingSizeG: 100, servings: servings,
        calories: calories, proteinG: 5, carbsG: 40, fatG: 2, fiberG: 1,
        createdAt: "2026-05-01T12:00:00Z", loggedAt: "2026-05-01T12:00:00Z"
    )
    try db.saveFoodEntry(&entry)
    return entry.id!
}

// MARK: - updateFoodEntryServings

@Test func updateServings_persistsNewValue() throws {
    let db = try makeTestDB()
    let id = try insertEntry(db: db, servings: 1.0)
    try db.updateFoodEntryServings(id: id, servings: 2.5)
    let fetched = try db.reader.read { try FoodEntry.fetchOne($0, id: id) }
    #expect(fetched?.servings == 2.5)
}

@Test func updateServings_doesNotAffectOtherFields() throws {
    let db = try makeTestDB()
    let id = try insertEntry(db: db, food: "Dal", servings: 1.0, calories: 150)
    try db.updateFoodEntryServings(id: id, servings: 3.0)
    let fetched = try db.reader.read { try FoodEntry.fetchOne($0, id: id) }
    #expect(fetched?.foodName == "Dal")
    #expect(fetched?.calories == 150)  // calories unchanged by servings update
}

// MARK: - updateFoodEntryMacros

@Test func updateMacros_persistsAllFields() throws {
    let db = try makeTestDB()
    let id = try insertEntry(db: db, calories: 200)
    try db.updateFoodEntryMacros(id: id, calories: 320, proteinG: 12, carbsG: 55, fatG: 8, fiberG: 3)
    let fetched = try db.reader.read { try FoodEntry.fetchOne($0, id: id) }
    #expect(fetched?.calories == 320)
    #expect(fetched?.proteinG == 12)
    #expect(fetched?.carbsG == 55)
    #expect(fetched?.fatG == 8)
    #expect(fetched?.fiberG == 3)
}

// MARK: - updateFoodEntryName

@Test func updateName_persistsNewName() throws {
    let db = try makeTestDB()
    let id = try insertEntry(db: db, food: "Oats")
    try db.updateFoodEntryName(id: id, name: "Steel-cut oats")
    let fetched = try db.reader.read { try FoodEntry.fetchOne($0, id: id) }
    #expect(fetched?.foodName == "Steel-cut oats")
}
