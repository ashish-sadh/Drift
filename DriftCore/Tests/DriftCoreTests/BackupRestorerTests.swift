import XCTest
import GRDB
import ZIPFoundation
import CryptoKit
@testable import DriftCore

final class BackupRestorerTests: XCTestCase {
    private var workDir: URL!

    override func setUp() {
        super.setUp()
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupRestorerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: workDir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeBackup(
        seedRows: Int = 100,
        prefs: [(String, Any)] = [],
        appMetadata: BackupPackager.AppMetadata = .init(appBuild: "1042", appVersion: "2.1.0", schemaVersion: 14),
        suite: String? = nil
    ) throws -> (backupURL: URL, prefsSuite: String) {
        let dbURL = workDir.appendingPathComponent("source-\(UUID().uuidString).sqlite")
        let dbQueue = try DatabaseQueue(path: dbURL.path)
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE seed_row (id INTEGER PRIMARY KEY, value TEXT)")
            for i in 0..<seedRows {
                try db.execute(sql: "INSERT INTO seed_row(value) VALUES(?)", arguments: ["row-\(i)"])
            }
        }

        let suiteName = suite ?? "BackupRestorerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        for (k, v) in prefs { defaults.set(v, forKey: k) }

        let backupURL = workDir.appendingPathComponent("test-\(UUID().uuidString).driftbackup")
        try BackupPackager().package(
            dbWriter: dbQueue,
            userDefaults: defaults,
            appMetadata: appMetadata,
            destination: backupURL
        )
        return (backupURL, suiteName)
    }

    private func corruptManifestChecksum(in backupURL: URL) throws {
        let editDir = workDir.appendingPathComponent("edit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: editDir, withIntermediateDirectories: true)
        let extractArchive = try XCTUnwrap(Archive(url: backupURL, accessMode: .read))
        for entry in extractArchive {
            let target = editDir.appendingPathComponent(entry.path)
            _ = try extractArchive.extract(entry, to: target)
        }
        // Tamper with manifest
        let manifestURL = editDir.appendingPathComponent(BackupKeys.manifestFileName)
        var manifest = try BackupManifest.decoder().decode(
            BackupManifest.self, from: try Data(contentsOf: manifestURL)
        )
        let dbName = BackupKeys.databaseFileName
        manifest.files[dbName] = .init(sha256: "0000000000", sizeBytes: manifest.files[dbName]!.sizeBytes)
        try BackupManifest.encoder().encode(manifest).write(to: manifestURL)

        // Re-zip
        try FileManager.default.removeItem(at: backupURL)
        let archive = try XCTUnwrap(Archive(url: backupURL, accessMode: .create))
        for name in [BackupKeys.manifestFileName, BackupKeys.databaseFileName, BackupKeys.preferencesFileName] {
            let url = editDir.appendingPathComponent(name)
            try archive.addEntry(with: name, fileURL: url, compressionMethod: .deflate)
        }
    }

    private func removeManifest(in backupURL: URL) throws {
        let editDir = workDir.appendingPathComponent("edit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: editDir, withIntermediateDirectories: true)
        let inArchive = try XCTUnwrap(Archive(url: backupURL, accessMode: .read))
        for entry in inArchive where entry.path != BackupKeys.manifestFileName {
            let target = editDir.appendingPathComponent(entry.path)
            _ = try inArchive.extract(entry, to: target)
        }
        try FileManager.default.removeItem(at: backupURL)
        let outArchive = try XCTUnwrap(Archive(url: backupURL, accessMode: .create))
        for name in [BackupKeys.databaseFileName, BackupKeys.preferencesFileName] {
            let url = editDir.appendingPathComponent(name)
            try outArchive.addEntry(with: name, fileURL: url, compressionMethod: .deflate)
        }
    }

    private func wipeSuite(_ suite: String) {
        UserDefaults().removePersistentDomain(forName: suite)
    }

    // MARK: - Tests

    func testRoundtripRestoresAllRowsAndPrefs() throws {
        let (backup, suite) = try makeBackup(
            seedRows: 100,
            prefs: [
                ("drift.weightGoal", 150),
                ("drift.dailyCalorieTarget", 2200),
                ("drift.backupEnabled", true),
            ]
        )
        defer { wipeSuite(suite) }

        // Pre-populate the target DB with different data — restore must replace it
        let targetDB = workDir.appendingPathComponent("target.sqlite")
        let targetQueue = try DatabaseQueue(path: targetDB.path)
        try targetQueue.write { db in
            try db.execute(sql: "CREATE TABLE seed_row (id INTEGER PRIMARY KEY, value TEXT)")
            try db.execute(sql: "INSERT INTO seed_row(value) VALUES('stale')")
        }

        let restoreSuite = "RestoreTarget-\(UUID().uuidString)"
        let restoreDefaults = UserDefaults(suiteName: restoreSuite)!
        defer { wipeSuite(restoreSuite) }

        let result = try BackupRestorer().restore(
            from: backup,
            dbURL: targetDB,
            defaults: restoreDefaults,
            currentSchemaVersion: 14
        )

        XCTAssertEqual(result.manifest.appBuild, "1042")
        XCTAssertEqual(result.preferenceKeysApplied,
                       ["drift.backupEnabled", "drift.dailyCalorieTarget", "drift.weightGoal"])

        let restoredQueue = try DatabaseQueue(path: targetDB.path)
        let count = try restoredQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM seed_row")
        }
        XCTAssertEqual(count, 100)

        XCTAssertEqual(restoreDefaults.integer(forKey: "drift.weightGoal"), 150)
        XCTAssertEqual(restoreDefaults.integer(forKey: "drift.dailyCalorieTarget"), 2200)
        XCTAssertEqual(restoreDefaults.bool(forKey: "drift.backupEnabled"), true)
    }

    func testCorruptedManifestChecksumLeavesTargetUntouched() throws {
        let (backup, suite) = try makeBackup()
        defer { wipeSuite(suite) }
        try corruptManifestChecksum(in: backup)

        let targetDB = workDir.appendingPathComponent("target-corrupt.sqlite")
        let targetQueue = try DatabaseQueue(path: targetDB.path)
        try targetQueue.write { db in
            try db.execute(sql: "CREATE TABLE original (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO original(id) VALUES(99)")
        }

        XCTAssertThrowsError(try BackupRestorer().restore(
            from: backup,
            dbURL: targetDB,
            defaults: UserDefaults(suiteName: "ignored")!,
            currentSchemaVersion: 14
        )) { error in
            guard case BackupError.corrupted = error else {
                XCTFail("expected BackupError.corrupted, got \(error)")
                return
            }
        }

        // Original DB still intact
        let postQueue = try DatabaseQueue(path: targetDB.path)
        let stayed = try postQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM original")
        }
        XCTAssertEqual(stayed, 1)
    }

