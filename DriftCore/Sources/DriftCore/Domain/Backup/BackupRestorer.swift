import Foundation
import GRDB
import CryptoKit
import ZIPFoundation

public struct BackupRestorer {
    public init() {}

    public struct Result: Equatable, Sendable {
        public let manifest: BackupManifest
        public let dbURL: URL
        public let preferenceKeysApplied: [String]
    }

    /// Restore a `.driftbackup` to the on-disk database file and UserDefaults.
    ///
    /// Steps: extract → validate format/schema → SHA-256 integrity → PRAGMA
    /// integrity_check → atomic FileManager.replaceItem into `dbURL` → apply
    /// preferences allowlist. If any step fails, `dbURL` is left untouched.
    @discardableResult
    public func restore(
        from source: URL,
        dbURL: URL,
        defaults: UserDefaults,
        currentSchemaVersion: Int,
        currentFormatVersion: Int = BackupManifest.currentFormatVersion,
        scratchDir: URL? = nil
    ) throws -> Result {
        let workDir = scratchDir ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("drift-restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        let extractedDir = workDir.appendingPathComponent("contents", isDirectory: true)
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        try extractZip(from: source, to: extractedDir)

        let manifest = try loadManifest(in: extractedDir)
        try validateFormatVersion(manifest, supported: currentFormatVersion)
        try validateSchemaVersion(manifest, supported: currentSchemaVersion)
        try validateChecksums(manifest, in: extractedDir)

        let extractedDB = extractedDir.appendingPathComponent(BackupKeys.databaseFileName)
        try runIntegrityCheck(at: extractedDB)

        try atomicSwap(from: extractedDB, to: dbURL)
        let prefsApplied = try applyPreferences(from: extractedDir, to: defaults)

        return Result(manifest: manifest, dbURL: dbURL, preferenceKeysApplied: prefsApplied)
    }

    private func extractZip(from source: URL, to destination: URL) throws {
        guard let archive = Archive(url: source, accessMode: .read) else {
            throw BackupError.invalidFormat("cannot open archive: \(source.lastPathComponent)")
        }
        for entry in archive {
            let target = destination.appendingPathComponent(entry.path)
            do {
                _ = try archive.extract(entry, to: target)
            } catch {
                throw BackupError.invalidFormat("failed to extract \(entry.path): \(error)")
            }
        }
    }

    private func loadManifest(in dir: URL) throws -> BackupManifest {
        let manifestURL = dir.appendingPathComponent(BackupKeys.manifestFileName)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw BackupError.invalidFormat("manifest.json missing")
        }
        let data = try Data(contentsOf: manifestURL)
        do {
            return try BackupManifest.decoder().decode(BackupManifest.self, from: data)
        } catch {
            throw BackupError.invalidFormat("manifest.json unreadable: \(error)")
        }
    }

    private func validateFormatVersion(_ manifest: BackupManifest, supported: Int) throws {
        if manifest.backupFormatVersion > supported {
            throw BackupError.unsupportedFormatVersion(
                found: manifest.backupFormatVersion,
                supported: supported
            )
        }
    }

    private func validateSchemaVersion(_ manifest: BackupManifest, supported: Int) throws {
        if manifest.schemaVersion > supported {
            throw BackupError.unsupportedSchemaVersion(
                found: manifest.schemaVersion,
                supported: supported
            )
        }
    }

    private func validateChecksums(_ manifest: BackupManifest, in dir: URL) throws {
        for (name, expected) in manifest.files {
            let url = dir.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw BackupError.corrupted("expected file \(name) missing")
            }
            let data = try Data(contentsOf: url)
            let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            if actual != expected.sha256 {
                throw BackupError.corrupted("checksum mismatch for \(name)")
            }
        }
    }

    private func runIntegrityCheck(at url: URL) throws {
        do {
            var config = Configuration()
            config.readonly = true
            let queue = try DatabaseQueue(path: url.path, configuration: config)
            let result = try queue.read { db in
                try String.fetchOne(db, sql: "PRAGMA integrity_check")
            }
            if result?.lowercased() != "ok" {
                throw BackupError.integrityCheckFailed(result ?? "(nil)")
            }
        } catch let e as BackupError {
            throw e
        } catch {
            throw BackupError.integrityCheckFailed(String(describing: error))
        }
    }

    private func atomicSwap(from source: URL, to destination: URL) throws {
        let parent = destination.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: source)
            } else {
                try FileManager.default.moveItem(at: source, to: destination)
            }
        } catch {
            throw BackupError.atomicSwapFailed(String(describing: error))
        }
        // GRDB sidecar files (-wal, -shm) become stale after a file replace —
        // remove them so the next AppDatabase open starts cleanly.
        for suffix in ["-wal", "-shm"] {
            let sidecar = URL(fileURLWithPath: destination.path + suffix)
            try? FileManager.default.removeItem(at: sidecar)
        }
    }

    private func applyPreferences(from dir: URL, to defaults: UserDefaults) throws -> [String] {
        let url = dir.appendingPathComponent(BackupKeys.preferencesFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let allowlist = Set(BackupKeys.userDefaultsAllowlist)
        var applied: [String] = []
        for (key, value) in raw where allowlist.contains(key) {
            defaults.set(value, forKey: key)
            applied.append(key)
        }
        return applied.sorted()
    }
}
