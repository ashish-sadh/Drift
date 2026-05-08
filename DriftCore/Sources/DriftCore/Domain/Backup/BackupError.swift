import Foundation

public enum BackupError: Error, Equatable {
    case iCloudUnavailable
    case quotaExceeded
    case corrupted(String)
    case invalidFormat(String)
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case unsupportedFormatVersion(found: Int, supported: Int)
    case integrityCheckFailed(String)
    case atomicSwapFailed(String)
}
