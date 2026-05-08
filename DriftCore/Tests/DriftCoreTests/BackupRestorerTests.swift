import XCTest
import GRDB
import ZIPFoundation
import CryptoKit
@testable import DriftCore

final class BackupRestorerTests: XCTestCase {
    private var workDir: URL!
    private var defaultsSuite: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupRestorerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defaultsSuite = "BackupRestorerTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuite)!
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: workDir)
        UserDefaults().removePersistentDomain(forName: defaultsSuite)
        super.tearDown()
    }

    // MARK: - Roundtrip

    func testRoundtripRestoresAllRowsAndAllowlistedDefaults() throws {
        let backupURL = try makeBackup(
            seedRows: 100,
            schemaVersion: Migrations.currentVersion,
            withDefaults: [
                "drift.weightGoal": 150,
                "drift.dailyCalorieTarget": 2200,
                "drift.backupEnabled": true,
                "drift.notAllowlisted": "leaked", // must NOT round-trip
            ]
        )

        let dest = workDir.appendingPathComponent("restored-target.sqlite")
        // Pre-create a stub destination so atomic replace exercises replaceItem.
        try Data("stale".utf8).write(to: dest)

        let manifest = try BackupRestorer().restore(
            from: backupURL,
            toDatabasePath: dest,
            userDefaults: defaults,
            currentSchemaVersion: Migrations.currentVersion,
            scratchDir: workDir.appendingPathComponent("scratch", isDirectory: true)
        )

        XCTAssertEqual(manifest.schemaVersion, Migrations.currentVersion)

        let restored = try DatabaseQueue(path: dest.path)
        let count = try restored.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM seed_row")
        }
        XCTAssertEqual(count, 100)

        XCTAssertEqual(defaults.integer(forKey: "drift.weightGoal"), 150)
        XCTAssertEqual(defaults.integer(forKey: "drift.dailyCalorieTarget"), 2200)
        XCTAssertTrue(defaults.bool(forKey: "drift.backupEnabled"))
        XCTAssertNil(defaults.object(forKey: "drift.notAllowlisted"))
    }

    // MARK: - Corruption

    func testCorruptManifestChecksumReturnsCorrupted() throws {
        let backupURL = try makeBackup(seedRows: 5, schemaVersion: Migrations.currentVersion)
        try corruptDatabaseChecksum(in: backupURL)

        let dest = workDir.appendingPathComponent("restored.sqlite")
        let originalBytes = Data("original-db".utf8)
        try originalBytes.write(to: dest)

        XCTAssertThrowsError(try BackupRestorer().restore(
            from: backupURL,
            toDatabasePath: dest,
            userDefaults: defaults
        )) { error in
            guard case .corrupted = error as? BackupError else {
                return XCTFail("expected .corrupted, got \(error)")
            }
        }

        // Original DB untouched.
        XCTAssertEqual(try Data(contentsOf: dest), originalBytes)
    }

    func testMissingManifestReturnsInvalidFormat() throws {
        let backupURL = workDir.appendingPathComponent("no-manifest.driftbackup")
        guard let archive = Archive(url: backupURL, accessMode: .create) else {
            return XCTFail("could not create archive")
        }
        let dummy = workDir.appendingPathComponent("dummy.sqlite")
        try Data("x".utf8).write(to: dummy)
        try archive.addEntry(with: "drift.sqlite", fileURL: dummy, compressionMethod: .deflate)

        let dest = workDir.appendingPathComponent("dest.sqlite")
        let originalBytes = Data("original".utf8)
        try originalBytes.write(to: dest)

        XCTAssertThrowsError(try BackupRestorer().restore(
            from: backupURL,
            toDatabasePath: dest,
            userDefaults: defaults
        )) { error in
            guard case .invalidFormat = error as? BackupError else {
                return XCTFail("expected .invalidFormat, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: dest), originalBytes)
    }

    // MARK: - Schema version

    func testSchemaVersionTooNewReturnsUnsupportedAndLeavesDestAlone() throws {
        let backupURL = try makeBackup(
            seedRows: 1,
            schemaVersion: Migrations.currentVersion + 5
        )

        let dest = workDir.appendingPathComponent("dest.sqlite")
        let originalBytes = Data("untouched".utf8)
        try originalBytes.write(to: dest)

        XCTAssertThrowsError(try BackupRestorer().restore(
            from: backupURL,
            toDatabasePath: dest,
            userDefaults: defaults
        )) { error in
            guard case .unsupportedSchemaVersion = error as? BackupError else {
                return XCTFail("expected .unsupportedSchemaVersion, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: dest), originalBytes)
    }

    func testOlderSchemaVersionRunsForwardMigrations() throws {
        // The packager stamps whatever schemaVersion the caller passes. We package
        // a DB at version 1, then restore claiming current = whatever Migrations
        // says — restorer should run forward migrations on the extracted DB before
        // swapping.
        let backupURL = try makeBackup(
            seedRows: 3,
            schemaVersion: 1,
            includeRealMigrations: true
        )

        let dest = workDir.appendingPathComponent("dest.sqlite")
        XCTAssertNoThrow(try BackupRestorer().restore(
            from: backupURL,
            toDatabasePath: dest,
            userDefaults: defaults
        ))

        // After restore the DB must have all forward migrations applied — tables
        // from later migrations should exist.
        let queue = try DatabaseQueue(path: dest.path)
        let hasMedicationTable = try queue.read { db in
            try db.tableExists("daily_medication")
        }
        XCTAssertTrue(hasMedicationTable, "v37 migration should have run")

        let appliedCount = try queue.read { db -> Int in
            // grdb_migrations is the internal migration ledger.
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM grdb_migrations") ?? 0
            return count
        }
        XCTAssertEqual(appliedCount, Migrations.currentVersion)
    }

    // MARK: - Crash defense: hand-crafted preferences

    /// Regression test for the crash audit (#687). JSON `null` deserializes
    /// to `NSNull`, which is NOT property-list compatible; calling
    /// `UserDefaults.set(NSNull(), forKey:)` raises an uncatchable Obj-C
    /// exception. The Restorer must filter such values rather than blindly
    /// forwarding them.
    func testApplyPreferencesIgnoresNullAndComplexValuesAndDoesNotCrash() throws {
        let backupURL = try makeBackupWithRawPreferencesJSON(
            seedRows: 1,
            schemaVersion: Migrations.currentVersion,
            rawPrefsJSON: """
            {
              "drift.weightGoal": null,
              "drift.dailyCalorieTarget": 2200,
              "drift.backupEnabled": true,
              "drift.preferredUnits": "kg",
              "drift.tdeeConfig": {"nested": "object"},
              "drift.foodSortOrder": ["array", "value"],
              "drift.notAllowlisted": "leaked"
            }
            """
        )

        let dest = workDir.appendingPathComponent("dest.sqlite")
        // Restore must complete without throwing or raising an Obj-C exception.
        XCTAssertNoThrow(try BackupRestorer().restore(
            from: backupURL,
            toDatabasePath: dest,
            userDefaults: defaults
        ))

        // Primitive values restored.
        XCTAssertEqual(defaults.integer(forKey: "drift.dailyCalorieTarget"), 2200)
        XCTAssertTrue(defaults.bool(forKey: "drift.backupEnabled"))
        XCTAssertEqual(defaults.string(forKey: "drift.preferredUnits"), "kg")
        // Null + complex values dropped silently — Restorer must not crash on them.
        XCTAssertNil(defaults.object(forKey: "drift.weightGoal"))
        XCTAssertNil(defaults.object(forKey: "drift.tdeeConfig"))
        XCTAssertNil(defaults.object(forKey: "drift.foodSortOrder"))
        // Allowlist still enforced.
        XCTAssertNil(defaults.object(forKey: "drift.notAllowlisted"))
    }

    // MARK: - Atomic swap failure

    func testAtomicReplaceFailureLeavesOriginalDBIntact() throws {
        let backupURL = try makeBackup(seedRows: 2, schemaVersion: Migrations.currentVersion)

        // Force replaceItem to fail by making the destination's parent directory
        // read-only. POSIX semantics: removing/replacing a file requires write
        // permission on the parent, so replaceItemAt throws and our atomic swap
        // never overwrites the original.
        let parent = workDir.appendingPathComponent("locked", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let dest = parent.appendingPathComponent("dest.sqlite")
        let originalBytes = Data("untouched-original".utf8)
        try originalBytes.write(to: dest)

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: parent.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: parent.path
            )
        }

        XCTAssertThrowsError(try BackupRestorer().restore(
            from: backupURL,
            toDatabasePath: dest,
            userDefaults: defaults
        ))

        XCTAssertEqual(try Data(contentsOf: dest), originalBytes,
                       "original DB must be untouched after atomic swap failure")
    }

    // MARK: - Helpers

    private func makeBackup(
        seedRows: Int,
        schemaVersion: Int,
        withDefaults extraDefaults: [String: Any] = [:],
        includeRealMigrations: Bool = false
    ) throws -> URL {
        let dbURL = workDir.appendingPathComponent("source-\(UUID().uuidString).sqlite")
        let dbQueue = try DatabaseQueue(path: dbURL.path)
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE seed_row (id INTEGER PRIMARY KEY, value TEXT)")
            for i in 0..<seedRows {
                try db.execute(sql: "INSERT INTO seed_row(value) VALUES(?)", arguments: ["row-\(i)"])
            }
        }
        if includeRealMigrations {
            // Stamp a partial migration ledger so forward-migration test exercises
            // the migrator. Just record v1_weight as applied; later migrations will
            // run because grdb_migrations doesn't include them.
            try dbQueue.write { db in
                try db.execute(sql: "CREATE TABLE IF NOT EXISTS grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
                try db.execute(sql: "INSERT INTO grdb_migrations VALUES('v1_weight')")
                // The v1_weight migration creates weight_entry — pre-create so the
                // forward-migration replay doesn't try to recreate an existing table.
                try db.execute(sql: """
                    CREATE TABLE weight_entry (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        date TEXT NOT NULL UNIQUE,
                        weight_kg REAL NOT NULL,
                        source TEXT NOT NULL DEFAULT 'manual',
                        created_at TEXT NOT NULL DEFAULT (datetime('now')),
                        synced_from_hk INTEGER NOT NULL DEFAULT 0
                    )
                    """)
                try db.execute(sql: "CREATE INDEX idx_weight_entry_date ON weight_entry(date)")
            }
        }

        let suite = "BackupRestorerTestsBuild-\(UUID().uuidString)"
        let buildDefaults = UserDefaults(suiteName: suite)!
        for (k, v) in extraDefaults { buildDefaults.set(v, forKey: k) }
        defer { UserDefaults().removePersistentDomain(forName: suite) }

        let destination = workDir.appendingPathComponent("backup-\(UUID().uuidString).driftbackup")
        try BackupPackager().package(
            dbWriter: dbQueue,
            userDefaults: buildDefaults,
            appMetadata: .init(appBuild: "1042", appVersion: "2.1.0", schemaVersion: schemaVersion),
            destination: destination
        )
        return destination
    }

    /// Build a backup whose `preferences.json` is the literal `rawPrefsJSON`
    /// rather than the Packager's filtered output. Used by the crash-audit
    /// test (#687) to verify the Restorer doesn't crash on null / complex
    /// values that a hand-crafted backup could contain.
    ///
    /// We reuse the standard packager to produce a valid archive, then swap
    /// the prefs entry + recompute its manifest hash so integrity passes.
    private func makeBackupWithRawPreferencesJSON(
        seedRows: Int,
        schemaVersion: Int,
        rawPrefsJSON: String
    ) throws -> URL {
        let backupURL = try makeBackup(seedRows: seedRows, schemaVersion: schemaVersion)
        guard let archive = Archive(url: backupURL, accessMode: .update) else {
            throw NSError(domain: "test", code: 10)
        }
        // Swap the preferences entry for the raw JSON.
        if let oldPrefs = archive[BackupKeys.preferencesFileName] {
            try archive.remove(oldPrefs)
        }
        let prefsData = Data(rawPrefsJSON.utf8)
        try archive.addEntry(
            with: BackupKeys.preferencesFileName,
            type: .file,
            uncompressedSize: Int64(prefsData.count),
            compressionMethod: .deflate,
            provider: { position, size in
                prefsData.subdata(in: Int(position) ..< Int(position) + size)
            }
        )
        // Recompute the manifest's prefs entry so checksum validation passes.
        guard let manifestEntry = archive[BackupKeys.manifestFileName] else {
            throw NSError(domain: "test", code: 11)
        }
        var manifestData = Data()
        _ = try archive.extract(manifestEntry) { manifestData.append($0) }
        var manifest = try BackupManifest.decoder().decode(BackupManifest.self, from: manifestData)
        let newHash = SHA256.hash(data: prefsData).map { String(format: "%02x", $0) }.joined()
        manifest.files[BackupKeys.preferencesFileName] = .init(
            sha256: newHash,
            sizeBytes: Int64(prefsData.count)
        )
        let updated = try BackupManifest.encoder().encode(manifest)
        try archive.remove(manifestEntry)
        try archive.addEntry(
            with: BackupKeys.manifestFileName,
            type: .file,
            uncompressedSize: Int64(updated.count),
            compressionMethod: .deflate,
            provider: { position, size in
                updated.subdata(in: Int(position) ..< Int(position) + size)
            }
        )
        return backupURL
    }

    /// Recompose the archive with a deliberately-wrong manifest checksum for the
    /// DB entry, so integrity validation must reject it.
    private func corruptDatabaseChecksum(in backupURL: URL) throws {
        guard let archive = Archive(url: backupURL, accessMode: .update) else {
            throw NSError(domain: "test", code: 1)
        }
        guard let manifestEntry = archive[BackupKeys.manifestFileName] else {
            throw NSError(domain: "test", code: 2)
        }
        var manifestData = Data()
        _ = try archive.extract(manifestEntry) { manifestData.append($0) }
        var manifest = try BackupManifest.decoder().decode(BackupManifest.self, from: manifestData)
        if let dbEntry = manifest.files[BackupKeys.databaseFileName] {
            manifest.files[BackupKeys.databaseFileName] = .init(
                sha256: String(repeating: "0", count: 64),
                sizeBytes: dbEntry.sizeBytes
            )
        }
        let updated = try BackupManifest.encoder().encode(manifest)
        try archive.remove(manifestEntry)
        try archive.addEntry(
            with: BackupKeys.manifestFileName,
            type: .file,
            uncompressedSize: Int64(updated.count),
            compressionMethod: .deflate,
            provider: { position, size in
                updated.subdata(in: Int(position) ..< Int(position) + size)
            }
        )
    }
}
