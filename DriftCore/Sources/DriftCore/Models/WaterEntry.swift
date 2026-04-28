import Foundation
import GRDB

public struct WaterEntry: Identifiable, Codable, Sendable {
    public var id: Int64?
    public var date: String
    public var amountMl: Double
    public var loggedAt: String
    public var source: String

    enum CodingKeys: String, CodingKey {
        case id, date, source
        case amountMl = "amount_ml"
        case loggedAt = "logged_at"
    }

    public init(
        id: Int64? = nil,
        date: String,
        amountMl: Double,
        loggedAt: String = ISO8601DateFormatter().string(from: Date()),
        source: String = "manual"
    ) {
        self.id = id
        self.date = date
        self.amountMl = amountMl
        self.loggedAt = loggedAt
        self.source = source
    }
}

extension WaterEntry: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "water_entry"

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
