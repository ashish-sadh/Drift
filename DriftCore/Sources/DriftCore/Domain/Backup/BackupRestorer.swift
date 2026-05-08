import Foundation
import GRDB
import CryptoKit
import ZIPFoundation

/// Atomic restore from a `.driftbackup` file produced by `BackupPackager`.
///
/// Sequence:
///   1. Open archive, read & decode manifest.
///   2. Validate `backupFormatVersion` and `schemaVersion` against this build.
///   3. Extract `drift.sqlite` + `preferences.json` into a scratch dir.
///   4. Verify SHA-256 of each file against the manifest.
///   5. Open extracted DB read-only and run `PRAGMA integrity_check`.
///   6. Run forward migrations on the extracted DB if its schema is older.
///   7. Atomically replace the destination DB file via `FileManager.replaceItem`.
///   8. Apply allowlisted preferences to `userDefaults`.
///
/// On any failure before step 7, the destination DB is untouched. After step 7,
/// preferences may not be applied (degraded but safe — data is restored).
public struct BackupRestorer {
    public init() {}

    /// Restore a `.driftbackup` file into the database at `databaseURL` and apply
    /// allowlisted preferences to `userDefaults`. Returns the restored manifest.
    @discardableResult
    public func restore(
        from backupURL: URL,
        toDatabasePath databaseURL: URL,
        userDefaults: UserDefaults,
        currentSchemaVersion: Int = Migrations.currentVersion,
        scratchDir: URL? = nil
    ) throws -> BackupManifest {
        let workDir = scratchDir ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("drift-restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        guard let archive = Archive(url: backupURL, accessMode: .read) else {
            throw BackupError.invalidFormat("not a zip archive: \(backupURL.lastPathComponent)")
        }

        let manifest = try readManifest(from: archive)

        // Format / schema version gates — fail fast before touching any files.
        if manifest.backupFormatVersion > BackupManifest.currentFormatVersion {
            throw BackupError.unsupportedFormatVersion(
                backupVersion: manifest.backupFormatVersion,
                current: BackupManifest.currentFormatVersion
            )
        }
        if manifest.schemaVersion > currentSchemaVersion {
            throw BackupError.unsupportedSchemaVersion(
                backupVersion: manifest.schemaVersion,
                current: currentSchemaVersion
            )
        }

        let extractedDB = try extractAndVerify(
            archive: archive,
            entryName: BackupKeys.databaseFileName,
            manifest: manifest,
            into: workDir
        )
        let extractedPrefs = try extractAndVerify(
            archive: archive,
            entryName: BackupKeys.preferencesFileName,
            manifest: manifest,
            into: workDir
        )

        try runIntegrityCheck(on: extractedDB)

        if manifest.schemaVersion < currentSchemaVersion {
            try migrateForward(at: extractedDB)
        }

        try atomicReplace(source: extractedDB, destination: databaseURL)

        try applyPreferences(from: extractedPrefs, to: userDefaults)

        return manifest
    }

    // MARK: - Steps

    private func readManifest(from archive: Archive) throws -> BackupManifest {
        guard let entry = archive[BackupKeys.manifestFileName] else {
            throw BackupError.invalidFormat("missing \(BackupKeys.manifestFileName)")
        }
        var data = Data()
        do {
            _ = try archive.extract(entry) { data.append($0) }
        } catch {
            throw BackupError.invalidFormat("failed to read manifest: \(error)")
        }
        do {
            return try BackupManifest.decoder().decode(BackupManifest.self, from: data)
        } catch {
            throw BackupError.invalidFormat("manifest decode failed: \(error)")
        }
    }

    private func extractAndVerify(
        archive: Archive,
        entryName: String,
        manifest: BackupManifest,
        into workDir: URL
    ) throws -> URL {
        guard let entry = archive[entryName] else {
            throw BackupError.invalidFormat("missing entry: \(entryName)")
        }
        guard let expected = manifest.files[entryName] else {
            throw BackupError.invalidFormat("manifest missing entry record: \(entryName)")
        }
        let dest = workDir.appendingPathComponent(entryName)
        var collected = Data()
        do {
            _ = try archive.extract(entry) { collected.append($0) }
        } catch {
            throw BackupError.corrupted("extraction failed for \(entryName): \(error)")
        }
        let actualHash = SHA256.hash(data: collected).map { String(format: "%02x", $0) }.joined()
        if actualHash != expected.sha256 {
            throw BackupError.corrupted("checksum mismatch for \(entryName)")
        }
        if Int64(collected.count) != expected.sizeBytes {
            throw BackupError.corrupted("size mismatch for \(entryName)")
        }
        try collected.write(to: dest)
        return dest
    }

    private func runIntegrityCheck(on dbURL: URL) throws {
        var config = Configuration()
        config.readonly = true
        do {
            let queue = try DatabaseQueue(path: dbURL.path, configuration: config)
            let result = try queue.read { db in
                try String.fetchOne(db, sql: "PRAGMA integrity_check")
            }
            guard result == "ok" else {
                throw BackupError.corrupted("PRAGMA integrity_check: \(result ?? "<nil>")")
            }
        } catch let err as BackupError {
            throw err
        } catch {
            throw BackupError.corrupted("PRAGMA integrity_check failed: \(error)")
        }
    }

    private func migrateForward(at dbURL: URL) throws {
        let queue = try DatabaseQueue(path: dbURL.path)
        try AppDatabase.runMigrations(on: queue)
    }

    private func atomicReplace(source: URL, destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fm.fileExists(atPath: destination.path) {
            // replaceItem requires the destination to exist; otherwise a plain move.
            _ = try fm.replaceItemAt(destination, withItemAt: source)
        } else {
            try fm.moveItem(at: source, to: destination)
        }
        // GRDB WAL/SHM sidecars from older sessions are stale after a swap. Removing
        // them forces SQLite to rebuild from the restored main file.
        try? fm.removeItem(at: URL(fileURLWithPath: destination.path + "-wal"))
        try? fm.removeItem(at: URL(fileURLWithPath: destination.path + "-shm"))
    }

    private func applyPreferences(from url: URL, to defaults: UserDefaults) throws {
        let data = try Data(contentsOf: url)
        let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let allow = Set(BackupKeys.userDefaultsAllowlist)
        for (key, value) in dict where allow.contains(key) {
            // JSON `null` deserializes to NSNull, which is NOT property-list
            // compatible — `defaults.set(NSNull(), forKey:)` raises an
            // uncatchable NSInvalidArgumentException. Drift-produced backups
            // can't contain null (the Packager's `jsonSafeValue` strips it),
            // but a hand-crafted or cross-version backup would crash here.
            // Symmetric primitive filter mirrors `BackupPackager.jsonSafeValue`.
            guard let safe = primitiveValue(value) else { continue }
            defaults.set(safe, forKey: key)
        }
    }

    private func primitiveValue(_ value: Any) -> Any? {
        if value is NSNull { return nil }
        if let v = value as? Bool { return v }
        if let v = value as? Int { return v }
        if let v = value as? Double { return v }
        if let v = value as? String { return v }
        return nil
    }
}
