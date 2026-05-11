import Foundation

/// Proactive cross-domain pattern detector — surfaces 1-3 statistically
/// significant correlations the user hasn't asked about.
///
/// Different from `cross_domain_insight`: that tool answers a specific
/// `(metric_a, metric_b)` question. This one scans every pair and reports
/// only signals strong enough to be worth a heads-up ("you log more
/// protein on training days").
///
/// Routes on open-ended discovery queries: "what patterns do you see",
/// "any insights from my data", "anything interesting", "show me trends".
/// #739.
@MainActor
public enum CrossDomainPatternDetectorTool {

    nonisolated static let toolName = "cross_domain_pattern_detector"

    nonisolated static let allowedWindows: [Int] = [14, 30, 60, 90]

    // MARK: - Registration

    static func syncRegistration(registry: ToolRegistry = .shared) {
        registry.register(schema)
    }

    static var schema: ToolSchema {
        ToolSchema(
            id: "insights.cross_domain_pattern_detector",
            name: toolName,
            service: "insights",
            description: "User asks open-ended discovery questions like 'what patterns do you see', 'any insights from my data', 'anything interesting in my logs', 'show me trends'. Scans all metric pairs and surfaces the 1-3 strongest cross-domain correlations.",
            parameters: [
                ToolParam("window_days", "number", "Lookback window: 14, 30, 60, or 90 days (default 30)", required: false)
            ],
            handler: { params in
                let window = clampWindow(params.int("window_days"))
                return .text(run(windowDays: window))
            }
        )
    }

    // MARK: - Entry point

    /// Run the detector and return a user-facing summary. Pure except for
    /// the underlying service's DB reads — testable by seeding the DB or
    /// by exercising `formatResults` directly on pre-built patterns.
    public static func run(windowDays: Int = 30, now: Date = Date()) -> String {
        let patterns = CrossDomainPatternService.detect(windowDays: windowDays, now: now)
        return formatResults(patterns, windowDays: windowDays)
    }

    // MARK: - Formatting

    /// Render detected patterns as a numbered list, or a graceful
    /// "nothing strong enough" line when the scan returned nothing.
    /// The blank-state message covers two cases — too little overlapping
    /// data (need ≥14 paired days), and enough data but no signal strong
    /// enough to clear the multi-test threshold. Both reduce to "keep
    /// logging" so we don't try to distinguish them in the copy.
    nonisolated static func formatResults(_ patterns: [CrossDomainPattern], windowDays: Int) -> String {
        guard !patterns.isEmpty else {
            return "Nothing stands out across food, weight, workouts, and glucose for the last \(windowDays) days yet — keep logging (at least 14 overlapping days needed) and ask again."
        }
        let header = patterns.count == 1
            ? "One pattern over the last \(windowDays) days:"
            : "\(patterns.count) patterns over the last \(windowDays) days:"
        let body = patterns.enumerated().map { idx, p in
            "\(idx + 1). \(p.summary)"
        }
        return ([header] + body).joined(separator: "\n")
    }

    // MARK: - Window clamping

    /// Bucket the user-supplied window into one of the allowed sizes.
    /// Defaults to 30 days when missing; mirrors the bucketing style of
    /// `CrossDomainInsightTool.clampWindow`.
    nonisolated static func clampWindow(_ raw: Int?) -> Int {
        guard let raw else { return 30 }
        if raw <= 21 { return 14 }
        if raw <= 45 { return 30 }
        if raw <= 75 { return 60 }
        return 90
    }
}
