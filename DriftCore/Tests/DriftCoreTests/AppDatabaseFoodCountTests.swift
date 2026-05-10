import Foundation
import GRDB
import Testing
@testable import DriftCore

// Tier-0: AppDatabase.foodCount() helper used by Settings to show
// "Refreshed N foods" after manual refresh of the bundled food JSON.

private func makeTestDB() throws -> AppDatabase {
    let queue = try DatabaseQueue()
    var migrator = DatabaseMigrator()
    Migrations.registerAll(&migrator)
    try migrator.migrate(queue)
    return try AppDatabase(queue)
}

struct AppDatabaseFoodCountTests {

    @Test func foodCountIsZeroOnEmptyDatabase() throws {
        let db = try makeTestDB()
        #expect(try db.foodCount() == 0)
    }

    @Test func foodCountReflectsInsertedRows() throws {
        let db = try makeTestDB()
        try db.writer.write { conn in
            try Food(name: "Apple", category: "Fruit", servingSize: 100,
                     servingUnit: "g", calories: 52).insert(conn)
            try Food(name: "Banana", category: "Fruit", servingSize: 100,
                     servingUnit: "g", calories: 89).insert(conn)
            try Food(name: "Carrot", category: "Vegetable", servingSize: 100,
                     servingUnit: "g", calories: 41).insert(conn)
        }
        #expect(try db.foodCount() == 3)
    }
}
