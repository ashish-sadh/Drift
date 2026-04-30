import Foundation

/// Stage 0.5 pre-pass: detect compound cross-domain queries and split them
/// before any LLM call. Runs after normalization + pronoun resolution so it
/// sees clean input, but before the rule engine and classifier.
///
/// Design constraints:
/// - Pure heuristics, no LLM, no DB.
/// - Only splits when BOTH sides of "and" have a classifiable domain AND the
///   domains are distinct. This prevents "I had chicken and rice" from splitting
///   (rice alone has no domain signal) while catching "I had eggs and logged 70kg".
/// - Large-model only (AIToolAgent guards this call).
public enum MultiIntentSplitter {

    // MARK: - Domain Detection

    /// Classify a phrase into its primary health tracking domain.
    /// Returns nil when no clear domain signal is present — callers use nil
    /// to prevent splitting (missing domain = same-domain fallback).
    public static func domain(of phrase: String) -> String? {
        let s = phrase.lowercased()

        // Weight: explicit weight vocabulary or number+unit pattern.
        // Checked first so "log weight 70kg" routes here, not food.
        let weightWords = ["weigh", "weight", "scale", "kilos"]
        let hasWeightWord = weightWords.contains(where: { s.contains($0) })
        let hasWeightUnit = s.range(
            of: #"\d+\.?\d*\s*(kg|kgs|lb|lbs|pounds|kilos?)\b"#,
            options: .regularExpression
        ) != nil
        if hasWeightWord || hasWeightUnit { return "weight" }

        // Supplement: known supplement item names. Action verbs alone ("mark",
        // "took") without a named item are intentionally excluded to avoid
        // false positives like "I haven't taken it".
        let supplementItems = [
            "creatine", "vitamin", "omega", "zinc", "magnesium",
            "probiotic", "melatonin", "ashwagandha", "fish oil"
        ]
        if supplementItems.contains(where: { s.contains($0) }) {
            return "supplement"
        }

        // Food: eating/drinking action verbs or explicit log/add/track verbs.
        // Bare food nouns ("rice", "chicken") intentionally produce nil so that
        // "I had chicken and rice" is not split.
        let foodVerbs = ["had ", "ate ", "eaten", "drank ", "drink ", "having "]
        let logVerbs = ["log ", "add ", "track "]
        if foodVerbs.contains(where: { s.contains($0) }) ||
           logVerbs.contains(where: { s.contains($0) }) {
            return "food"
        }

        return nil
    }

    // MARK: - Split

    /// Split a compound cross-domain query at "and" conjunctions.
    /// Returns nil when the message is single-domain or any segment is
    /// unclassifiable (preventing false splits on same-domain multi-item food).
    ///
    /// - "I had eggs and logged 70kg"       → ["I had eggs", "logged 70kg"]
    /// - "mark creatine and update weight"  → ["mark creatine", "update weight"]
    /// - "I had chicken and rice"           → nil (rice has no domain signal)
    /// - "eggs and toast and oj"            → nil (no segment has a domain signal)
    public static func split(_ message: String) -> [String]? {
        guard message.lowercased().contains(" and ") else { return nil }

        let parts = splitOnAnd(message)
        guard parts.count >= 2 else { return nil }

        let domains = parts.map { domain(of: $0) }
        guard domains.allSatisfy({ $0 != nil }) else { return nil }

        let uniqueDomains = Set(domains.compactMap { $0 })
        guard uniqueDomains.count >= 2 else { return nil }

        return parts.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Private

    private static func splitOnAnd(_ message: String) -> [String] {
        var parts: [String] = []
        var remaining = message[...]
        while !remaining.isEmpty {
            if let range = remaining.range(of: " and ", options: .caseInsensitive) {
                parts.append(String(remaining[..<range.lowerBound]))
                remaining = remaining[range.upperBound...]
            } else {
                parts.append(String(remaining))
                break
            }
        }
        return parts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
