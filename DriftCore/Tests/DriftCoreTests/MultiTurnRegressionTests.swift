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

    // MARK: - Long-context multi-turn chains (6+ turns, #315 6144 context window)

    @MainActor func testHistoryBuilder_800TokenBudget_IncludesMoreTurns() {
        // With 6144 context window, history budget raised 400→800 tokens.
        // A 6-turn conversation at ~60 tokens/msg must all fit in the new budget.
        let turns = (1...6).flatMap { i -> [HistoryTurn] in [
            HistoryTurn(role: .user, text: "log \(i) eggs for breakfast"),
            HistoryTurn(role: .assistant, text: "Logged \(i) eggs — 78 kcal each.")
        ]}
        let history = ConversationHistoryBuilder.build(turns: turns, maxTokens: 800)
        XCTAssertTrue(history.contains("log 1 eggs"), "Oldest turn should be preserved within 800-token budget")
        XCTAssertTrue(history.contains("log 6 eggs"), "Newest turn must be present")
    }

    @MainActor func testHistoryBuilder_TurnWindow_AllowsTenTurns() {
        // maxTurnWindow raised 6→10 so 10-turn conversations fit without truncation.
        let turns = (1...10).flatMap { i -> [HistoryTurn] in [
            HistoryTurn(role: .user, text: "step \(i)"),
            HistoryTurn(role: .assistant, text: "ok \(i)")
        ]}
        // The window limit is 10 turns (20 messages), so all 10 rounds should be considered.
        let history = ConversationHistoryBuilder.build(turns: turns, maxTokens: 2000)
        XCTAssertTrue(history.contains("step 1"), "All 10 turns should be within the window")
        XCTAssertTrue(history.contains("step 10"), "Latest turn must be present")
    }

    @MainActor func testHistoryBuilder_EleventhTurn_DroppedByWindow() {
        // Turns beyond maxTurnWindow (10) must be dropped — oldest falls off.
        let turns = (1...11).flatMap { i -> [HistoryTurn] in [
            HistoryTurn(role: .user, text: "msg\(i)"),
            HistoryTurn(role: .assistant, text: "ack\(i)")
        ]}
        let history = ConversationHistoryBuilder.build(turns: turns, maxTokens: 5000)
        XCTAssertFalse(history.contains("msg1"), "11th-oldest turn should be outside the 10-turn window")
        XCTAssertTrue(history.contains("msg11"), "Most recent turn must always be present")
    }

    @MainActor func testHistoryBuilder_LongChain_PerMessageCapEnforced() {
        // Verbose assistant responses must not crowd out other turns.
        // Each message is capped at perMessageTokens (60 tokens ≈ 240 chars).
        let verboseReply = String(repeating: "word ", count: 200) // ~1000 chars, well over cap
        let turns = [
            HistoryTurn(role: .user, text: "log 2 eggs"),
            HistoryTurn(role: .assistant, text: verboseReply),
            HistoryTurn(role: .user, text: "log 1 banana"),
            HistoryTurn(role: .assistant, text: "Logged banana — 89 kcal.")
        ]
        let history = ConversationHistoryBuilder.build(turns: turns, maxTokens: 800)
        let verboseTruncated = verboseReply.prefix(ConversationHistoryBuilder.perMessageTokens * ConversationHistoryBuilder.charsPerToken)
        XCTAssertTrue(history.contains(String(verboseTruncated.prefix(20))),
            "Verbose reply should be included but truncated")
        XCTAssertTrue(history.contains("log 1 banana"),
            "Later turns must not be crowded out by the verbose reply")
    }

    @MainActor func testHistoryBuilder_SixTurnChain_EntryRefPreserved() {
        // In a 6-turn chain the user references a food from turn 1 at turn 6.
        // The history string must include the original log so the model can resolve it.
        let turns = [
            HistoryTurn(role: .user, text: "log 2 idli"),
            HistoryTurn(role: .assistant, text: "Logged 2 idli — 58 kcal each."),
            HistoryTurn(role: .user, text: "log dal fry"),
            HistoryTurn(role: .assistant, text: "Logged dal fry — 150 kcal."),
            HistoryTurn(role: .user, text: "log rice"),
            HistoryTurn(role: .assistant, text: "Logged rice — 200 kcal."),
            HistoryTurn(role: .user, text: "log sabzi"),
            HistoryTurn(role: .assistant, text: "Logged sabzi — 120 kcal."),
            HistoryTurn(role: .user, text: "log raita"),
            HistoryTurn(role: .assistant, text: "Logged raita — 60 kcal."),
            HistoryTurn(role: .user, text: "actually the idli was 3 not 2"),
            HistoryTurn(role: .assistant, text: "Updated to 3 idli.")
        ]
        let history = ConversationHistoryBuilder.build(turns: turns, maxTokens: 800)
        XCTAssertTrue(history.contains("idli"), "Original idli log must be in history for correction context")
    }
}
