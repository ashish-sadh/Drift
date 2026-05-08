import XCTest
import GRDB
import ZIPFoundation
import CryptoKit
@testable import DriftCore

final class BackupPackagerTests: XCTestCase {
    private var workDir: URL!

    override func setUp() {
        super.setUp()
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupPackagerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: workDir)
        super.tearDown()
    }

    func testManifestEncodeDecodeRoundtrip() throws {
        let original = BackupManifest(
            appBuild: "1042",
            appVersion: "2.1.0",
            timestamp: Date(timeIntervalSince1970: 1714615212),
            schemaVersion: 14,
            files: [
                "drift.sqlite": .init(sha256: "a3f2c1", sizeBytes: 2_097_152),
                "preferences.json": .init(sha256: "b7e9d4", sizeBytes: 512),
            ]
        )
        let data = try BackupManifest.encoder().encode(original)
        let decoded = try BackupManifest.decoder().decode(BackupManifest.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testFilenamePattern() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 2
        components.hour = 3
        components.minute = 0
        components.second = 12
        let name = BackupPackager.filename(for: components.date!)
        XCTAssertEqual(name, "drift-backup-2026-05-02T030012.driftbackup")
    }

    func testPackageRoundtrip() throws {
        let dbURL = workDir.appendingPathComponent("source.sqlite")
        let dbQueue = try DatabaseQueue(path: dbURL.path)
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE seed_row (id INTEGER PRIMARY KEY, value TEXT)")
            for i in 0..<100 {
                try db.execute(sql: "INSERT INTO seed_row(value) VALUES(?)", arguments: ["row-\(i)"])
            }
        }

        let suite = "BackupPackagerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(150, forKey: "drift.weightGoal")
        defaults.set(2200, forKey: "drift.dailyCalorieTarget")
        defaults.set(true, forKey: "drift.backupEnabled")
        // A non-allowlisted key — must NOT be in the snapshot
        defaults.set("leaked", forKey: "drift.notAllowlisted")
        // A system-namespaced key — must NOT be in the snapshot
        defaults.set("apple", forKey: "AppleLanguages")

        let destination = workDir.appendingPathComponent("test.driftbackup")
        let packager = BackupPackager()
        let manifest = try packager.package(
            dbWriter: dbQueue,
            userDefaults: defaults,
            appMetadata: .init(appBuild: "1042", appVersion: "2.1.0", schemaVersion: 14),
            destination: destination
        )

        XCTAssertEqual(manifest.backupFormatVersion, 1)
        XCTAssertEqual(manifest.appBuild, "1042")
        XCTAssertEqual(manifest.schemaVersion, 14)
        XCTAssertEqual(Set(manifest.files.keys), ["drift.sqlite", "preferences.json"])
        XCTAssertGreaterThan(manifest.files["drift.sqlite"]?.sizeBytes ?? 0, 0)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        let archive = try XCTUnwrap(Archive(url: destination, accessMode: .read))
        let names = Set(archive.map { $0.path })
        XCTAssertEqual(names, ["manifest.json", "drift.sqlite", "preferences.json"])

        // Extract and verify checksums match the manifest
        for (name, expected) in manifest.files {
            let entry = try XCTUnwrap(archive[name])
            var collected = Data()
            _ = try archive.extract(entry) { collected.append($0) }
            let digest = collected.sha256Hex()
            XCTAssertEqual(digest, expected.sha256, "checksum mismatch for \(name)")
            XCTAssertEqual(Int64(collected.count), expected.sizeBytes, "size mismatch for \(name)")
        }

        // Preferences allowlist behavior
        let prefsEntry = try XCTUnwrap(archive["preferences.json"])
        var prefsData = Data()
        _ = try archive.extract(prefsEntry) { prefsData.append($0) }
        let prefs = try JSONSerialization.jsonObject(with: prefsData) as? [String: Any] ?? [:]
        XCTAssertEqual(prefs["drift.weightGoal"] as? Int, 150)
        XCTAssertEqual(prefs["drift.dailyCalorieTarget"] as? Int, 2200)
        XCTAssertEqual(prefs["drift.backupEnabled"] as? Bool, true)
        XCTAssertNil(prefs["drift.notAllowlisted"])
        XCTAssertNil(prefs["AppleLanguages"])

        // Restored DB has all 100 rows
        let restoredDB = workDir.appendingPathComponent("restored.sqlite")
        let dbEntry = try XCTUnwrap(archive["drift.sqlite"])
        var dbData = Data()
        _ = try archive.extract(dbEntry) { dbData.append($0) }
        try dbData.write(to: restoredDB)
        let restoredQueue = try DatabaseQueue(path: restoredDB.path)
        let count = try restoredQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM seed_row")
        }
        XCTAssertEqual(count, 100)

        UserDefaults().removePersistentDomain(forName: suite)
    }

    func testPackageOmitsAbsentKeys() throws {
        let dbURL = workDir.appendingPathComponent("source.sqlite")
        let dbQueue = try DatabaseQueue(path: dbURL.path)
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE x (id INTEGER PRIMARY KEY)")
        }

        let suite = "BackupPackagerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        // Set only one allowlisted key
        defaults.set(150, forKey: "drift.weightGoal")

        let destination = workDir.appendingPathComponent("absent.driftbackup")
        try BackupPackager().package(
            dbWriter: dbQueue,
            userDefaults: defaults,
            appMetadata: .init(appBuild: "1", appVersion: "0.1", schemaVersion: 1),
            destination: destination
        )

        let archive = try XCTUnwrap(Archive(url: destination, accessMode: .read))
        let prefsEntry = try XCTUnwrap(archive["preferences.json"])
        var data = Data()
        _ = try archive.extract(prefsEntry) { data.append($0) }
        let prefs = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        XCTAssertEqual(prefs.count, 1)
        XCTAssertEqual(prefs["drift.weightGoal"] as? Int, 150)
        // Confirm absent allowlisted keys are NOT serialized as null
        XCTAssertNil(prefs["drift.tdeeConfig"])
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("null"))

        UserDefaults().removePersistentDomain(forName: suite)
    }
}

private extension Data {
    func sha256Hex() -> String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}
