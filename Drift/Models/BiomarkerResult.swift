import Foundation
import GRDB

/// A single biomarker value extracted from a lab report.
struct BiomarkerResult: Identifiable, Codable, Sendable {
    var id: Int64?
    var reportId: Int64            // FK to lab_report
    var biomarkerId: String        // matches BiomarkerDefinition.id (e.g. "total_cholesterol")
    var value: Double
    var unit: String               // original unit from report
    var normalizedValue: Double    // value converted to standard unit
    var normalizedUnit: String     // standard unit (from BiomarkerDefinition)
    var referenceLow: Double?      // lab's reference range (if provided)
    var referenceHigh: Double?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, value, unit
        case reportId = "report_id"
        case biomarkerId = "biomarker_id"
        case normalizedValue = "normalized_value"
        case normalizedUnit = "normalized_unit"
        case referenceLow = "reference_low"
        case referenceHigh = "reference_high"
        case createdAt = "created_at"
    }

    init(
        id: Int64? = nil,
        reportId: Int64,
        biomarkerId: String,
        value: Double,
        unit: String,
        normalizedValue: Double? = nil,
        normalizedUnit: String? = nil,
        referenceLow: Double? = nil,
        referenceHigh: Double? = nil,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.reportId = reportId
        self.biomarkerId = biomarkerId
        self.value = value
        self.unit = unit
        self.normalizedValue = normalizedValue ?? value
        self.normalizedUnit = normalizedUnit ?? unit
        self.referenceLow = referenceLow
        self.referenceHigh = referenceHigh
        self.createdAt = createdAt
    }
}

extension BiomarkerResult: FetchableRecord, PersistableRecord {
    static let databaseTableName = "biomarker_result"
    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
