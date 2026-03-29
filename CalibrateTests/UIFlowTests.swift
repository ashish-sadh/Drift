import Foundation
import Testing
@testable import Calibrate

// Test the core data flows end-to-end with an in-memory database

@Test func weightEntryRoundTrip() async throws {
    let db = try AppDatabase.empty()

    // Add weight
    var entry = WeightEntry(date: "2026-03-28", weightKg: 54.5)
    try db.saveWeightEntry(&entry)
    #expect(entry.id != nil)

    // Fetch
    let entries = try db.fetchWeightEntries()
    #expect(entries.count == 1)
    #expect(entries[0].weightKg == 54.5)

    // Delete
    try db.deleteWeightEntry(id: entry.id!)
    let after = try db.fetchWeightEntries()
    #expect(after.isEmpty)
}

@Test func foodLoggingFlow() async throws {
    let db = try AppDatabase.empty()

    // Create meal log
    var meal = MealLog(date: "2026-03-28", mealType: "lunch")
    try db.saveMealLog(&meal)
    #expect(meal.id != nil)

    // Add food entry
    var entry = FoodEntry(
        mealLogId: meal.id!,
        foodName: "Moong Dal",
        servingSizeG: 200,
        servings: 2,
        calories: 210,
        proteinG: 14,
        carbsG: 36,
        fatG: 1,
        fiberG: 8
    )
    try db.saveFoodEntry(&entry)

    // Check daily nutrition
    let nutrition = try db.fetchDailyNutrition(for: "2026-03-28")
    #expect(nutrition.calories == 420) // 210 * 2 servings
    #expect(nutrition.proteinG == 28)  // 14 * 2
}

@Test func supplementFlow() async throws {
    let db = try AppDatabase.empty()

    // Add supplement
    var supp = Supplement(name: "Creatine", dosage: "5", unit: "g")
    try db.saveSupplement(&supp)
    #expect(supp.id != nil)

    // Toggle taken
    try db.toggleSupplementTaken(supplementId: supp.id!, date: "2026-03-28")
    let logs = try db.fetchSupplementLogs(for: "2026-03-28")
    #expect(logs.count == 1)
    #expect(logs[0].taken == true)

    // Toggle again (untaken)
    try db.toggleSupplementTaken(supplementId: supp.id!, date: "2026-03-28")
    let logs2 = try db.fetchSupplementLogs(for: "2026-03-28")
    #expect(logs2[0].taken == false)
}

@Test func dexaScanFlow() async throws {
    let db = try AppDatabase.empty()

    var scan1 = DEXAScan(
        scanDate: "2025-11-16",
        location: "BodySpec - SF",
        fatMassKg: 14.7,
        leanMassKg: 41.6,
        bodyFatPct: 25.0,
        visceralFatKg: 0.4
    )
    try db.saveDEXAScan(&scan1)

    var scan2 = DEXAScan(
        scanDate: "2026-03-06",
        location: "BodySpec - SF",
        fatMassKg: 9.0,
        leanMassKg: 43.3,
        bodyFatPct: 16.4,
        visceralFatKg: 0.3
    )
    try db.saveDEXAScan(&scan2)

    let scans = try db.fetchDEXAScans()
    #expect(scans.count == 2)
    #expect(scans[0].scanDate == "2026-03-06") // most recent first
    #expect(scans[0].bodyFatPct == 16.4)
}

@Test func glucoseImport() async throws {
    let db = try AppDatabase.empty()

    let readings = [
        GlucoseReading(timestamp: "2026-03-15T08:00:00Z", glucoseMgdl: 95, importBatch: "batch1"),
        GlucoseReading(timestamp: "2026-03-15T08:05:00Z", glucoseMgdl: 102, importBatch: "batch1"),
        GlucoseReading(timestamp: "2026-03-15T08:10:00Z", glucoseMgdl: 118, importBatch: "batch1"),
    ]
    try db.saveGlucoseReadings(readings)

    let fetched = try db.fetchGlucoseReadings(from: "2026-03-15T00:00:00Z", to: "2026-03-15T23:59:59Z")
    #expect(fetched.count == 3)
    #expect(fetched[0].glucoseMgdl == 95)
    #expect(fetched[2].glucoseMgdl == 118)
}

@Test func foodSearchWorks() async throws {
    let db = try AppDatabase.empty()

    // Insert some test foods manually
    try await db.writer.write { dbConn in
        var food1 = Food(name: "Moong Dal", category: "Indian", servingSize: 200, servingUnit: "g", calories: 210, proteinG: 14, carbsG: 36, fatG: 1, fiberG: 8)
        var food2 = Food(name: "Chicken Breast", category: "Protein", servingSize: 150, servingUnit: "g", calories: 248, proteinG: 46, carbsG: 0, fatG: 5.4, fiberG: 0)
        try food1.insert(dbConn)
        try food2.insert(dbConn)
    }

    let results = try db.searchFoods(query: "dal")
    #expect(results.count == 1)
    #expect(results[0].name == "Moong Dal")

    let results2 = try db.searchFoods(query: "chicken")
    #expect(results2.count == 1)
    #expect(results2[0].proteinG == 46)

    let empty = try db.searchFoods(query: "pizza")
    #expect(empty.isEmpty)
}
