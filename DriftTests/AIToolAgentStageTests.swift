import Foundation
import Testing
@testable import Drift

// MARK: - AIToolAgent stage label helpers

@Test @MainActor func toolLookupMessage_foodInfo_usesParamName() {
    let call = ToolCall(tool: "food_info", params: ToolCallParams(values: ["name": "banana"]))
    #expect(AIToolAgent.toolLookupMessage(for: call, query: "nutrition in banana") == "Looking up banana...")
}

@Test @MainActor func toolLookupMessage_foodInfo_fallsBackToQuery() {
    let call = ToolCall(tool: "food_info", params: ToolCallParams(values: [:]))
    let msg = AIToolAgent.toolLookupMessage(for: call, query: "calories in chicken")
    #expect(msg.hasPrefix("Looking up"))
}

@Test @MainActor func toolLookupMessage_weightInfo_returnsWeightLabel() {
    let call = ToolCall(tool: "weight_info", params: ToolCallParams(values: [:]))
    #expect(AIToolAgent.toolLookupMessage(for: call, query: "weight trend") == "Looking up your weight...")
}

@Test @MainActor func toolLookupMessage_sleepRecovery_returnsSleepLabel() {
    let call = ToolCall(tool: "sleep_recovery", params: ToolCallParams(values: [:]))
    #expect(AIToolAgent.toolLookupMessage(for: call, query: "how did I sleep") == "Looking up your sleep...")
}

@Test @MainActor func toolLookupMessage_unknown_returnsGeneric() {
    let call = ToolCall(tool: "unknown_tool", params: ToolCallParams(values: [:]))
    #expect(AIToolAgent.toolLookupMessage(for: call, query: "something") == "Looking that up...")
}

@Test @MainActor func toolFoundMessage_foodInfo_returnsMacrosLabel() {
    #expect(AIToolAgent.toolFoundMessage(for: "food_info") == "Finding macros...")
}

@Test @MainActor func toolFoundMessage_weightInfo_returnsTrendsLabel() {
    #expect(AIToolAgent.toolFoundMessage(for: "weight_info") == "Reading your trends...")
}

@Test @MainActor func toolFoundMessage_sleepRecovery_returnsRecoveryLabel() {
    #expect(AIToolAgent.toolFoundMessage(for: "sleep_recovery") == "Checking your recovery...")
}

@Test @MainActor func toolFoundMessage_unknown_returnsGeneric() {
    #expect(AIToolAgent.toolFoundMessage(for: "unknown_tool") == "Putting it together...")
}

@Test @MainActor func stageLabels_foodInfo_areDistinct() {
    let call = ToolCall(tool: "food_info", params: ToolCallParams(values: ["name": "oats"]))
    let stage1 = AIToolAgent.toolLookupMessage(for: call, query: "nutrition in oats")
    let stage2 = AIToolAgent.toolFoundMessage(for: "food_info")
    #expect(stage1 != stage2, "Lookup and found messages must differ for visible UI transition")
}
