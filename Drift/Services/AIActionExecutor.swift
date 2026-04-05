import Foundation

/// Parses user messages for food/weight/workout intent and extracts parameters.
/// Used to pre-fill and launch native app views from the AI assistant.
enum AIActionExecutor {

    struct FoodIntent {
        let query: String
        let servings: Double?
    }

    struct WeightIntent {
        let weightValue: Double
        let unit: WeightUnit
    }

    /// Try to parse a food logging intent from natural language.
    /// "log 1/3 avocado" → FoodIntent(query: "avocado", servings: 0.33)
    /// "ate 2 eggs" → FoodIntent(query: "eggs", servings: 2)
    /// "had chicken breast" → FoodIntent(query: "chicken breast", servings: nil)
    static func parseFoodIntent(_ text: String) -> FoodIntent? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)

        // Must start with a logging verb
        let verbs = ["log ", "ate ", "had ", "add ", "track ", "logged ", "eating "]
        guard let verb = verbs.first(where: { lower.hasPrefix($0) }) else { return nil }

        var remainder = String(lower.dropFirst(verb.count)).trimmingCharacters(in: .whitespaces)

        // Remove trailing qualifiers
        for suffix in [" for me", " please", " today", " for breakfast", " for lunch", " for dinner", " for snack"] {
            if remainder.hasSuffix(suffix) {
                remainder = String(remainder.dropLast(suffix.count))
            }
        }

        guard !remainder.isEmpty else { return nil }

        // Try to extract amount from the beginning
        let (amount, food) = extractAmount(from: remainder)

        guard !food.isEmpty else { return nil }
        return FoodIntent(query: food, servings: amount)
    }

    /// Try to parse a weight logging intent.
    /// "I weigh 165" → WeightIntent(165, lbs)
    /// "weight is 75.2 kg" → WeightIntent(75.2, kg)
    static func parseWeightIntent(_ text: String) -> WeightIntent? {
        let lower = text.lowercased()
        guard lower.contains("weigh") || lower.contains("weight is") || lower.contains("weight:") else { return nil }

        // Extract number
        let pattern = #"(\d+\.?\d*)\s*(kg|lbs|lb|pounds?)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
              let numRange = Range(match.range(at: 1), in: lower),
              let value = Double(String(lower[numRange])) else { return nil }

        // Detect unit
        let unit: WeightUnit
        if let unitRange = Range(match.range(at: 2), in: lower) {
            let unitStr = String(lower[unitRange])
            unit = unitStr.hasPrefix("kg") ? .kg : .lbs
        } else {
            unit = Preferences.weightUnit // default to user's preference
        }

        return WeightIntent(weightValue: value, unit: unit)
    }

    // MARK: - Amount Parsing

    /// Extract amount from beginning of string: "1/3 avocado" → (0.33, "avocado")
    private static func extractAmount(from text: String) -> (Double?, String) {
        let parts = text.split(separator: " ", maxSplits: 1)
        guard let first = parts.first else { return (nil, text) }
        let firstStr = String(first)

        // Fraction: "1/3", "1/2"
        if firstStr.contains("/") {
            let fracParts = firstStr.split(separator: "/")
            if fracParts.count == 2, let num = Double(fracParts[0]), let den = Double(fracParts[1]), den > 0 {
                let food = parts.count > 1 ? String(parts[1]) : ""
                return (num / den, food.trimmingCharacters(in: .whitespaces))
            }
        }

        // Word amounts
        let wordAmounts: [String: Double] = ["half": 0.5, "quarter": 0.25, "one": 1, "two": 2, "three": 3, "a": 1, "an": 1]
        if let amount = wordAmounts[firstStr] {
            let food = parts.count > 1 ? String(parts[1]) : ""
            return (amount, food.trimmingCharacters(in: .whitespaces))
        }

        // Number: "2", "0.5", "200"
        if let num = Double(firstStr) {
            let food = parts.count > 1 ? String(parts[1]) : ""
            // If number is large (>10), it might be grams not servings — include with food name
            if num > 10 {
                return (nil, text) // "200g chicken" — let food search handle it
            }
            return (num, food.trimmingCharacters(in: .whitespaces))
        }

        // No amount found — entire text is food name
        return (nil, text)
    }
}
