import Foundation
import GRDB

/// A lab report uploaded by the user (PDF or image).
struct LabReport: Identifiable, Codable, Sendable {
    var id: Int64?
    var reportDate: String         // ISO 8601 date (YYYY-MM-DD)
    var labName: String?           // "Quest", "Labcorp", etc.
    var fileName: String           // original file name
    var fileDataHash: String       // SHA256 hash of encrypted file data
    var markerCount: Int           // how many biomarkers were extracted
    var notes: String?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, notes
        case reportDate = "report_date"
        case labName = "lab_name"
        case fileName = "file_name"
        case fileDataHash = "file_data_hash"
        case markerCount = "marker_count"
        case createdAt = "created_at"
    }

    init(
        id: Int64? = nil,
        reportDate: String,
        labName: String? = nil,
        fileName: String,
        fileDataHash: String = "",
        markerCount: Int = 0,
        notes: String? = nil,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.reportDate = reportDate
        self.labName = labName
        self.fileName = fileName
        self.fileDataHash = fileDataHash
        self.markerCount = markerCount
        self.notes = notes
        self.createdAt = createdAt
    }

    /// Display-friendly date.
    var displayDate: String {
        guard let date = DateFormatters.dateOnly.date(from: reportDate) else { return reportDate }
        return DateFormatters.dayDisplay.string(from: date)
    }
}

extension LabReport: FetchableRecord, PersistableRecord {
    static let databaseTableName = "lab_report"
    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
