import Foundation
import DriftCore

@MainActor
public enum SleepFoodCorrelationTool {

    nonisolated static let toolName = "sleep_food_correlation"

    static func syncRegistration(registry: ToolRegistry = .shared) {
        registry.register(schema)
    }

    static var schema: ToolSchema {
        ToolSchema(
            id: "insights.sleep_food_correlation",
            name: toolName,
            service: "insights",
            description: "User asks whether late eating affects sleep — 'does eating late affect my sleep?', 'should I stop eating earlier?', 'what time should I have my last meal?', 'is late-night snacking hurting my sleep?'.",
            parameters: [
                ToolParam("window_days", "number", "Lookback window in days (default 30)", required: false)
            ],
            handler: { params in
                let window = max(14, min(90, params.int("window_days") ?? 30))
                return .text(await run(windowDays: window))
            }
        )
    }

    // MARK: - Entry point (async — fetches from HealthKit)

    public static func run(windowDays: Int) async -> String {
        guard let hk = DriftPlatform.health,
              let sleepNights = try? await hk.fetchRecentSleepData(days: windowDays),
              !sleepNights.isEmpty else {
            return "No sleep data available. Connect your Apple Watch or a compatible sleep tracker in the Health app to enable this analysis."
        }

        var pairs: [(lastMealHour: Double, sleepHours: Double)] = []
        for night in sleepNights {
            let dateStr = DateFormatters.dateOnly.string(from: night.date)
            let entries = (try? AppDatabase.shared.fetchFoodEntries(for: dateStr)) ?? []
            guard let lastHour = entries.compactMap({ FoodTimingInsightTool.parseLocalHour($0.loggedAt) }).max() else { continue }
            pairs.append((lastMealHour: lastHour, sleepHours: night.hours))
        }

        guard pairs.count >= 5 else {
            return "Need at least 5 nights with both food logged and sleep tracked — have \(pairs.count) so far. Keep logging meals and check back."
        }

        return formatResult(analyze(pairs: pairs))
    }

    // MARK: - Pure analysis (testable)

    public struct CorrelationResult: Sendable {
        public let lateDinnerAvgSleep: Double?
        public let earlyDinnerAvgSleep: Double?
        public let lateDinnerCount: Int
        public let earlyDinnerCount: Int
        public let pearsonR: Double?
        public let totalPairs: Int
    }

    nonisolated public static func analyze(pairs: [(lastMealHour: Double, sleepHours: Double)]) -> CorrelationResult {
        let late = pairs.filter { $0.lastMealHour >= 20.0 }
        let early = pairs.filter { $0.lastMealHour < 19.0 }

        func avg(_ items: [(lastMealHour: Double, sleepHours: Double)]) -> Double? {
            guard !items.isEmpty else { return nil }
            return items.map(\.sleepHours).reduce(0, +) / Double(items.count)
        }

        let r = CrossDomainInsightTool.pearsonR(
            xs: pairs.map(\.lastMealHour),
            ys: pairs.map(\.sleepHours)
        )

        return CorrelationResult(
            lateDinnerAvgSleep: avg(late),
            earlyDinnerAvgSleep: avg(early),
            lateDinnerCount: late.count,
            earlyDinnerCount: early.count,
            pearsonR: r,
            totalPairs: pairs.count
        )
    }

    // MARK: - Formatting

    nonisolated static func formatResult(_ result: CorrelationResult) -> String {
        var lines: [String] = []

        if let late = result.lateDinnerAvgSleep, let early = result.earlyDinnerAvgSleep,
           result.lateDinnerCount >= 3, result.earlyDinnerCount >= 3 {
            let diff = early - late
            lines.append("Based on \(result.totalPairs) nights:")
            lines.append("  Late dinner (after 8pm, \(result.lateDinnerCount)n): avg \(String(format: "%.1f", late))h sleep")
            lines.append("  Early dinner (before 7pm, \(result.earlyDinnerCount)n): avg \(String(format: "%.1f", early))h sleep")
            if diff > 0.25 {
                lines.append("You sleep \(String(format: "%.1f", diff))h longer on early dinner nights.")
                lines.append("Recommendation: try finishing your last meal before 7pm.")
            } else if diff < -0.25 {
                lines.append("Interestingly, you sleep \(String(format: "%.1f", abs(diff)))h longer on late dinner nights — other factors may dominate.")
            } else {
                lines.append("Dinner timing doesn't strongly affect your sleep duration.")
            }
            return lines.joined(separator: "\n")
        }

        // Fall back to Pearson correlation when groups are too small
        guard let r = result.pearsonR else {
            return "Couldn't compute a correlation — meal timing may be too consistent to vary. Keep logging for a more varied dataset."
        }
        let strength = CrossDomainInsightTool.strengthLabel(r)
        let direction = CrossDomainInsightTool.directionLabel(r)
        let rStr = String(format: "%+.2f", r)
        lines.append("Based on \(result.totalPairs) nights: last meal time vs sleep correlation r=\(rStr) (\(strength) \(direction)).")
        if r < -0.3 {
            lines.append("Later meals tend to be followed by shorter sleep.")
            lines.append("Try finishing your last meal at least 2–3 hours before bed.")
        } else {
            lines.append("No strong pattern detected — dinner timing may not be a major factor for you.")
        }
        return lines.joined(separator: "\n")
    }
}
