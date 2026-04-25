import Foundation
import DriftCore

/// Domain service for DEXA scan operations.
@MainActor
public enum DEXAService {

    /// Fetch all DEXA scans, ordered by date descending.
    public static func fetchScans() -> [DEXAScan] {
        (try? AppDatabase.shared.fetchDEXAScans()) ?? []
    }

    /// Fetch regional breakdown for a specific scan.
    public static func fetchRegions(forScanId id: Int64) -> [DEXARegion] {
        (try? AppDatabase.shared.fetchDEXARegions(forScanId: id)) ?? []
    }

    /// Save a manually entered DEXA scan.
    public static func saveScan(_ scan: inout DEXAScan) {
        try? AppDatabase.shared.saveDEXAScan(&scan)
    }

    /// Import scans parsed from a BodySpec PDF. Returns count imported.
    public static func importBodySpecScans(_ parsedScans: [BodySpecParsedScan]) throws -> Int {
        try AppDatabase.shared.importBodySpecScans(parsedScans)
    }

    /// Delete a single DEXA scan.
    public static func deleteScan(id: Int64) {
        try? AppDatabase.shared.deleteDEXAScan(id: id)
    }

    /// Delete all DEXA scans.
    public static func deleteAllScans() {
        try? AppDatabase.shared.deleteAllDEXAScans()
    }
}
