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

    // MARK: - GLP-1 and medication correction chains (#598)

    func testOzempicDateCorrection_ActuallyTriggers_RecentEntries() {
        // Turn 1: "I took Ozempic" — fresh log, no correction cue.
        // Turn 2: "actually I took it yesterday" — date correction, must inject recent entries.
        XCTAssertFalse(IntentClassifier.needsRecentEntries("I took Ozempic"),
            "Fresh medication log must not inject recent entries")
        XCTAssertTrue(IntentClassifier.needsRecentEntries("actually I took it yesterday"),
            "Date correction cue 'actually' must trigger recent-entries injection")
    }

    func testMetforminFrequencyQuery_NoRecentEntriesNeeded() {
        // Turn 1: "log metformin 500mg" (mark_supplement)
        // Turn 2: "how many times did I take metformin this week?" — query, not correction.
        // The query must not trigger recent-entries injection (no edit/delete cues).
        XCTAssertFalse(IntentClassifier.needsRecentEntries("how many times did I take metformin this week?"),
            "Frequency query has no correction cues — must not inject recent entries")
    }

    func testMetforminHistory_FrequencyQuery_HistoryIncludesPriorLog() {
        // After logging metformin, the composed message for the follow-up query
        // must contain the prior mark_supplement turn for the model to have context.
        let composed = IntentClassifier.buildUserMessage(
            message: "how many times did I take metformin this week?",
            history: "User: log metformin 500mg\nAssistant: [mark_supplement]"
        )
        XCTAssertTrue(composed.contains("Chat:"), "Prior turn must appear under Chat: prefix")
        XCTAssertTrue(composed.contains("log metformin 500mg"), "Prior medication log must be in context")
    }

    @MainActor func testGLP1Shot_ClassifiesAsSupplement() {
        // "I took my glp1 shot" must route to .supplements domain — not food or unknown.
        let topic = ConversationState.shared.classifyTopic("I took my glp1 shot")
        XCTAssertEqual(topic, .supplements, "GLP-1 shot log must classify as supplements via 'took my' phrase")
    }

    func testGLP1LastDose_Query_DoesNotTriggerRecentEntries() {
        // "when did I last take it?" — a query after a supplement mark.
        // There is no correction cue — must not inject recent entries.
        XCTAssertFalse(IntentClassifier.needsRecentEntries("when did I last take it?"),
            "A supplement history query has no correction cues")
    }

    func testOzempicDoseCorrection_ChangeThat_TriggersRecentEntries() {
        // Turn 1: "log ozempic 0.5mg" → mark_supplement
        // Turn 2: "change that to 1mg" — dose correction must inject recent entries.
        XCTAssertTrue(IntentClassifier.needsRecentEntries("change that to 1mg"),
            "'change' is an edit trigger — must inject recent entries for dose correction")
    }

    func testOzempicDoseCorrection_ParsesCorrectJSON() {
        // The corrected dose response JSON must parse cleanly.
        let json = #"{"tool":"mark_supplement","name":"ozempic","dose":"1mg","confidence":"high"}"#
        let intent = IntentClassifier.parseResponse(json)
        XCTAssertEqual(intent?.tool, "mark_supplement")
        XCTAssertEqual(intent?.params["name"], "ozempic")
        XCTAssertEqual(intent?.params["dose"], "1mg")
    }

    func testMorningMeds_Ambiguous_LowIncomplete_Clarifies() {
        // "took my morning meds" — mark_supplement, low confidence, name unknown (incomplete).
        // IntentThresholds must route to clarify so user can name the medication.
        let decision = IntentThresholds.shouldClarify(
            tool: "mark_supplement", confidence: "low", hasCompleteParams: false)
        XCTAssertEqual(decision, .clarify,
            "Ambiguous medication log with low confidence + incomplete params must clarify")
    }

    func testMorningMeds_HighConfidence_Proceeds() {
        // High-confidence mark_supplement (name known) must always proceed.
        let decision = IntentThresholds.shouldClarify(
            tool: "mark_supplement", confidence: "high", hasCompleteParams: false)
        XCTAssertEqual(decision, .proceed,
            "High confidence mark_supplement must proceed regardless of param completeness")
    }

    func testMetforminThenBreakfast_MultiIntent_HistoryPreserved() {
        // Turn 1: "log metformin" → mark_supplement
        // Turn 2: "also log breakfast" — food log in same session.
        // The composed message for turn 2 must include the prior medication log.
        let composed = IntentClassifier.buildUserMessage(
            message: "also log breakfast",
            history: "User: log metformin\nAssistant: [mark_supplement]"
        )
        XCTAssertTrue(composed.contains("log metformin"),
            "Prior medication turn must be in context for multi-intent session")
        XCTAssertTrue(composed.contains("also log breakfast"),
            "Current food-log request must be present in the composed message")
    }

    @MainActor func testCreatineAndOzempic_ClassifiesAsSupplement() {
        // Combined supplement + medication intake must route to .supplements domain.
        let topic = ConversationState.shared.classifyTopic("I took creatine and ozempic")
        XCTAssertEqual(topic, .supplements,
            "'took' with supplement names must classify as supplements")
    }

    func testCreatineAndOzempic_ParsedAsMarkSupplement() {
        // Ensure a combined supplement+medication JSON parses to mark_supplement.
        let json = #"{"tool":"mark_supplement","name":"creatine, ozempic","confidence":"high"}"#
        let intent = IntentClassifier.parseResponse(json)
        XCTAssertEqual(intent?.tool, "mark_supplement")
        XCTAssertNotNil(intent?.params["name"])
    }

    @MainActor func testMedicationToNutritionTopicSwitch_HistoryPreservesBothTurns() {
        // Turn 1: "log medication: semaglutide" → mark_supplement
        // Turn 2: nutrition query "how many calories did I eat today?"
        // History builder must include both turns so the model has full session context.
        let turns = [
            HistoryTurn(role: .user, text: "log medication: semaglutide"),
            HistoryTurn(role: .assistant, text: "Logged semaglutide."),
            HistoryTurn(role: .user, text: "how many calories did I eat today?"),
            HistoryTurn(role: .assistant, text: "You've eaten 1,200 kcal today.")
        ]
        let history = ConversationHistoryBuilder.build(turns: turns, maxTokens: 800)
        XCTAssertTrue(history.contains("semaglutide"),
            "Medication log from turn 1 must be in history for topic-switch session")
        XCTAssertTrue(history.contains("calories"),
            "Nutrition query from turn 3 must be in history")
    }

    func testNutritionQueryAfterMedicationLog_NoRecentEntriesInjected() {
        // After logging a medication, switching to a nutrition query must not
        // inject recent entries — "calories" is not an edit/delete trigger.
        XCTAssertFalse(IntentClassifier.needsRecentEntries("how many calories did I eat today?"),
            "Topic-switch nutrition query must not inject recent entries from prior medication log")
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
