import Foundation

/// Parses composed-food queries: "coffee with milk", "oatmeal with honey and banana".
/// Splits on additive connectors so each component is logged separately — calories sum correctly.
public enum ComposedFoodParser {

    // MARK: - Public API

    /// FM-first variant: when `Preferences.fmCompositeFoodExtractEnabled` is
    /// ON and the platform supports FoundationModels (iOS 26+ / macOS 26+),
    /// the message routes through `CompositeFoodExtractor`; on `.unavailable`,
    /// `.sessionFailed`, `.notComposite`, or `.bounded` the call falls back
    /// to the regex parser. Returns the same `[FoodIntent]?` shape as
    /// `parse(_:)` so existing callers don't need to branch on backend.
    /// Per design-666 QW2.
    public static func parseAsync(_ text: String) async -> [FoodIntent]? {
        guard Preferences.fmCompositeFoodExtractEnabled else { return parse(text) }
        if let fm = await fmExtractOrNil(text) { return fm }
        return parse(text)
    }

    /// Map a successful `FMCompositeFoodEntry` to the existing
    /// `[FoodIntent]`. Returns nil on any FM error so the async caller falls
    /// back to the regex parser. The extractor's component list is the
    /// source of truth for *what* the foods are — but each component still
    /// runs through `AIActionExecutor.extractAmount` so food-aware gram
    /// math (honey density, milk ml) lands on the `FoodIntent` exactly
    /// like the regex path produces it.
    private static func fmExtractOrNil(_ text: String) async -> [FoodIntent]? {
        do {
            let entry = try await CompositeFoodExtractor.extract(text: text)
            var intents: [FoodIntent] = []
            for component in entry.components {
                let (amt, food, grams) = AIActionExecutor.extractAmount(from: component.foodName)
                let resolvedName = food.isEmpty ? component.foodName : food
                guard !resolvedName.isEmpty else { continue }
                intents.append(FoodIntent(query: resolvedName, servings: amt, gramAmount: grams))
            }
            return intents.count > 1 ? intents : nil
        } catch {
            return nil
        }
    }

    /// "log coffee with milk" → [FoodIntent("coffee"), FoodIntent("milk")]
    /// "oatmeal with milk and honey" → [FoodIntent("oatmeal"), FoodIntent("milk"), FoodIntent("honey")]
    /// Returns nil when no composition connector is found.
    /// Regex-only synchronous path — kept as the stable fallback used by
    /// `parseAsync` when FM is unavailable / refuses / returns out-of-bounds.
    public static func parse(_ text: String) -> [FoodIntent]? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)

        var remainder = stripVerbPrefixes(from: lower)
        guard !remainder.isEmpty else { return nil }

        // Strip trailing meal/noise qualifiers
        remainder = stripTrailingSuffixes(from: remainder)

        // Must contain a composition connector — bail early if none present
        guard containsCompositionConnector(remainder) else { return nil }

        // Split remainder into base + additive string
        guard let (baseRaw, additivesRaw) = splitOnConnector(remainder) else { return nil }

        // Validate base isn't empty after stripping
        let baseTrimmed = baseRaw.trimmingCharacters(in: .whitespaces)
        guard !baseTrimmed.isEmpty else { return nil }

        // Build base intent
        let (baseAmt, baseFood, baseGrams) = AIActionExecutor.extractAmount(from: baseTrimmed)
        guard !baseFood.isEmpty else { return nil }
        let baseIntent = FoodIntent(query: baseFood, servings: baseAmt, gramAmount: baseGrams)

        // Split additives on "and" / "," to support multi-additive: "milk and honey"
        let additiveComponents = splitAdditives(additivesRaw)
        guard !additiveComponents.isEmpty else { return nil }

        var intents: [FoodIntent] = [baseIntent]
        for raw in additiveComponents {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "^extra ", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^some ", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^a bit of ", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let (amt, food, grams) = AIActionExecutor.extractAmount(from: trimmed)
            guard !food.isEmpty else { continue }
            intents.append(FoodIntent(query: food, servings: amt, gramAmount: grams))
        }

        // Need at least 2 items (base + 1 additive) to be useful
        return intents.count > 1 ? intents : nil
    }

    // MARK: - Private Helpers

    private static let verbPrefixes = [
        "i want to ", "i'd like to ", "can you ", "could you ", "please ", "help me ",
        "log ", "ate ", "had ", "add ", "track ", "logged ", "eating ", "drank ", "drinking ", "made ",
        "i just had ", "i just ate ", "i had ", "i ate ", "just had ", "just ate ",
        "i'm having ", "i'm eating ", "snacked on ", "i drank ", "just drank ", "i made ",
    ]

    private static func stripVerbPrefixes(from text: String) -> String {
        var result = text
        for prefix in verbPrefixes {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        if result.hasPrefix("my ") { result = String(result.dropFirst(3)) }
        return result
    }

    private static let trailingSuffixes = [
        " for breakfast", " for lunch", " for dinner", " for snack",
        " for me", " please", " today",
    ]

    private static func stripTrailingSuffixes(from text: String) -> String {
        var result = text
        for suffix in trailingSuffixes {
            if result.hasSuffix(suffix) {
                result = String(result.dropLast(suffix.count))
                break
            }
        }
        return result
    }

    /// Ordered longest-first so "served with" matches before "with"
    private static let connectors = ["served with", "alongside", "plus", " with "]

    private static func containsCompositionConnector(_ text: String) -> Bool {
        connectors.contains { text.contains($0) }
    }

    /// Split on the first matching connector. Returns (base, additives).
    private static func splitOnConnector(_ text: String) -> (String, String)? {
        for connector in connectors {
            if let range = text.range(of: connector) {
                let base = String(text[..<range.lowerBound])
                let additives = String(text[range.upperBound...])
                if !base.trimmingCharacters(in: .whitespaces).isEmpty,
                   !additives.trimmingCharacters(in: .whitespaces).isEmpty {
                    return (base, additives)
                }
            }
        }
        return nil
    }

    /// Split additive string on "and" / "," — avoids breaking compound foods.
    private static let compoundAdditives: Set<String> = [
        "cream and sugar", "salt and pepper", "bread and butter",
    ]

    private static func splitAdditives(_ raw: String) -> [String] {
        let text = raw.trimmingCharacters(in: .whitespaces)
        // Preserve known compound additive phrases
        if compoundAdditives.contains(text) { return [text] }

        var parts = [text]
        for sep in [", and ", " and ", ", "] {
            parts = parts.flatMap { $0.components(separatedBy: sep) }
        }
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
