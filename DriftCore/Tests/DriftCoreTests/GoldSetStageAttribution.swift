import Foundation
@testable import DriftCore

/// Pure-logic stage attribution for the food-logging gold set.
///
/// For cases that don't reach the LLM (Tier-0 pure-logic runs), only stages
/// 0–2 are observable: normalization, staticRules, and toolRanker. Higher
/// stages (llmIntent, extraction, execution, presentation) require a real
/// model and are attributed by the LLM eval harness instead.
enum GoldSetStageAttribution {

    /// Diagnose which pipeline stage caused a false positive or false negative.
    /// Returns nil when the case passes (no failure to attribute).
    static func diagnose(query: String, expectedDetect: Bool) -> PipelineStage? {
        let normalized = InputNormalizer.normalize(query).lowercased()
        let actualDetect = AIActionExecutor.parseFoodIntent(normalized) != nil
            || (AIActionExecutor.parseMultiFoodIntent(normalized)?.isEmpty == false)

        guard actualDetect != expectedDetect else { return nil }

        if expectedDetect && !actualDetect {
            // False negative: food not detected.
            // Stage 0 heuristic: if normalization completely emptied or over-stripped the input.
            if normalized.count < 3 || normalized.trimmingCharacters(in: .whitespaces).isEmpty {
                return .normalization
            }
            // Otherwise the parser itself missed — stage 1.
            return .staticRules
        } else {
            // False positive: non-food query detected as food — stage 1 over-trigger.
            return .staticRules
        }
    }

    /// Bucket all failing cases by stage. Returns an empty dict when all pass.
    static func attribute(
        cases: [(query: String, shouldDetect: Bool)]
    ) -> [PipelineStage: [String]] {
        var buckets: [PipelineStage: [String]] = [:]
        for (query, expected) in cases {
            if let stage = diagnose(query: query, expectedDetect: expected) {
                buckets[stage, default: []].append(query)
            }
        }
        return buckets
    }

    /// Format a human-readable per-stage failure report.
    static func report(buckets: [PipelineStage: [String]], total: Int) -> String {
        guard !buckets.isEmpty else {
            return "📊 Stage attribution: all \(total) cases pass — no failures."
        }
        let failCount = buckets.values.reduce(0) { $0 + $1.count }
        var lines = ["📊 Per-Stage Failure Attribution (\(failCount)/\(total) failures):"]
        for stage in PipelineStage.allCases {
            guard let failures = buckets[stage], !failures.isEmpty else { continue }
            lines.append("  [\(stage.rawValue)] \(failures.count) miss(es):")
            for q in failures { lines.append("    - \(q)") }
        }
        return lines.joined(separator: "\n")
    }

    /// Persist a report to a temp file so planning sessions can read it.
    static func persist(_ report: String, filename: String = "goldset-stage-report.txt") {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        try? report.data(using: .utf8)?.write(to: url)
    }
}
