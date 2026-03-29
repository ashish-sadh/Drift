import Foundation
import GRDB

extension AppDatabase {
    /// The shared database for the application (production).
    static let shared = makeShared()

    private static func makeShared() -> AppDatabase {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directoryURL = appSupportURL.appendingPathComponent("Drift", isDirectory: true)
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            let databaseURL = directoryURL.appendingPathComponent("drift.sqlite")
            Log.database.info("Opening database at \(databaseURL.path)")
            let dbPool = try DatabasePool(path: databaseURL.path, configuration: makeConfiguration())
            let database = try AppDatabase(dbPool)

            // Seed foods from bundled JSON on first launch
            try database.seedFoodsFromJSON()
            Log.database.info("Database ready")

            return database
        } catch {
            Log.database.fault("Database setup failed: \(error.localizedDescription)")
            fatalError("Database setup failed: \(error)")
        }
    }

    /// An empty in-memory database for testing and previews.
    static func empty() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: makeConfiguration())
        return try AppDatabase(dbQueue)
    }

    private static func makeConfiguration() -> Configuration {
        var config = Configuration()
        config.foreignKeysEnabled = true
        return config
    }
}
