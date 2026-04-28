import Foundation

/// iOS-side IntentClassifier methods that touch ConversationState / LocalAIService.
/// Pure parsing + composition lives in DriftCore (`IntentClassifier` enum).
@MainActor
extension IntentClassifier {

    /// MainActor variant used by the live pipeline. Prepends the recent-entries
    /// block when the message looks like a delete/edit turn AND the window has rows.
    /// `literalHint` is used by the #240 auto-retry path to nudge the extractor.
    static func buildContextualUserMessage(
        message: String, history: String, literalHint: String? = nil
    ) -> String {
        let recentBlock = needsRecentEntries(message)
            ? ConversationState.shared.recentEntriesContextBlock()
            : nil
        return composeUserMessage(
            message: message, history: history,
            recentBlock: recentBlock, literalHint: literalHint
        )
    }

    /// Classify user message into intent + tool call via LLM.
    /// Returns nil only on timeout. Text responses are returned as `.text`.
    /// Picks routerPrompt vs intelligencePrompt based on the active backend
    /// — small model gets the tight prompt, large gets the rich one.
    static func classifyFull(
        message: String, history: String, literalHint: String? = nil
    ) async -> ClassifyResult? {
        let msg = buildContextualUserMessage(
            message: message, history: history, literalHint: literalHint
        )
        let isLarge = await LocalAIService.shared.isLargeModel
        let prompt = activeSystemPrompt(isLargeModel: isLarge)
        let response = await withTimeout(seconds: 10) {
            await LocalAIService.shared.respondDirect(
                systemPrompt: prompt,
                message: msg
            )
        }
        return mapResponse(response)
    }

    /// Legacy: returns nil for text responses (backward compat)
    static func classify(message: String, history: String) async -> ClassifiedIntent? {
        guard let result = await classifyFull(message: message, history: history) else { return nil }
        if case .toolCall(let intent) = result { return intent }
        return nil
    }
}
