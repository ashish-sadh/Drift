import Foundation
import GRDB

/// A medication the user is prescribed or self-administers. Separate from
/// `Supplement` for PHI isolation — see Docs/designs/574-glp1-medication-tracking.md.
/// `MedicationLog` references this by id for per-dose history.
public struct Medication: Identifiable, Codable, Sendable {
    public var id: Int64?
    public var name: String            // generic, lowercased: "semaglutide"
    public var brandName: String?      // "Ozempic", "Wegovy", "Mounjaro"
    public var doseAmount: Double      // prescribed dose, e.g. 0.5
    public var doseUnit: String        // "mg" | "mcg" | "mL" | "units" | "IU"
    public var scheduleType: String    // "daily" | "weekly" | "biweekly" | "asneeded"
    public var reminderTime: String?   // "HH:mm", nil = no reminder
    public var reminderDay: Int?       // 0..6 Sun-Sat, only for weekly/biweekly
    public var startDate: String?      // "YYYY-MM-DD", for chart markers
    public var isActive: Bool          // false = archived, still in history
    public var notes: String?          // free text, e.g. "inject in abdomen"

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case brandName = "brand_name"
        case doseAmount = "dose_amount"
        case doseUnit = "dose_unit"
        case scheduleType = "schedule_type"
        case reminderTime = "reminder_time"
        case reminderDay = "reminder_day"
        case startDate = "start_date"
        case isActive = "is_active"
    }

    public init(
        id: Int64? = nil,
        name: String,
        brandName: String? = nil,
        doseAmount: Double,
        doseUnit: String,
        scheduleType: String = "daily",
        reminderTime: String? = nil,
        reminderDay: Int? = nil,
        startDate: String? = nil,
        isActive: Bool = true,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.brandName = brandName
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.scheduleType = scheduleType
        self.reminderTime = reminderTime
        self.reminderDay = reminderDay
        self.startDate = startDate
        self.isActive = isActive
        self.notes = notes
    }

    /// Display label preferring brand name when present.
    public var displayName: String {
        if let brand = brandName, !brand.isEmpty { return brand }
        return name.capitalized
    }
}

extension Medication: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "medication"
    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
