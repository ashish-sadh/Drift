import Foundation

/// Failure modes for the iCloud backup + restore flow. Maps to the user-facing
/// copy in Section F of `Docs/designs/561-icloud-backup.md`.
public enum BackupError: Error, Equatable {
    /// `FileManager.default.url(forUbiquityContainerIdentifier:)` returned nil —
    /// iCloud Drive is off or the user is signed out of iCloud.
    case iCloudUnavailable

    /// iCloud quota is full (`NSFileWriteOutOfSpaceError`).
    case quotaExceeded

    /// Manifest checksum or `PRAGMA integrity_check` mismatch.
    case corrupted(String)

    /// Manifest is missing, malformed, or the zip lacks expected entries.
    case invalidFormat(String)

    /// Backup's `schemaVersion` is greater than what this app build supports —
    /// the user must update Drift before the backup can be restored.
    case unsupportedSchemaVersion(backupVersion: Int, current: Int)

    /// Backup's `backupFormatVersion` is greater than what this app build can read.
    case unsupportedFormatVersion(backupVersion: Int, current: Int)
}
