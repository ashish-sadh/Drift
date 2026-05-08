import Foundation
import DriftCore

@MainActor
public enum MedicationService {

    public static func logMedication(name: String, doseMg: Double?, doseUnit: String?) -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        var entry = DailyMedication(name: name.capitalized, doseMg: doseMg, doseUnit: doseUnit, loggedAt: now)
        try? AppDatabase.shared.saveMedication(&entry)

        var response = "Logged \(name.capitalized)"
        if let dose = doseMg {
            let unit = doseUnit ?? "mg"
            let doseStr = dose == dose.rounded() ? String(Int(dose)) : String(dose)
            response += " (\(doseStr)\(unit))"
        }
        response += "."
        return response
    }

    public static func todayMedications() -> [DailyMedication] {
        (try? AppDatabase.shared.fetchTodayMedications()) ?? []
    }

    /// Most recent log timestamp for a named medication, or nil if never logged.
    public static func lastDoseTime(for name: String) -> Date? {
        let logs = (try? AppDatabase.shared.fetchMedications(for: name, days: 365)) ?? []
        guard let latest = logs.first else { return nil }
        return ISO8601DateFormatter().date(from: latest.loggedAt)
    }

    /// Local-time hours (fractional Double, e.g. 13.5 = 1:30 PM) for recent logs
    /// of a named medication. Used to compute typical dose time for smart reminders.
    public static func recentDoseHours(for name: String, days: Int = 30) -> [Double] {
        let logs = (try? AppDatabase.shared.fetchMedications(for: name, days: days)) ?? []
        return logs.compactMap { log in
            guard let date = ISO8601DateFormatter().date(from: log.loggedAt) else { return nil }
            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            guard let hour = comps.hour, let minute = comps.minute else { return nil }
            return Double(hour) + Double(minute) / 60.0
        }
    }

    /// Names of medications logged at least `minLogs` times in the last `days` days.
    /// These are candidates for smart dose reminders.
    public static func consistentMedicationNames(days: Int = 30, minLogs: Int = 3) -> [String] {
        let all = (try? AppDatabase.shared.fetchAllRecentMedications(days: days)) ?? []
        var counts: [String: Int] = [:]
        for med in all { counts[med.name, default: 0] += 1 }
        return counts.filter { $0.value >= minLogs }.map(\.key).sorted()
    }
}
