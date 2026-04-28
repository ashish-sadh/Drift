import Foundation
@testable import DriftCore
import Testing

// Pin the contract that every tool the IntentClassifier prompts the LLM to
// emit is actually registered in ToolRegistry. The inverse failure mode of
// the empty-registry bug: an empty registry caused every call to return
// "unknown tool"; a *partial* registry would silently work for some tools
// and fail for others (e.g. someone adds a new tool to the prompt but
// forgets to register the schema). Same surface symptom, harder to spot.

@Test @MainActor func intentClassifierPrompt_referencesOnlyRegisteredTools() async throws {
    if ToolRegistry.shared.allTools().isEmpty { ToolRegistration.registerAll() }
    let registered = Set(ToolRegistry.shared.allTools().map(\.name))

    let prompt = IntentClassifier.systemPrompt
    guard let toolsLine = prompt.split(separator: "\n").first(where: { $0.hasPrefix("Tools:") }) else {
        Issue.record("IntentClassifier prompt missing 'Tools:' line")
        return
    }

    // Extract every <name>( occurrence — tool signature is `name(params...)`
    // or `name()` — the open-paren is the reliable terminator.
    let pattern = #"([a-z_]+)\("#
    let regex = try NSRegularExpression(pattern: pattern)
    let range = NSRange(toolsLine.startIndex..., in: toolsLine)
    let matches = regex.matches(in: String(toolsLine), range: range)

    var promptTools: [String] = []
    for match in matches {
        guard let r = Range(match.range(at: 1), in: toolsLine) else { continue }
        promptTools.append(String(toolsLine[r]))
    }
    #expect(!promptTools.isEmpty, "Failed to parse any tool names from the prompt — regex broken or prompt format changed")

    for tool in promptTools {
        #expect(registered.contains(tool),
                "Tool '\(tool)' is in the IntentClassifier prompt but not registered. Either register it in ToolRegistration.registerAll() or remove it from the prompt.")
    }
}
