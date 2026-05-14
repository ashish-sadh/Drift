import Foundation

// Async FM-first companions for the food-intent parsers + bridge from the
// typed `FMFoodLogIntent` shape down to the existing `FoodIntent`. Per
// design-666 QW1: the FM path is gated by `Preferences.fmFoodIntentExtractEnabled`
// (kill-switch ON by default). On `.unavailable` / `.notFoodLog` / `.bounded` /
// session error the async path falls through to the existing regex parsers so
// callers get the same shape regardless of backend.

// MARK: - Bridge: FMFoodLogIntent → FoodIntent

public enum FoodLogIntentBridge {

    /// Map only the primary item to a single `FoodIntent`. Used by the
    /// `parseFoodIntent` async companion which expects one intent or nil.
    public static func toFoodIntent(_ intent: FMFoodLogIntent) -> FoodIntent {
        return makeIntent(
            name: intent.foodName,
            quantity: intent.quantity,
            unit: intent.unit,
            mealHint: intent.mealType?.rawValue
        )
    }

    /// Map primary + additionals to `[FoodIntent]`. mealHint from the primary
    /// is inherited by every additional so a "for lunch" suffix tags the
    /// whole batch (matches the existing regex behaviour where the suffix
    /// is stripped once and applied per-result downstream).
    public static func toFoodIntents(_ intent: FMFoodLogIntent) -> [FoodIntent] {
        let mealHint = intent.mealType?.rawValue
        let primary = makeIntent(
            name: intent.foodName,
            quantity: intent.quantity,
            unit: intent.unit,
            mealHint: mealHint
        )
        let additionals = intent.additionalItems.map {
            makeIntent(name: $0.foodName, quantity: $0.quantity, unit: $0.unit, mealHint: mealHint)
        }
        return [primary] + additionals
    }

    // MARK: - Helpers

    /// Trim whitespace and apply the regex parser's plural-singularization
    /// rule so downstream DB lookup behaves the same for both backends
    /// ("eggs" → "egg", but short words like "gas" stay).
    static func singularize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("s") && trimmed.count > 3 {
            return String(trimmed.dropLast())
        }
        return trimmed
    }

    /// Build a `FoodIntent` from a single FM extraction result. Weight /
    /// volume units route through `AIActionExecutor.normalizeToGrams(_:unit:foodHint:)`
    /// so food-aware density (honey, butter, oil) hits the bridge the same
    /// way it hits the regex path. Count units (slices/plates/bowls/servings)
    /// stay as `servings`; pieces resolve to grams when the food is in the
    /// known-piece-foods set, else stay as `servings`.
    private static func makeIntent(
        name: String,
        quantity: Double,
        unit: FMFoodLogIntent.Unit,
        mealHint: String?
    ) -> FoodIntent {
        let singular = singularize(name)
        switch unit {
        case .grams:
            return FoodIntent(query: singular, servings: nil, mealHint: mealHint, gramAmount: quantity)
        case .ounces:
            return FoodIntent(query: singular, servings: nil, mealHint: mealHint, gramAmount: quantity * 28.3495)
        case .milliliters:
            return FoodIntent(query: singular, servings: nil, mealHint: mealHint, gramAmount: quantity)
        case .cups:
            let grams = AIActionExecutor.normalizeToGrams(quantity, unit: "cup", foodHint: singular)
                ?? (quantity * 240)
            return FoodIntent(query: singular, servings: nil, mealHint: mealHint, gramAmount: grams)
        case .tablespoons:
            let grams = AIActionExecutor.normalizeToGrams(quantity, unit: "tbsp", foodHint: singular)
                ?? (quantity * 15)
            return FoodIntent(query: singular, servings: nil, mealHint: mealHint, gramAmount: grams)
        case .teaspoons:
            let grams = AIActionExecutor.normalizeToGrams(quantity, unit: "tsp", foodHint: singular)
                ?? (quantity * 5)
            return FoodIntent(query: singular, servings: nil, mealHint: mealHint, gramAmount: grams)
        case .pieces:
            if let grams = AIActionExecutor.normalizeToGrams(quantity, unit: "piece", foodHint: singular) {
                return FoodIntent(query: singular, servings: nil, mealHint: mealHint, gramAmount: grams)
            }
            return FoodIntent(query: singular, servings: quantity, mealHint: mealHint, gramAmount: nil)
        case .slices, .plates, .bowls, .servings:
            return FoodIntent(query: singular, servings: quantity, mealHint: mealHint, gramAmount: nil)
        }
    }
}

// MARK: - AIActionExecutor async companions

extension AIActionExecutor {

    /// FM-first variant of `parseFoodIntent`. When `Preferences.fmFoodIntentExtractEnabled`
    /// is ON and the platform supports FoundationModels (iOS 26+/macOS 26+),
    /// the message routes through `FoodLogIntentExtractor`; on `.unavailable`,
    /// `.notFoodLog`, `.bounded`, or session error the call falls back to the
    /// regex `parseFoodIntent`. Returns the same `FoodIntent?` shape so
    /// existing callers don't need to branch on backend.
    public static func parseFoodIntentAsync(_ text: String) async -> FoodIntent? {
        guard Preferences.fmFoodIntentExtractEnabled else { return parseFoodIntent(text) }
        do {
            let intent = try await FoodLogIntentExtractor.extract(text: text)
            return FoodLogIntentBridge.toFoodIntent(intent)
        } catch {
            return parseFoodIntent(text)
        }
    }

    /// FM-first variant of `parseMultiFoodIntent`. Same flag + fallback rules
    /// as `parseFoodIntentAsync`. Returns nil when the FM result has only the
    /// primary item (matching the regex contract: multi-intent only when ≥2
    /// foods are present).
    public static func parseMultiFoodIntentAsync(_ text: String) async -> [FoodIntent]? {
        guard Preferences.fmFoodIntentExtractEnabled else { return parseMultiFoodIntent(text) }
        do {
            let intent = try await FoodLogIntentExtractor.extract(text: text)
            let intents = FoodLogIntentBridge.toFoodIntents(intent)
            return intents.count > 1 ? intents : nil
        } catch {
            return parseMultiFoodIntent(text)
        }
    }
}
