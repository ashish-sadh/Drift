import Foundation

/// Minimal chat turn shape the history builder needs. iOS Drift's
/// `AIChatViewModel.ChatMessage` maps to this at the call boundary.
public struct HistoryTurn: Sendable {
    public enum Role: Sendable { case user, assistant }
    public let role: Role
    public let text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

/// Serializes recent chat turns into a token-budgeted "Q: … / A: …" string
/// that AIToolAgent injects into Stage 2 (IntentClassifier), Stage 3
/// (presentation), and Stage 5 (ToolRanker.buildPrompt).
public enum ConversationHistoryBuilder {

    /// Approximate chars-per-token ratio for Gemma/SmolLM tokenizers.
    public static let charsPerToken = 4

    /// Per-message cap — keeps a single verbose assistant answer from
    /// consuming the whole budget. 60 tokens ≈ 240 chars.
    public static let perMessageTokens = 60

    /// How many trailing turns to consider.
    public static let maxTurnWindow = 6

    /// Chars reserved for the `[LAST ACTION: …]` prefix.
    public static let lastActionTokens = 100

    /// Build a Q/A formatted history string within `maxTokens`.
    /// When `ConversationState` has a fresh tool summary, prepends
    /// `[LAST ACTION: …]` so follow-ups have the concrete data.
    @MainActor
    public static func build(
        turns: [HistoryTurn],
        maxTokens: Int = 400
    ) -> String {
        guard Preferences.conversationHistoryEnabled, !turns.isEmpty else { return "" }

        let perMsgChars = perMessageTokens * charsPerToken
        let window = turns.suffix(maxTurnWindow)

        let toolLine: String? = {
            guard let summary = ConversationState.shared.freshToolSummary() else { return nil }
            let cap = lastActionTokens * charsPerToken
            let flattened = summary.replacingOccurrences(of: "\n", with: " ")
            return "[LAST ACTION: \(String(flattened.prefix(cap)))]"
        }()

        let toolReserve = toolLine.map { $0.count + 1 } ?? 0
        let qaBudgetChars = max(0, maxTokens * charsPerToken - toolReserve)

        var lines: [String] = []
        var used = 0
        for msg in window.reversed() {
            let prefix = msg.role == .user ? "Q" : "A"
            let truncated = String(msg.text.prefix(perMsgChars))
            let line = "\(prefix): \(truncated)"
            // +1 accounts for the joining newline between lines.
            if used + line.count + (lines.isEmpty ? 0 : 1) > qaBudgetChars { break }
            lines.insert(line, at: 0)
            used += line.count + (lines.count > 1 ? 1 : 0)
        }
        if let toolLine { lines.insert(toolLine, at: 0) }
        return lines.joined(separator: "\n")
    }
}
