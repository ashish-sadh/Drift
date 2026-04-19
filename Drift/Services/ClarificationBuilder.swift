import Foundation

/// One offered alternative when the classifier can't tell between two
/// reasonable intents. Carries the preview shown to the user AND the
/// concrete tool call to execute if picked — the dispatcher never
/// re-classifies on resolution. #226.
struct ClarificationOption: Equatable, Codable, Sendable, Identifiable {
    /// 1-based selection index used in UI chips and numeric responses.
    let id: Int
    /// User-facing label: "Log chicken as food", "Check calories in chicken".
    let label: String
    /// Registered tool to run on pick (e.g. `log_food`, `food_info`).
    let tool: String
    /// Extracted params to hand to the tool as-is.
    let params: [String: String]
}

/// Deterministic option builder — produces 2-3 alternative intents for
/// inputs the classifier can't disambiguate. Pure Swift (no LLM call),
/// so the clarification decision is predictable and testable. Used when
/// either (a) the LLM returned `confidence: "low"` or (b) the message
/// matches a Swift-detected ambiguity pattern. Narrow by design: silence
/// is better than a bad clarifier on clear inputs.
enum ClarificationBuilder {

    /// Returns 2-3 options only when the input is genuinely ambiguous.
    /// Returns nil for clear intents, gibberish, or single-option cases —
    /// callers fall through to normal classification.
    static func buildOptions(for message: String) -> [ClarificationOption]? {
        let lower = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty, lower.count <= 60 else { return nil }

        if let opts = bareFoodNounOptions(lower) { return opts }
        if let opts = bareSupplementOptions(lower) { return opts }
        if let opts = bareWeightValueOptions(lower) { return opts }
        if let opts = ambiguousLogOptions(lower) { return opts }
        return nil
    }

    /// Format options into a "Did you mean: …" prompt. One line per option
    /// with a number — matches how `AIChatViewModel.handleClarification`
    /// parses the user's next turn.
    static func promptText(_ options: [ClarificationOption]) -> String {
        var s = "Did you mean:"
        for opt in options {
            s += "\n\(opt.id). \(opt.label)"
        }
        s += "\n\nReply with a number or tap an option — or \"nevermind\" to skip."
        return s
    }

    // MARK: - Ambiguity classes

    /// "biryani", "chicken" — bare food noun with no verb. Could be log
    /// OR a nutrition lookup. Require (a) known food-like token set match
    /// and (b) no clear action verb to avoid triggering on "log chicken".
    private static func bareFoodNounOptions(_ lower: String) -> [ClarificationOption]? {
        guard !startsWithActionVerb(lower),
              !lower.contains("calories") && !lower.contains("protein")
                && !lower.contains("carbs") && !lower.contains("fat"),
              !containsQuestionCue(lower),
              tokenCount(lower) <= 3,
              looksLikeFoodNoun(lower) else { return nil }
        let display = lower
        return [
            .init(id: 1, label: "Log \(display) as food", tool: "log_food",
                  params: ["name": display]),
            .init(id: 2, label: "Look up calories in \(display)", tool: "food_info",
                  params: ["query": "calories in \(display)"])
        ]
    }

    /// "vitamin d", "creatine" — bare supplement name. Could be mark-as-
    /// taken OR a status question. Only trigger when the token exactly
    /// matches a known supplement stem (no action verb).
    private static func bareSupplementOptions(_ lower: String) -> [ClarificationOption]? {
        guard !startsWithActionVerb(lower),
              !containsQuestionCue(lower),
              tokenCount(lower) <= 3,
              supplementLexicon.contains(where: { lower == $0 || lower.hasPrefix("\($0) ") || lower.hasSuffix(" \($0)") || lower == "\($0)s" }) else {
            return nil
        }
        return [
            .init(id: 1, label: "Mark \(lower) as taken today", tool: "mark_supplement",
                  params: ["name": lower]),
            .init(id: 2, label: "Check if I've taken \(lower)", tool: "supplements",
                  params: ["query": lower])
        ]
    }

    /// Pure numeric input 20-500 — ambiguous: log weight (lbs vs kg) or
    /// set goal. Offer the two most-common reads. Outside this range the
    /// input is almost certainly not a weight, so we bail.
    private static func bareWeightValueOptions(_ lower: String) -> [ClarificationOption]? {
        guard let value = Double(lower), value >= 20, value <= 500 else { return nil }
        let formatted = value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
        return [
            .init(id: 1, label: "Log weight \(formatted) lbs", tool: "log_weight",
                  params: ["value": formatted, "unit": "lbs"]),
            .init(id: 2, label: "Log weight \(formatted) kg", tool: "log_weight",
                  params: ["value": formatted, "unit": "kg"]),
            .init(id: 3, label: "Set goal to \(formatted)", tool: "set_goal",
                  params: ["target": formatted])
        ]
    }

