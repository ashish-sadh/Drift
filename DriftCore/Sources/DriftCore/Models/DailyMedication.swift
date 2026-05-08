import Foundation
import GRDB

public struct DailyMedication: Identifiable, Codable, Sendable {
    public var id: Int64?
    public var name: String
    public var doseMg: Double?
    public var doseUnit: String?   // "mg", "mcg", "ml", "units", "IU", etc.
    public var loggedAt: String    // ISO 8601 datetime

    enum CodingKeys: String, CodingKey {
        case id, name
        case doseMg = "dose_mg"
        case doseUnit = "dose_unit"
        case loggedAt = "logged_at"
    }

    public init(
        id: Int64? = nil,
        name: String,
        doseMg: Double? = nil,
        doseUnit: String? = nil,
        loggedAt: String
    ) {
        self.id = id
        self.name = name
        self.doseMg = doseMg
        self.doseUnit = doseUnit
        self.loggedAt = loggedAt
    }
}

extension DailyMedication: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "daily_medication"

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
