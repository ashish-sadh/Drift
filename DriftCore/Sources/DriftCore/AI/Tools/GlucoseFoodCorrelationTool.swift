import Foundation
import DriftCore

/// Correlates logged food items with glucose readings in a ±2h window.
/// Answers "does rice spike my glucose?", "what foods raise my blood sugar?",
/// "which foods cause glucose spikes?". On-device, no cloud, read-only.
///
/// Algorithm: for each food entry logged at time T, compute avg glucose
/// in [T−2h, T] (pre-meal baseline) and [T, T+2h] (post-meal). Delta =
/// post − pre. Aggregate per food name across the lookback window, then
/// rank by average delta descending.
@MainActor
public enum GlucoseFoodCorrelationTool {

    nonisolated static let toolName = "glucose_food_correlation"

    static func syncRegistration(registry: ToolRegistry = .shared) {
        registry.register(schema)
    }

    static var schema: ToolSchema {
        ToolSchema(
            id: "insights.glucose_food_correlation",
            name: toolName,
            service: "insights",
            description: "User asks which foods spike their glucose — 'does rice spike my glucose?', 'what foods raise my blood sugar?', 'does pasta affect my glucose?', 'which foods cause glucose spikes?', 'food and blood sugar correlation'.",
            parameters: [
                ToolParam("query", "string", "User question, used for context"),
                ToolParam("lookback_days", "number", "Days to look back (default 30, max 90)", required: false)
            ],
            handler: { params in
                let days = min(90, max(14, params.int("lookback_days") ?? 30))
                return .text(run(lookbackDays: days))
            }
        )
    }

    // MARK: - Entry point

    public static func run(lookbackDays: Int) -> String {
        let (startStr, endStr) = CrossDomainInsightTool.dateWindow(windowDays: lookbackDays)

        let readings = (try? AppDatabase.shared.fetchGlucoseReadings(from: startStr, to: endStr)) ?? []
        guard readings.count >= 5 else {
            return "Need more glucose data — have \(readings.count) reading\(readings.count == 1 ? "" : "s") in the last \(lookbackDays) days, need at least 5. Log glucose readings for a few days and check back."
        }

        var allFoodEntries: [FoodEntry] = []
        for date in CrossDomainInsightTool.datesInRange(startDate: startStr, endDate: endStr) {
            let entries = (try? AppDatabase.shared.fetchFoodEntries(for: date)) ?? []
            allFoodEntries.append(contentsOf: entries)
        }

        let correlations = correlate(foodEntries: allFoodEntries, glucoseReadings: readings)
        return format(correlations: correlations, readingCount: readings.count, windowDays: lookbackDays)
    }

    // MARK: - Pure analysis (testable)

    public struct FoodCorrelation: Sendable {
        public let foodName: String
        public let avgDeltaMgdl: Double
        public let sampleCount: Int
    }

    /// For each food entry at time T, finds glucose readings in [T−2h, T] (pre) and
    /// [T, T+2h] (post). Delta = postAvg − preAvg. Returns foods ranked by avg delta
    /// descending (highest glucose impact first). Requires ≥ 2 paired samples per food.
    nonisolated public static func correlate(
        foodEntries: [FoodEntry],
        glucoseReadings: [GlucoseReading]
    ) -> [FoodCorrelation] {
        let fmt = DateFormatters.iso8601
        let twoHours: TimeInterval = 2 * 3600

        let parsedReadings: [(date: Date, mgdl: Double)] = glucoseReadings.compactMap { r in
            guard let d = fmt.date(from: r.timestamp) else { return nil }
            return (d, r.glucoseMgdl)
        }
        guard !parsedReadings.isEmpty else { return [] }

        var deltas: [String: [Double]] = [:]

        for entry in foodEntries {
            guard let foodTime = fmt.date(from: entry.loggedAt) else { continue }
            let name = entry.foodName.lowercased().trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            let preReadings = parsedReadings
                .filter { $0.date >= foodTime.addingTimeInterval(-twoHours) && $0.date <= foodTime }
                .map(\.mgdl)
            let postReadings = parsedReadings
                .filter { $0.date > foodTime && $0.date <= foodTime.addingTimeInterval(twoHours) }
                .map(\.mgdl)

            guard !preReadings.isEmpty, !postReadings.isEmpty else { continue }

            let preAvg = preReadings.reduce(0, +) / Double(preReadings.count)
            let postAvg = postReadings.reduce(0, +) / Double(postReadings.count)
            deltas[name, default: []].append(postAvg - preAvg)
        }

        return deltas
            .compactMap { name, ds in
                guard ds.count >= 2 else { return nil }
                let avg = ds.reduce(0, +) / Double(ds.count)
                return FoodCorrelation(foodName: name, avgDeltaMgdl: avg, sampleCount: ds.count)
            }
            .sorted { $0.avgDeltaMgdl > $1.avgDeltaMgdl }
    }

    // MARK: - Formatting

    nonisolated static func format(
        correlations: [FoodCorrelation],
        readingCount: Int,
        windowDays: Int
    ) -> String {
        guard !correlations.isEmpty else {
            return "Not enough food + glucose overlap yet. Make sure you're logging meals and glucose readings around the same times."
        }

        var lines = ["Glucose-food correlation (\(windowDays)d, \(readingCount) readings):"]
        for c in correlations.prefix(5) {
            let sign = c.avgDeltaMgdl >= 0 ? "+" : ""
            let delta = "\(sign)\(Int(c.avgDeltaMgdl.rounded())) mg/dL"
            let label: String
            if c.avgDeltaMgdl > 20 { label = "spikes" }
            else if c.avgDeltaMgdl > 8 { label = "raises" }
            else if c.avgDeltaMgdl < -8 { label = "lowers" }
            else { label = "neutral" }
            lines.append("  \(c.foodName.capitalized): \(delta) avg (\(c.sampleCount) samples) — \(label)")
        }

        if correlations.count > 5 {
            let extra = correlations.count - 5
            lines.append("+ \(extra) more food\(extra == 1 ? "" : "s") tracked")
        }

        lines.append("Tip: correlation, not causation — stress, sleep, and exercise also affect glucose.")
        return lines.joined(separator: "\n")
    }
}
