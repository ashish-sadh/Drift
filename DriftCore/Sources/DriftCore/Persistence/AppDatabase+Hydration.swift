import Foundation
import GRDB

extension AppDatabase {
    public func saveWaterEntry(_ entry: inout WaterEntry) throws {
        try writer.write { [entry] db in
            var mutable = entry
            try mutable.insert(db)
        }
        entry = try reader.read { db in
            try WaterEntry.order(Column("id").desc).fetchOne(db)
        } ?? entry
    }

    public func fetchWaterEntries(for date: String) throws -> [WaterEntry] {
        try reader.read { db in
            try WaterEntry
                .filter(Column("date") == date)
                .order(Column("logged_at"))
                .fetchAll(db)
        }
    }

    public func fetchDailyWaterMl(for date: String) throws -> Double {
        try reader.read { db in
            let result = try Double.fetchOne(db, sql: "SELECT COALESCE(SUM(amount_ml), 0) FROM water_entry WHERE date = ?", arguments: [date])
            return result ?? 0
        }
    }

    public func deleteWaterEntry(id: Int64) throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM water_entry WHERE id = ?", arguments: [id])
        }
    }
}
