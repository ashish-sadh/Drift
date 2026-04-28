import Foundation
import DriftCore

@MainActor
public enum SupplementInsightTool {

    nonisolated static let toolName = "supplement_insight"

    static func syncRegistration(registry: ToolRegistry = .shared) {
        registry.register(schema)
    }

    static var schema: ToolSchema {
        ToolSchema(
            id: "insights.supplement_insight",
            name: toolName,
            service: "insights",
            description: "User asks about supplement adherence, streak, or consistency — e.g. 'how consistent am I with creatine?', 'what's my vitamin D streak?', 'did I miss any omega-3 this week?'.",
            parameters: [
                ToolParam("supplement", "string", "Supplement name to analyze. Omit for overall adherence across all supplements.", required: false),
                ToolParam("window_days", "number", "Lookback window: 7, 14, or 30 days (default 30)", required: false)
            ],
            handler: { params in
                let name = params.string("supplement")
                let window = clampWindow(params.int("window_days"))
                return .text(run(supplementName: name, windowDays: window))
            }
        )
    }

    // MARK: - Entry point

    public static func run(supplementName: String?, windowDays: Int) -> String {
        let (startStr, endStr) = dateWindow(windowDays: windowDays)
        guard let supplements = try? AppDatabase.shared.fetchActiveSupplements(),
              !supplements.isEmpty else {
            return "No supplements set up. Try 'add creatine' to get started."
        }

        if let raw = supplementName, !raw.isEmpty {
            let lower = raw.lowercased()
            guard let supp = supplements.first(where: { $0.name.lowercased().contains(lower) }),
                  let id = supp.id else {
                let names = supplements.map(\.name).joined(separator: ", ")
                return "Couldn't find '\(raw)'. Your supplements: \(names)."
            }
            let logs = (try? AppDatabase.shared.fetchSupplementLogs(from: startStr, to: endStr)) ?? []
            let takenDates = Set(logs.filter { $0.supplementId == id && $0.taken }.map(\.date))
            let stats = adherenceStats(takenDates: takenDates, startDate: startStr, endDate: endStr, today: endStr)
            return formatSingle(name: supp.name, stats: stats, windowDays: windowDays)
        }

        // Overall adherence across all supplements
        let logs = (try? AppDatabase.shared.fetchSupplementLogs(from: startStr, to: endStr)) ?? []
        var lines: [String] = ["Supplement adherence over \(windowDays) days:"]
        for supp in supplements {
            guard let id = supp.id else { continue }
            let takenDates = Set(logs.filter { $0.supplementId == id && $0.taken }.map(\.date))
            let stats = adherenceStats(takenDates: takenDates, startDate: startStr, endDate: endStr, today: endStr)
            lines.append("  \(supp.name): \(stats.adherencePct)% (\(stats.takenDays)/\(stats.totalDays)d, streak \(stats.currentStreak)d)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Pure stats (testable)

    public struct AdherenceStats: Sendable {
        public let takenDays: Int
        public let totalDays: Int
        public let adherencePct: Int
        public let currentStreak: Int
        public let longestStreak: Int
        public let lastMissedDate: String?
    }

    nonisolated public static func adherenceStats(
        takenDates: Set<String>,
        startDate: String,
        endDate: String,
        today: String
    ) -> AdherenceStats {
        let dates = datesInRange(startDate: startDate, endDate: endDate)
        let total = dates.count
        let taken = takenDates.count
        let pct = total > 0 ? Int(Double(taken) / Double(total) * 100) : 0

        var currentStreak = 0
        for date in dates.reversed() {
            if date > today { continue }
            if takenDates.contains(date) { currentStreak += 1 } else { break }
        }

        var longest = 0, run = 0
        for date in dates {
            if takenDates.contains(date) { run += 1; longest = max(longest, run) } else { run = 0 }
        }

        let lastMissed = dates.reversed().first { $0 <= today && !takenDates.contains($0) }

        return AdherenceStats(
            takenDays: taken, totalDays: total, adherencePct: pct,
            currentStreak: currentStreak, longestStreak: longest, lastMissedDate: lastMissed
        )
    }

    // MARK: - Formatting

    nonisolated static func formatSingle(name: String, stats: AdherenceStats, windowDays: Int) -> String {
        var parts = [
            "\(name) adherence (\(windowDays)d): \(stats.adherencePct)% (\(stats.takenDays)/\(stats.totalDays) days).",
            "Current streak: \(stats.currentStreak) day\(stats.currentStreak == 1 ? "" : "s").",
            "Longest streak: \(stats.longestStreak) day\(stats.longestStreak == 1 ? "" : "s")."
        ]
        if let missed = stats.lastMissedDate { parts.append("Last missed: \(missed).") }
        if stats.adherencePct == 100 {
            parts.append("Perfect adherence!")
        } else if stats.adherencePct >= 80 {
            parts.append("Great consistency — keep it up.")
        } else if stats.adherencePct < 50 {
            parts.append("Tip: take it at the same time each day to build the habit.")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Helpers

    nonisolated static func clampWindow(_ raw: Int?) -> Int {
        guard let raw else { return 30 }
        if raw <= 10 { return 7 }
        if raw <= 21 { return 14 }
        return 30
    }

    nonisolated static func dateWindow(windowDays: Int, now: Date = Date()) -> (start: String, end: String) {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(windowDays - 1), to: now) ?? now
        let fmt = DateFormatters.dateOnly
        return (fmt.string(from: start), fmt.string(from: now))
    }

    nonisolated static func datesInRange(startDate: String, endDate: String) -> [String] {
        let fmt = DateFormatters.dateOnly
        guard let start = fmt.date(from: startDate), let end = fmt.date(from: endDate) else { return [] }
        var out: [String] = []
        var cur = start
        let cal = Calendar.current
        while cur <= end {
            out.append(fmt.string(from: cur))
            guard let next = cal.date(byAdding: .day, value: 1, to: cur) else { break }
            cur = next
        }
        return out
    }
}
