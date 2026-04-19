import Foundation
import Testing
@testable import Drift

@Suite("AIToolAgent stage labels")
struct AIToolAgentStageTests {

    // MARK: - toolLookupMessage

    @Test func lookupMessage_foodInfo_usesParamName() {
        let call = ToolCall(tool: "food_info", params: ToolCallParams(values: ["name": "banana"]))
        #expect(AIToolAgent.toolLookupMessage(for: call, query: "nutrition in banana") == "Looking up banana...")
    }

    @Test func lookupMessage_foodInfo_fallsBackToQuery() {
        let call = ToolCall(tool: "food_info", params: ToolCallParams(values: [:]))
        let msg = AIToolAgent.toolLookupMessage(for: call, query: "calories in chicken")
        #expect(msg.hasPrefix("Looking up"))
    }

    @Test func lookupMessage_weightInfo() {
        let call = ToolCall(tool: "weight_info", params: ToolCallParams(values: [:]))
        #expect(AIToolAgent.toolLookupMessage(for: call, query: "weight trend") == "Looking up your weight...")
    }

    @Test func lookupMessage_sleepRecovery() {
        let call = ToolCall(tool: "sleep_recovery", params: ToolCallParams(values: [:]))
        #expect(AIToolAgent.toolLookupMessage(for: call, query: "how did I sleep") == "Looking up your sleep...")
    }

    @Test func lookupMessage_unknown_returnsGeneric() {
        let call = ToolCall(tool: "unknown_tool", params: ToolCallParams(values: [:]))
        #expect(AIToolAgent.toolLookupMessage(for: call, query: "something") == "Looking that up...")
    }

    // MARK: - toolFoundMessage

    @Test func foundMessage_foodInfo() {
        #expect(AIToolAgent.toolFoundMessage(for: "food_info") == "Finding macros...")
    }

    @Test func foundMessage_weightInfo() {
        #expect(AIToolAgent.toolFoundMessage(for: "weight_info") == "Reading your trends...")
    }

    @Test func foundMessage_sleepRecovery() {
        #expect(AIToolAgent.toolFoundMessage(for: "sleep_recovery") == "Checking your recovery...")
    }

    @Test func foundMessage_unknown_returnsGeneric() {
        #expect(AIToolAgent.toolFoundMessage(for: "unknown_tool") == "Putting it together...")
    }

    // MARK: - Stage sequence contract

    @Test func stagesAreDistinct_foodInfo() {
        let call = ToolCall(tool: "food_info", params: ToolCallParams(values: ["name": "oats"]))
        let stage1 = AIToolAgent.toolLookupMessage(for: call, query: "nutrition in oats")
        let stage2 = AIToolAgent.toolFoundMessage(for: "food_info")
        #expect(stage1 != stage2, "Lookup and found messages must be distinct so UI shows a visible transition")
    }
}
