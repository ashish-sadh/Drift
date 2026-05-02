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
        let today = DateFormatters.todayString
        return (try? AppDatabase.shared.fetchTodayMedications(datePrefix: today)) ?? []
    }
}
