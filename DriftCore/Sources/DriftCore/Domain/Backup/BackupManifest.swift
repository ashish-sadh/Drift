import Foundation

public struct BackupManifest: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1

    public var backupFormatVersion: Int
    public var appBuild: String
    public var appVersion: String
    public var timestamp: Date
    public var schemaVersion: Int
    public var files: [String: FileEntry]

    public struct FileEntry: Codable, Equatable, Sendable {
        public var sha256: String
        public var sizeBytes: Int64

        public init(sha256: String, sizeBytes: Int64) {
            self.sha256 = sha256
            self.sizeBytes = sizeBytes
        }
    }

    public init(
        backupFormatVersion: Int = BackupManifest.currentFormatVersion,
        appBuild: String,
        appVersion: String,
        timestamp: Date,
        schemaVersion: Int,
        files: [String: FileEntry]
    ) {
        self.backupFormatVersion = backupFormatVersion
        self.appBuild = appBuild
        self.appVersion = appVersion
        self.timestamp = timestamp
        self.schemaVersion = schemaVersion
        self.files = files
    }

    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
