import Foundation
import GRDB

struct BodyComposition: Identifiable, Codable, Sendable {
    var id: Int64?
    var date: String            // "YYYY-MM-DD"
    var bodyFatPct: Double?     // 0-100
    var bmi: Double?            // e.g. 22.5
    var waterPct: Double?       // 0-100
    var source: String          // "manual" | "healthkit" | "smart_scale"
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, date, source, bmi
        case bodyFatPct = "body_fat_pct"
        case waterPct = "water_pct"
        case createdAt = "created_at"
    }

    init(
        id: Int64? = nil,
        date: String,
        bodyFatPct: Double? = nil,
        bmi: Double? = nil,
        waterPct: Double? = nil,
        source: String = "manual",
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id; self.date = date
        self.bodyFatPct = bodyFatPct; self.bmi = bmi; self.waterPct = waterPct
        self.source = source; self.createdAt = createdAt
    }

    var hasData: Bool { bodyFatPct != nil || bmi != nil || waterPct != nil }
}

extension BodyComposition: FetchableRecord, PersistableRecord {
    static let databaseTableName = "body_composition"
    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
