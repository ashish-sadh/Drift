import Foundation
import GRDB

struct Supplement: Identifiable, Codable, Sendable {
    var id: Int64?
    var name: String
    var dosage: String?
    var unit: String?
    var isActive: Bool
    var sortOrder: Int
    var dailyDoses: Int
    var reminderTime: String?  // "HH:mm" or nil

    enum CodingKeys: String, CodingKey {
        case id, name, dosage, unit
        case isActive = "is_active"
        case sortOrder = "sort_order"
        case dailyDoses = "daily_doses"
        case reminderTime = "reminder_time"
    }

    init(
        id: Int64? = nil, name: String, dosage: String? = nil, unit: String? = nil,
        isActive: Bool = true, sortOrder: Int = 0, dailyDoses: Int = 1, reminderTime: String? = nil
    ) {
        self.id = id; self.name = name; self.dosage = dosage; self.unit = unit
        self.isActive = isActive; self.sortOrder = sortOrder
        self.dailyDoses = dailyDoses; self.reminderTime = reminderTime
    }

    var dosageDisplay: String {
        guard let dosage, let unit else { return "" }
        let freq = dailyDoses > 1 ? " × \(dailyDoses)/day" : ""
        return "\(dosage) \(unit)\(freq)"
    }
}

extension Supplement: FetchableRecord, PersistableRecord {
    static let databaseTableName = "supplement"
    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
