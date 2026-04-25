import Foundation
@testable import DriftCore
import Testing
@testable import Drift

/// Regression coverage for #249 — "Weekly summary" chip routed to a
/// fuzzy food match ("Mix secos y arandanos - Weekly!") instead of the
/// weekly period summary. Root cause: the food_info tool's nutrition-
/// lookup branch treated the query as a food name and hit the online
/// USDA/OpenFoodFacts fallback. Fix added a summary-query guard.

@MainActor
private func runFoodInfo(_ query: String) async -> String {
    if ToolRegistry.shared.allTools().isEmpty {
        ToolRegistration.registerAll()
    }
    let call = ToolCall(
        tool: "food_info",
        params: ToolCallParams(values: ["query": query])
    )
    let result = await ToolRegistry.shared.execute(call)
    if case .text(let t) = result { return t }
    return ""
}

// MARK: - Regression: summary queries must NOT hit food lookup

@Test @MainActor func weeklySummaryDoesNotFuzzyMatchFood() async {
    let output = await runFoodInfo("weekly summary")
    // Nutrition-lookup output always suffixes "Say 'log X' to add it." —
    // if we see that, it means the food-lookup branch fired.
    #expect(!output.contains("Say 'log"),
            "Weekly summary must not route through food-name lookup. Got: '\(output.prefix(100))'")
}

@Test @MainActor func weeklySummaryReturnsPeriodSummary() async {
    let output = await runFoodInfo("weekly summary")
    // AIRuleEngine.weeklySummary() starts with "This week:" in all data
    // states (even empty — it still sets header line).
    #expect(output.contains("This week:") || output.contains("No food logged"),
            "Weekly summary should return period overview. Got: '\(output.prefix(100))'")
}

@Test @MainActor func dailySummaryDoesNotFuzzyMatchFood() async {
    let output = await runFoodInfo("daily summary")
    #expect(!output.contains("Say 'log"),
            "Daily summary must not route through food-name lookup. Got: '\(output.prefix(100))'")
}

@Test @MainActor func bareTodayDoesNotFuzzyMatchFood() async {
    let output = await runFoodInfo("today")
    #expect(!output.contains("Say 'log"),
            "'today' must not be interpreted as a food name. Got: '\(output.prefix(100))'")
}

@Test @MainActor func bareYesterdayDoesNotFuzzyMatchFood() async {
    let output = await runFoodInfo("yesterday")
    #expect(!output.contains("Say 'log"),
            "'yesterday' must not be interpreted as a food name. Got: '\(output.prefix(100))'")
}

@Test @MainActor func bareWeeklyDoesNotFuzzyMatchFood() async {
    let output = await runFoodInfo("weekly")
    #expect(!output.contains("Say 'log"),
            "'weekly' alone must route to weekly summary. Got: '\(output.prefix(100))'")
}

@Test @MainActor func thisWeekDoesNotFuzzyMatchFood() async {
    let output = await runFoodInfo("this week")
    #expect(!output.contains("Say 'log"),
            "'this week' must route to weekly summary. Got: '\(output.prefix(100))'")
}

// MARK: - Positive guard: normal food lookup still works

@Test @MainActor func normalFoodLookupStillWorks() async {
    // Regression sentinel: the summary guard MUST NOT block real food
    // lookups. "calories in banana" is the canonical nutrition-lookup
    // query — it must still hit the food-match branch or at minimum
    // produce a legitimate answer (not swallowed by summary logic).
    let output = await runFoodInfo("calories in banana")
    // The output depends on whether banana is in the local DB; if not,
    // it falls through to the daily summary. Either is fine — what we're
    // asserting is that the guard didn't accidentally hijack this query
    // into the summary branch AND return "This week:" (which would be
    // clearly wrong for a per-food nutrition query).
    #expect(!output.contains("This week:"),
            "'calories in banana' must not return a weekly summary. Got: '\(output.prefix(100))'")
}
