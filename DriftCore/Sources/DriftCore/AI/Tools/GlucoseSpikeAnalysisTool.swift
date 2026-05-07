import Foundation

/// AI tool: detects which meals cause glucose spikes (>30 mg/dL peak rise within 2h).
/// Distinct from GlucoseFoodCorrelationTool (avg delta) — this uses peak detection
/// and binary spike classification for "what's spiking my blood sugar?" queries.
@MainActor
public enum GlucoseSpikeAnalysisTool {

    nonisolated static let toolName = "glucose_spike_analysis"

    static func syncRegistration(registry: ToolRegistry = .shared) {
        registry.register(schema)
    }

    static var schema: ToolSchema {
        ToolSchema(
            id: "insights.glucose_spike_analysis",
            name: toolName,
            service: "insights",
            description: "User asks what foods are spiking their glucose — 'what's spiking my blood sugar?', 'what causes my glucose spikes?', 'which meals give me glucose spikes?', 'post-meal glucose spike'. Uses peak detection (>30 mg/dL rise within 2h of meal).",
            parameters: [
                ToolParam("query", "string", "User question"),
                ToolParam("lookback_days", "number", "Days to look back (default 30, max 90)", required: false)
            ],
            handler: { params in
                let days = min(90, max(14, params.int("lookback_days") ?? 30))
                return .text(run(lookbackDays: days))
            }
        )
    }

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

        let spikes = GlucoseAnalyticsService.detectSpikes(foodEntries: allFoodEntries, readings: readings)
        let foods = GlucoseAnalyticsService.spikingFoods(from: spikes)
        return format(foods: foods, spikeCount: spikes.count, readingCount: readings.count, windowDays: lookbackDays)
    }

    nonisolated static func format(
        foods: [GlucoseAnalyticsService.FoodSpikeRecord],
        spikeCount: Int,
        readingCount: Int,
        windowDays: Int
    ) -> String {
        guard !foods.isEmpty else {
            if spikeCount == 0 {
                return "No post-meal glucose spikes detected in the last \(windowDays) days (\(readingCount) readings). Keep it up — your meals appear to be keeping glucose steady."
            }
            return "Detected \(spikeCount) glucose spike\(spikeCount == 1 ? "" : "s") but each food had fewer than 2 observations. Log more meals to see patterns."
        }

        var lines = ["Meals linked to glucose spikes (last \(windowDays)d, \(readingCount) readings, threshold >30 mg/dL):"]
        for food in foods.prefix(5) {
            let avg = Int(food.avgDeltaMgdl.rounded())
            lines.append("• \(food.foodName): +\(avg) mg/dL avg spike (\(food.spikeCount) observation\(food.spikeCount == 1 ? "" : "s"))")
        }
        if foods.count > 5 {
            lines.append("…and \(foods.count - 5) more")
        }
        lines.append("\nTip: try smaller portions or pairing with protein/fat to blunt the spike.")
        return lines.joined(separator: "\n")
    }
}
