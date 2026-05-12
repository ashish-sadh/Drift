import Foundation
import GRDB

extension AppDatabase {
    /// The shared database for the application (production).
    public static let shared = makeShared()

    /// Location of the live SQLite file. Exposed so backup/restore can swap
    /// it atomically without re-deriving the path in three places.
    public static func databaseFileURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport
            .appendingPathComponent("Drift", isDirectory: true)
            .appendingPathComponent("drift.sqlite")
    }

    private static func makeShared() -> AppDatabase {
        do {
            let databaseURL = try databaseFileURL()
            try FileManager.default.createDirectory(
                at: databaseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            Log.database.info("Opening database at \(databaseURL.path)")
            let dbPool = try DatabasePool(path: databaseURL.path, configuration: makeConfiguration())
            let database = try AppDatabase(dbPool)

            // Seed + refresh foods from bundled JSON on every launch. New
            // rows get inserted; existing DB-sourced rows get calories,
            // macros, and ingredients re-synced from the JSON (so stale
            // values from older installs don't stick around — see
            // "Coffee (with milk) 0 cal" complaint 2026-04-21). User-scanned
            // foods (barcode / recipe / photo_log / custom) are never touched.
            try database.seedFoodsFromJSON()
            Log.database.info("Database ready")

            return database
        } catch {
            Log.database.fault("Database setup failed: \(error.localizedDescription). Attempting recovery...")
            // Recovery: delete corrupt database and try again
            do {
                let fm = FileManager.default
                let dbURL = try databaseFileURL()
                try? fm.removeItem(at: dbURL)
                try? fm.removeItem(at: URL(fileURLWithPath: dbURL.path + "-wal"))
                try? fm.removeItem(at: URL(fileURLWithPath: dbURL.path + "-shm"))
                Log.database.info("Deleted corrupt database, recreating...")
                try fm.createDirectory(
                    at: dbURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let dbPool = try DatabasePool(path: dbURL.path, configuration: makeConfiguration())
                let database = try AppDatabase(dbPool)
                try database.seedFoodsFromJSON()
                Log.database.info("Database recovered successfully")
                return database
            } catch {
                fatalError("Database setup failed and recovery failed: \(error)")
            }
        }
    }

    /// An empty in-memory database for testing and previews.
    public static func empty() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: makeConfiguration())
        return try AppDatabase(dbQueue)
    }

    private static func makeConfiguration() -> Configuration {
        var config = Configuration()
        config.foreignKeysEnabled = true
        return config
    }
}
