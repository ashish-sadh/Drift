import Foundation

/// Lightweight description of a `.driftbackup` file on disk: the URL plus the
/// fields lifted from its `manifest.json`. Cheap enough to display in a
/// restore picker without unzipping the archive.
public struct BackupInfo: Identifiable, Equatable, Hashable, Sendable {
    public let url: URL
    public let timestamp: Date
    public let appVersion: String
    public let appBuild: String
    public let backupFormatVersion: Int
    public let schemaVersion: Int

    public var id: URL { url }

    public init(
        url: URL,
        timestamp: Date,
        appVersion: String,
        appBuild: String,
        backupFormatVersion: Int,
        schemaVersion: Int
    ) {
        self.url = url
        self.timestamp = timestamp
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.backupFormatVersion = backupFormatVersion
        self.schemaVersion = schemaVersion
    }

    /// Convenience initializer from a parsed manifest at a known URL.
    public init(url: URL, manifest: BackupManifest) {
        self.url = url
        self.timestamp = manifest.timestamp
        self.appVersion = manifest.appVersion
        self.appBuild = manifest.appBuild
        self.backupFormatVersion = manifest.backupFormatVersion
        self.schemaVersion = manifest.schemaVersion
    }
}
