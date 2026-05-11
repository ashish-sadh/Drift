import Foundation
@testable import DriftCore
import Testing

/// Tier-0 deterministic chat-path smoke. Asserts that recently shipped
/// analytical / coaching tools are reachable end-to-end from the chat surface
/// without invoking a real LLM. Each case fails if the corresponding tool /
/// router rule / splitter is removed (regression value confirmed).
///
/// Scope (mirrors the example queries from the cycle-9760 review):
///   - `food_timing_insight` (#690 smart-meal-reminder timing source) —
///     "when do I usually eat lunch"
///   - `cycle_biomarker_correlation` (#689 cycle × biomarker) —
///     "how does my cycle affect my iron"
///   - `MultiIntentSplitter` (#688 compound-query split) —
///     "log lunch and update weight"
///
/// Out of scope: iOS-bound chat flows (photo-log, edit-meal, navigation
/// HealthKit reads). Those need `@testable import Drift` and live with #655's
/// iOS Tier-1 file when that lands.

// MARK: - food_timing_insight: "when do I usually eat lunch"

@Test @MainActor func chatSmoke_foodTimingInsight_isRegistered() {
    // ToolRegistry is a singleton shared across tests. Other tests that
    // register a single tool via syncRegistration leave `allTools()`
    // non-empty but missing the chat-path tools, so we can't rely on the
    // "if empty then register" pattern. registerAll is idempotent —
    // safer to always call it from the smoke path.
    ToolRegistration.registerAll()
    let tool = ToolRegistry.shared.tool(named: FoodTimingInsightTool.toolName)
    #expect(tool != nil,
            "food_timing_insight must be registered for the chat path to reach it")
    #expect(tool?.service == "insights")
}

@Test func chatSmoke_foodTimingInsight_routerPromptCarriesExample() {
    let prompt = IntentClassifier.routerPrompt
    #expect(prompt.contains("food_timing_insight"),
            "router prompt must declare the food_timing_insight tool")
    #expect(prompt.contains(#""tool":"food_timing_insight""#),
            "router prompt must show a routing example so the LLM produces matching JSON")
}

@Test func chatSmoke_foodTimingInsight_jsonResponseParses() {
    let json = #"{"tool":"food_timing_insight","window_days":"14"}"#
    let intent = IntentClassifier.parseResponse(json)
    #expect(intent?.tool == "food_timing_insight")
    #expect(intent?.params["window_days"] == "14")
}

@Test @MainActor func chatSmoke_foodTimingInsight_handlerProducesCard() async {
    // ToolRegistry is a singleton shared across tests. Other tests that
    // register a single tool via syncRegistration leave `allTools()`
    // non-empty but missing the chat-path tools, so we can't rely on the
    // "if empty then register" pattern. registerAll is idempotent —
    // safer to always call it from the smoke path.
    ToolRegistration.registerAll()
    let call = ToolCall(
        tool: FoodTimingInsightTool.toolName,
        params: ToolCallParams(values: ["window_days": "14"])
    )
    let result = await ToolRegistry.shared.execute(call)
    if case .text(let s) = result {
        #expect(!s.isEmpty,
                "food_timing_insight must return a non-empty card; got empty string")
    } else {
        Issue.record("expected .text result from food_timing_insight, got \(result)")
    }
}

// MARK: - cycle_biomarker_correlation: "how does my cycle affect my iron"

@Test @MainActor func chatSmoke_cycleBiomarker_isRegistered() {
    // ToolRegistry is a singleton shared across tests. Other tests that
    // register a single tool via syncRegistration leave `allTools()`
    // non-empty but missing the chat-path tools, so we can't rely on the
    // "if empty then register" pattern. registerAll is idempotent —
    // safer to always call it from the smoke path.
    ToolRegistration.registerAll()
    let tool = ToolRegistry.shared.tool(named: CycleBiomarkerInsightTool.toolName)
    #expect(tool != nil,
            "cycle_biomarker_correlation must be registered for the chat path to reach it")
    #expect(tool?.service == "insights")
    #expect(tool?.parameters.contains(where: { $0.name == "biomarker" && !$0.required }) == true)
}

@Test func chatSmoke_cycleBiomarker_routerPromptCarriesExample() {
    let prompt = IntentClassifier.routerPrompt
    #expect(prompt.contains("cycle_biomarker_correlation"),
            "router prompt must declare the cycle_biomarker_correlation tool")
    #expect(prompt.contains(#""tool":"cycle_biomarker_correlation""#),
            "router prompt must show a routing example so the LLM produces matching JSON")
}

@Test func chatSmoke_cycleBiomarker_jsonResponseParses() {
    let json = #"{"tool":"cycle_biomarker_correlation","biomarker":"iron"}"#
    let intent = IntentClassifier.parseResponse(json)
    #expect(intent?.tool == "cycle_biomarker_correlation")
    #expect(intent?.params["biomarker"] == "iron")
}

@Test @MainActor func chatSmoke_cycleBiomarker_handlerRunsWithoutCrash() async {
    // ToolRegistry is a singleton shared across tests. Other tests that
    // register a single tool via syncRegistration leave `allTools()`
    // non-empty but missing the chat-path tools, so we can't rely on the
    // "if empty then register" pattern. registerAll is idempotent —
    // safer to always call it from the smoke path.
    ToolRegistration.registerAll()
    // Test environment has no HealthKit + no lab reports → tool surfaces a friendly
    // text degradation, never crashes. Asserts the chat path completes even
    // when the data isn't there.
    let call = ToolCall(
        tool: CycleBiomarkerInsightTool.toolName,
        params: ToolCallParams(values: ["biomarker": "iron"])
    )
    let result = await ToolRegistry.shared.execute(call)
    if case .text(let s) = result {
        #expect(!s.isEmpty)
    } else {
        Issue.record("expected .text result from cycle_biomarker_correlation, got \(result)")
    }
}

// MARK: - MultiIntentSplitter: "log lunch and update weight"

@Test func chatSmoke_multiIntent_splitsLogLunchAndWeight() {
    let parts = MultiIntentSplitter.split("log lunch and update weight")
    #expect(parts?.count == 2,
            "compound food + weight query must split into two segments; got \(parts ?? [])")
    #expect(parts?[0] == "log lunch")
    #expect(parts?[1] == "update weight")
}

@Test func chatSmoke_multiIntent_doesNotSplitSameDomainFoods() {
    // Regression guard: "I had chicken and rice" must NOT split — rice has no
    // domain signal so MultiIntentSplitter returns nil. Without this guard,
    // accidental relaxation of the domain rules would silently double-route
    // food queries through two LLM calls.
    let parts = MultiIntentSplitter.split("I had chicken and rice")
    #expect(parts == nil, "single-domain food multi-item must not split; got \(parts ?? [])")
}
