import XCTest
@testable import DriftCore

/// Tier 0 — pure logic, no LLM, no simulator.
/// Verifies that GoldSetStageAttribution diagnoses failing cases to the correct
/// pipeline stage, and that passing cases produce nil (no attribution needed).
///
/// Run: `cd DriftCore && swift test --filter GoldSetStageAttributionTests`
final class GoldSetStageAttributionTests: XCTestCase {

    // MARK: - Passing cases → no attribution

    func testPassingFoodCase_ReturnsNil() {
        // "log 2 eggs" is a clear food intent — should pass with no failure.
        let stage = GoldSetStageAttribution.diagnose(query: "log 2 eggs", expectedDetect: true)
        XCTAssertNil(stage, "Passing case must return nil — no stage to blame")
    }

    func testPassingNonFoodCase_ReturnsNil() {
        // "how many calories left" must NOT be detected as food — passing negative.
        let stage = GoldSetStageAttribution.diagnose(query: "how many calories left", expectedDetect: false)
        XCTAssertNil(stage, "Passing non-food case must return nil")
    }

    // MARK: - False negative → staticRules (parser missed food)

    func testFalseNegative_NormalInput_AttributesToStaticRules() {
        // A query that looks like food but parseFoodIntent misses → staticRules.
        // Use a deliberately obscure phrasing that the parser doesn't cover yet.
        // We diagnose it as staticRules (not normalization) because the input is valid text.
        let normalized = InputNormalizer.normalize("scarfed down a bowl of porridge").lowercased()
        let detected = AIActionExecutor.parseFoodIntent(normalized) != nil
        if !detected {
            // Parser misses this → should attribute to staticRules, not normalization
            let stage = GoldSetStageAttribution.diagnose(
                query: "scarfed down a bowl of porridge", expectedDetect: true)
            XCTAssertEqual(stage, .staticRules,
                "Normal-text false negative should be attributed to staticRules parser miss")
        } else {
            // Parser catches it — test is moot; pass silently
        }
    }

    // MARK: - False positive → staticRules (parser over-triggered)

    func testFalsePositive_AttributesToStaticRules() {
        // Build a synthetic case where parseFoodIntent fires on a non-food query.
        // "egg chart" — "egg" is a food word but "chart" signals info-lookup intent.
        // If the parser fires, it's a staticRules over-trigger.
        let normalized = InputNormalizer.normalize("egg chart").lowercased()
        let detected = AIActionExecutor.parseFoodIntent(normalized) != nil
        if detected {
            let stage = GoldSetStageAttribution.diagnose(query: "egg chart", expectedDetect: false)
            XCTAssertEqual(stage, .staticRules,
                "False positive must be attributed to staticRules over-trigger")
        } else {
            // Parser correctly rejects it — test is moot; pass silently
        }
    }

    // MARK: - Attribution report

    func testReport_EmptyBuckets_ShowsAllPass() {
        let report = GoldSetStageAttribution.report(buckets: [:], total: 10)
        XCTAssertTrue(report.contains("all 10 cases pass"), "Empty buckets should report all pass")
    }

    func testReport_WithFailures_ListsStagesAndQueries() {
        let buckets: [PipelineStage: [String]] = [
            .staticRules: ["had a wrap", "ate sushi"],
            .normalization: ["emoji-only input"]
        ]
        let report = GoldSetStageAttribution.report(buckets: buckets, total: 20)
        XCTAssertTrue(report.contains("staticRules"), "Report must list staticRules stage")
        XCTAssertTrue(report.contains("normalization"), "Report must list normalization stage")
        XCTAssertTrue(report.contains("had a wrap"), "Report must include failing query")
        XCTAssertTrue(report.contains("3/20"), "Report must show total failure count")
    }
}
