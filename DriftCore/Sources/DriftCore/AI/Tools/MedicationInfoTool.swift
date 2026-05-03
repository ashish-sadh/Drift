import Foundation
import DriftCore

@MainActor
public enum MedicationInfoTool {

    nonisolated static let toolName = "medication_info"

    static func syncRegistration(registry: ToolRegistry = .shared) {
        registry.register(schema)
    }

    static var schema: ToolSchema {
        ToolSchema(
            id: "health.medication_info",
            name: toolName,
            service: "health",
            description: "User asks about medication history, last dose time, or dosing patterns — e.g. 'when did I last take ozempic?', 'how often do I take metformin?', 'what time did I inject semaglutide?'.",
            parameters: [
                ToolParam("medication", "string", "Medication name to query. Omit for all recent medications.", required: false),
                ToolParam("window_days", "number", "Lookback window in days (default 30)", required: false)
            ],
            handler: { params in
                let name = params.string("medication")
                let window = min(max(params.int("window_days") ?? 30, 1), 365)
                return .text(run(medicationName: name, windowDays: window))
            }
        )
    }

    // MARK: - Entry point

    public static func run(medicationName: String?, windowDays: Int) -> String {
        let consistent = MedicationService.consistentMedicationNames(days: windowDays, minLogs: 1)

        if let raw = medicationName, !raw.isEmpty {
            let lower = raw.lowercased()
            let matched = consistent.first(where: { $0.lowercased().contains(lower) }) ?? raw.capitalized

            guard let lastDate = MedicationService.lastDoseTime(for: matched) else {
                return "No \(matched) doses logged in the last \(windowDays) days."
            }

            let relativeStr = relativeDate(lastDate)
            let timeStr = timeString(lastDate)
            let hours = MedicationService.recentDoseHours(for: matched, days: windowDays)
            var response = "Last \(matched): \(relativeStr) at \(timeStr)."
            if hours.count > 1 {
                let avg = hours.reduce(0, +) / Double(hours.count)
                let avgHour = Int(avg)
                let avgMin = Int((avg - Double(avgHour)) * 60)
                let ampm = avgHour >= 12 ? "PM" : "AM"
                let h12 = avgHour == 0 ? 12 : (avgHour > 12 ? avgHour - 12 : avgHour)
                let typicalStr = String(format: "%d:%02d %@", h12, avgMin, ampm)
                response += " Typical dose time: \(typicalStr) (\(hours.count) logs)."
            }
            return response
        }

        // All recent medications
        guard !consistent.isEmpty else {
            return "No medications logged in the last \(windowDays) days."
        }
        var lines = ["Medications in the last \(windowDays) days:"]
        for name in consistent {
            if let lastDate = MedicationService.lastDoseTime(for: name) {
                lines.append("  \(name): last taken \(relativeDate(lastDate)) at \(timeString(lastDate))")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Formatting helpers (pure, testable)

    nonisolated public static func relativeDate(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return "today"
        case 1: return "yesterday"
        case 2...6: return "\(days) days ago"
        default:
            let weeks = days / 7
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        }
    }

    nonisolated public static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
