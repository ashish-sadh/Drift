import Foundation
@testable import DriftCore
import Testing
@testable import Drift

// MARK: - DriftApp launch wiring

// Regression cover for the bug where the iOS app launched with an empty
// ToolRegistry and every chat tool call returned "unknown tool: food_info"
// because `ToolRegistration.registerAll()` had been moved out of
// `LocalAIService.init()` (commit 96e3173) without adding the caller wiring
// in `DriftApp.init()`. Tests here pin that wiring so future code-moves
// can't silently re-introduce the same gap.

@Test @MainActor func driftAppInit_registersAITools() async throws {
    // Tear down — clear any tools left by other tests so we observe what
    // DriftApp.init() actually registers, not state from a sibling test.
    let priorTools = ToolRegistry.shared.allTools().map(\.name)
    for name in priorTools { ToolRegistry.shared.unregister(name: name) }
    #expect(ToolRegistry.shared.allTools().isEmpty)

    // Trigger DriftApp.init() — this is the path that runs at app launch.
    _ = DriftApp()

    // Spot-check the canonical tools that the IntentClassifier prompts for.
    // If any of these go missing, the chat will surface "unknown tool" again.
    let registered = Set(ToolRegistry.shared.allTools().map(\.name))
    let mustHave: [String] = [
        "log_food", "food_info", "copy_yesterday", "delete_food",
        "edit_meal", "explain_calories",
        "log_weight", "weight_info", "set_goal",
        "start_workout", "exercise_info", "log_activity",
        "sleep_recovery", "supplements", "mark_supplement", "add_supplement",
        "glucose", "biomarkers", "body_comp", "log_body_comp",
        "navigate_to",
    ]
    for tool in mustHave {
        #expect(registered.contains(tool), "DriftApp.init() must register tool: \(tool)")
    }
}

@Test @MainActor func driftAppInit_routesFoodInfoQueryWithoutUnknownToolError() async throws {
    // End-to-end smoke: after DriftApp init, dispatching a `food_info` call
    // must NOT come back as the "unknown tool" friendly error. This is the
    // exact symptom the user reported.
    let priorTools = ToolRegistry.shared.allTools().map(\.name)
    for name in priorTools { ToolRegistry.shared.unregister(name: name) }
    _ = DriftApp()

    let call = ToolCall(tool: "food_info", params: ToolCallParams(values: ["query": "protein"]))
    let result = await AIToolAgent.executeTool(call)

    #expect(!result.didFail || !(result.text.contains("unknown tool")),
            "food_info dispatched after DriftApp init should not return 'unknown tool'")
}