    /// "log X" where X could be food OR activity (e.g. "log running", "log
    /// protein"). Distinguishes from unambiguous "log 2 eggs" by requiring
    /// a single noun after the verb.
    private static func ambiguousLogOptions(_ lower: String) -> [ClarificationOption]? {
        let verbs = ["log ", "track ", "add "]
        guard let verb = verbs.first(where: { lower.hasPrefix($0) }) else { return nil }
        let rest = String(lower.dropFirst(verb.count)).trimmingCharacters(in: .whitespaces)
        guard tokenCount(rest) == 1, !rest.isEmpty else { return nil }
        // Skip if rest is unambiguous (clear food or clear activity) — these
        // are handled by existing rules/classifier without needing a prompt.
        if clearActivityLexicon.contains(rest) { return nil }
        if clearFoodLexicon.contains(rest) { return nil }
        // "log protein" / "log calories" — food-info query, not log.
        if rest == "protein" || rest == "calories" || rest == "carbs" || rest == "fat" {
            return nil
        }
        // Ambiguous single word — offer both reads.
        if ambiguousLogLexicon.contains(rest) {
            return [
                .init(id: 1, label: "Log \(rest) as food", tool: "log_food",
                      params: ["name": rest]),
                .init(id: 2, label: "Log \(rest) as activity", tool: "log_activity",
                      params: ["name": rest])
            ]
        }
        return nil
    }

    // MARK: - Heuristics

    private static func startsWithActionVerb(_ lower: String) -> Bool {
        let verbs = ["log ", "track ", "add ", "ate ", "had ", "i had ", "i ate ",
                     "show ", "check ", "delete ", "remove ", "undo ", "edit ",
                     "update ", "set ", "start ", "begin ", "what ", "how ", "why "]
        return verbs.contains(where: { lower.hasPrefix($0) })
    }

    private static func containsQuestionCue(_ lower: String) -> Bool {
        lower.contains("?") || lower.contains(" vs ") || lower.contains("how much")
            || lower.contains("how many") || lower.contains("is it")
    }

    private static func tokenCount(_ s: String) -> Int {
        s.split(separator: " ").count
    }

    /// Small built-in lexicon of foods that are commonly uttered as bare
    /// nouns (and also as info queries). Intentionally not pulled from the
    /// main food DB — we want *tight* coverage of the ambiguous cases.
    private static let bareFoodLexicon: Set<String> = [
        "biryani", "chicken", "rice", "dal", "pasta", "pizza", "bread", "egg", "eggs",
        "salad", "soup", "curry", "steak", "salmon", "tuna", "yogurt", "cheese",
        "banana", "apple", "orange", "mango", "grapes", "toast", "oatmeal",
        "paneer", "samosa", "roti", "tofu", "sushi", "burrito", "taco",
        "coffee", "tea", "milk", "juice"
    ]

    private static func looksLikeFoodNoun(_ lower: String) -> Bool {
        bareFoodLexicon.contains(lower)
            || bareFoodLexicon.contains(where: { lower.hasSuffix(" \($0)") || lower.hasPrefix("\($0) ") })
    }

    /// Common supplement names that a user might say alone — intake vs
    /// status depends entirely on the prior turn.
    private static let supplementLexicon: Set<String> = [
        "creatine", "vitamin d", "vitamin c", "vitamin b12", "b12", "zinc",
        "magnesium", "iron", "fish oil", "omega 3", "omega-3", "multivitamin",
        "vitamin e", "calcium", "ashwagandha", "probiotics", "collagen"
    ]

    /// Foods that are clearly foods when preceded by "log"/"track"/"add"
    /// — no clarifier needed.
    private static let clearFoodLexicon: Set<String> = [
        "biryani", "pizza", "pasta", "sushi", "burrito", "taco", "salad",
        "samosa", "sandwich", "burger", "roti", "paneer"
    ]

    /// Activities that are clearly activities — no clarifier needed.
    private static let clearActivityLexicon: Set<String> = [
        "run", "running", "walk", "walking", "yoga", "swim", "swimming",
        "cycling", "biking", "squats", "pushups", "lifting", "workout"
    ]

    /// Words that could be either food or activity ("log cardio", "log tea").
    private static let ambiguousLogLexicon: Set<String> = [
        "rowing", "hiking"
    ]
}
