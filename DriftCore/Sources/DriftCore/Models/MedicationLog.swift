import Foundation
import GRDB

/// A single dose event for a `Medication`. Stores actual administration time
/// and optional override dose / side-effect note. See
/// Docs/designs/574-glp1-medication-tracking.md.
public struct MedicationLog: Identifiable, Codable, Sendable {
    public var id: Int64?
    public var medicationId: Int64
    public var takenAt: String         // ISO 8601 datetime
    public var doseAmount: Double?     // nil = used prescribed dose from Medication
    public var sideEffects: String?    // free text, e.g. "nausea", "fatigue"
    public var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, notes
        case medicationId = "medication_id"
        case takenAt = "taken_at"
        case doseAmount = "dose_amount"
        case sideEffects = "side_effects"
    }

    public init(
        id: Int64? = nil,
        medicationId: Int64,
        takenAt: String,
        doseAmount: Double? = nil,
        sideEffects: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.medicationId = medicationId
        self.takenAt = takenAt
        self.doseAmount = doseAmount
        self.sideEffects = sideEffects
        self.notes = notes
    }
}

extension MedicationLog: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "medication_log"
    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
