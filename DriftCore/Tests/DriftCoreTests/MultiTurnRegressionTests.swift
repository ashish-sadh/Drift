import XCTest
@testable import DriftCore

/// Tier 0 — pure logic, no LLM, no simulator.
/// Regression coverage for hydration routing and multi-turn correction chains. #416.
///
/// Run: `cd DriftCore && swift test --filter MultiTurnRegressionTests`
final class MultiTurnRegressionTests: XCTestCase {

    // MARK: - Hydration routing

    func testWaterLog_ParsesAsFood() {
        let json = #"{"tool":"log_food","name":"water","servings":"2","confidence":"high"}"#
        let intent = IntentClassifier.parseResponse(json)
        XCTAssertEqual(intent?.tool, "log_food")
        XCTAssertEqual(intent?.params["name"], "water")
        XCTAssertEqual(intent?.params["servings"], "2")
    }

    func testWaterLog_MediumConfidenceWithName_Proceeds() {
        // Water has a name — food domain must not over-clarify at medium confidence.
        // Regression: food "had biryani" clarifying when extractor emits medium.
        let decision = IntentThresholds.shouldClarify(
            tool: "log_food", confidence: "medium", hasCompleteParams: true)
        XCTAssertEqual(decision, .proceed)
    }

    func testWaterCorrection_InlineSuffix_ExtractsQuantity() {
        // "add 750ml" — ml is glued to the number, no space → single token.
        // Regression: volume corrections being dropped when user types "750ml" inline.
        XCTAssertEqual(IntentContextResolver.extractAddQuantity("add 750ml"), "750ml")
    }

    func testWaterCorrection_AfterFoodLog_ResolvesToEditMeal() {
        // After logging water, "add 750ml" should correct the entry via edit_meal,
        // not ask for clarification. Regression: context-less routing ignoring lastTool.
        let result = IntentContextResolver.resolve(
            message: "add 750ml",
            phase: .idle,
            lastTool: "log_food",
            lastTopic: .food
        )
        guard case .resolved(let tool, let params) = result else {
            XCTFail("Expected .resolved for 'add 750ml' after water log, got .pass")
            return
        }
        XCTAssertEqual(tool, "edit_meal")
        XCTAssertEqual(params["new_value"], "750ml")
        XCTAssertEqual(params["action"], "update_quantity")
    }

    // MARK: - Multi-turn correction chains

    func testNeedsRecentEntries_HydrationCorrectionPhrases() {
        // "actually i had" and "no i had" trigger recent-entries context injection
        // so water corrections can reference the entry by position.
        XCTAssertTrue(IntentClassifier.needsRecentEntries("actually i had 750ml"))
        XCTAssertTrue(IntentClassifier.needsRecentEntries("no i had 500ml not 250"))
        XCTAssertFalse(IntentClassifier.needsRecentEntries("log 500ml water"),
            "A fresh log should not inject recent entries context")
    }

    func testFoodCorrection_LowConfidenceCompleteParams_Proceeds() {
        // edit_meal is a food-domain tool. Low confidence + complete params must proceed —
        // the user named what to change and said how, so clarifying adds no value.
        let decision = IntentThresholds.shouldClarify(
            tool: "edit_meal", confidence: "low", hasCompleteParams: true)
        XCTAssertEqual(decision, .proceed)
    }

    func testCorrectionChain_HistoryPrependedInComposedMessage() {
        // Correction turns rely on the previous tool call appearing in "Chat:" history
        // so the model can resolve "actually 3" → edit_meal on the prior food entry.
        let composed = IntentClassifier.buildUserMessage(
            message: "actually 3 servings",
            history: "User: log 2 eggs\nAssistant: [log_food]"
        )
        XCTAssertTrue(composed.contains("Chat:"), "History must appear under Chat: prefix")
        XCTAssertTrue(composed.contains("log 2 eggs"), "Prior turn must be in context")
        XCTAssertTrue(composed.contains("actually 3 servings"), "Current message must be present")
    }

    func testAddGlasses_NotKnownVolumeUnit_ReturnsNil() {
        // "add 2 glasses" — "glasses" is not in the unit suffix list, so this must
        // fall through to a normal food-log path rather than routing as edit_meal.
        // Regression: unmapped units mis-routed as bare-quantity edits.
        XCTAssertNil(IntentContextResolver.extractAddQuantity("add 2 glasses"),
            "'glasses' is not a recognised unit — should fall through to food log")
    }
}