    func testMissingManifestReturnsInvalidFormat() throws {
        let (backup, suite) = try makeBackup()
        defer { wipeSuite(suite) }
        try removeManifest(in: backup)

        let targetDB = workDir.appendingPathComponent("target-missing-manifest.sqlite")
        XCTAssertThrowsError(try BackupRestorer().restore(
            from: backup,
            dbURL: targetDB,
            defaults: UserDefaults(suiteName: "ignored")!,
            currentSchemaVersion: 14
        )) { error in
            guard case BackupError.invalidFormat = error else {
                XCTFail("expected BackupError.invalidFormat, got \(error)")
                return
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetDB.path))
    }

    func testSchemaVersionTooNewIsRejected() throws {
        let (backup, suite) = try makeBackup(
            appMetadata: .init(appBuild: "1", appVersion: "0.1", schemaVersion: 99)
        )
        defer { wipeSuite(suite) }

        let targetDB = workDir.appendingPathComponent("target-schema-too-new.sqlite")
        XCTAssertThrowsError(try BackupRestorer().restore(
            from: backup,
            dbURL: targetDB,
            defaults: UserDefaults(suiteName: "ignored")!,
            currentSchemaVersion: 14
        )) { error in
            guard case BackupError.unsupportedSchemaVersion(let found, let supported) = error else {
                XCTFail("expected BackupError.unsupportedSchemaVersion, got \(error)")
                return
            }
            XCTAssertEqual(found, 99)
            XCTAssertEqual(supported, 14)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetDB.path))
    }

    func testOlderSchemaVersionRestoreSucceeds() throws {
        let (backup, suite) = try makeBackup(
            appMetadata: .init(appBuild: "1", appVersion: "0.1", schemaVersion: 5)
        )
        defer { wipeSuite(suite) }

        let targetDB = workDir.appendingPathComponent("target-older-schema.sqlite")
        let restoreDefaults = UserDefaults(suiteName: "older-schema-\(UUID().uuidString)")!
        let result = try BackupRestorer().restore(
            from: backup,
            dbURL: targetDB,
            defaults: restoreDefaults,
            currentSchemaVersion: 14
        )
        XCTAssertEqual(result.manifest.schemaVersion, 5)
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetDB.path))
    }

    func testFormatVersionTooNewIsRejected() throws {
        let (backup, suite) = try makeBackup()
        defer { wipeSuite(suite) }

        // Tamper the manifest's backupFormatVersion
        let editDir = workDir.appendingPathComponent("edit-fv", isDirectory: true)
        try FileManager.default.createDirectory(at: editDir, withIntermediateDirectories: true)
        let inArchive = try XCTUnwrap(Archive(url: backup, accessMode: .read))
        for entry in inArchive {
            let target = editDir.appendingPathComponent(entry.path)
            _ = try inArchive.extract(entry, to: target)
        }
        let manifestURL = editDir.appendingPathComponent(BackupKeys.manifestFileName)
        var manifest = try BackupManifest.decoder().decode(BackupManifest.self, from: try Data(contentsOf: manifestURL))
        manifest.backupFormatVersion = 99
        try BackupManifest.encoder().encode(manifest).write(to: manifestURL)
        try FileManager.default.removeItem(at: backup)
        let outArchive = try XCTUnwrap(Archive(url: backup, accessMode: .create))
        for name in [BackupKeys.manifestFileName, BackupKeys.databaseFileName, BackupKeys.preferencesFileName] {
            let url = editDir.appendingPathComponent(name)
            try outArchive.addEntry(with: name, fileURL: url, compressionMethod: .deflate)
        }

        let targetDB = workDir.appendingPathComponent("target-fv.sqlite")
        XCTAssertThrowsError(try BackupRestorer().restore(
            from: backup,
            dbURL: targetDB,
            defaults: UserDefaults(suiteName: "ignored")!,
            currentSchemaVersion: 14
        )) { error in
            guard case BackupError.unsupportedFormatVersion = error else {
                XCTFail("expected BackupError.unsupportedFormatVersion, got \(error)")
                return
            }
        }
    }
}
