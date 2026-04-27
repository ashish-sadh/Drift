import Foundation

/// Context-aware tie-break for ambiguous intent classification.
/// Called before the pre-classifier clarifier and after IntentThresholds
/// returns `.clarify`, to resolve cases where conversation state makes
/// the right tool unambiguous without asking the user. #449.
///
/// Pure (nonisolated) — takes already-read ConversationState values so
/// tests can exercise it without a running @MainActor singleton.
public enum IntentContextResolver {

    public enum Resolution: Equatable {
        case resolved(tool: String, params: [String: String])
        case pass
    }

    /// Try to resolve the message using conversation context.
    /// Returns `.resolved` when context makes the tool unambiguous,
    /// `.pass` otherwise (caller should fall through to clarification UI).
    public static func resolve(
        message: String,
        phase: ConversationState.Phase,
        lastTool: String?,
        lastTopic: ConversationState.Topic
    ) -> Resolution {
        let lower = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return .pass }

        // "add N[unit]" — bare quantity command, highly context-dependent
        if let qty = extractAddQuantity(lower) {
            switch phase {
            case .awaitingMealItems(let mealName):
                // In meal-building phase, "add 50" means edit the meal being
                // constructed — not a new food log. The food name is unknown,
                // so we pass mealName as the period anchor for the tool.
                return .resolved(tool: "edit_meal", params: [
                    "meal_period": mealName,
                    "action": "update_quantity",
                    "new_value": qty
                ])
            case .idle:
                // Just logged food + "add N" → edit that entry (add quantity)
                if lastTool == "log_food" {
                    return .resolved(tool: "edit_meal", params: [
                        "action": "update_quantity",
                        "new_value": qty
                    ])
                }
            default:
                break
            }
        }

        // awaitingExercises phase: any non-question input is an exercise list
        if phase == .awaitingExercises, !isQuestionCue(lower) {
            return .resolved(tool: "log_activity", params: ["name": lower])
        }

        return .pass
    }

    // MARK: - Quantity Extraction

    /// Extract the quantity from "add N" / "add Ng" / "add N cal" patterns.
    /// Returns the raw quantity string ("50", "50g", "50cal") or nil when
    /// the pattern doesn't match (e.g. "add eggs" — food log, not edit).
    static func extractAddQuantity(_ lower: String) -> String? {
        guard lower.hasPrefix("add ") || lower.hasPrefix("plus ") else { return nil }
        let rest: String
        if lower.hasPrefix("add ") {
            rest = String(lower.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        } else {
            rest = String(lower.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        }
        // Must start with a digit
        guard let first = rest.first, first.isNumber else { return nil }

        // Split into tokens; if there are 2 tokens the second must be a known
        // unit — otherwise it's a food name ("add 50 eggs") and this is a log,
        // not an edit.
        let tokens = rest.split(separator: " ", maxSplits: 1).map(String.init)
        let quantityToken = tokens[0]
        let unitSuffixes: Set<String> = [
            "g", "kg", "lb", "lbs", "cal", "kcal", "mg", "oz",
            "gram", "grams", "calorie", "calories"
        ]
        if tokens.count == 2 {
            let second = tokens[1]
            if !unitSuffixes.contains(second) { return nil } // "add 50 eggs" → food log
            return quantityToken + second
        }
        // Single token — accept digits with optional inline unit ("50g", "50cal")
        return quantityToken
    }

    // MARK: - Helpers

    private static func isQuestionCue(_ lower: String) -> Bool {
        lower.contains("?") || lower.hasPrefix("how") || lower.hasPrefix("what")
            || lower.hasPrefix("when") || lower.hasPrefix("did")
    }
}
