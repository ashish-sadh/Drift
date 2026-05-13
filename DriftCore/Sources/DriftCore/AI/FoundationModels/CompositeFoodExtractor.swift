import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Public output type (available on all OS versions)

/// One composite-food entry extracted by the FM pipeline. Mirrors the
/// `@Generable FMCompositeFoodSchema` below: an ordered list of food
/// components ("biryani" + "raita", "coffee" + "milk") that a single
/// user message described as one composed meal. `isMain` flags the dish
/// the rest accompanies — downstream meal-builder uses this for naming
/// but it is not required for nutrition math.
public struct FMCompositeFoodEntry: Sendable, Equatable {
    public struct Component: Sendable, Equatable {
        public let foodName: String
        public let isMain: Bool

        public init(foodName: String, isMain: Bool) {
            self.foodName = foodName
            self.isMain = isMain
        }
    }

    public let components: [Component]

    public init(components: [Component]) {
        self.components = components
    }
}

public enum FMCompositeFoodExtractorError: Error, Sendable {
    case unavailable
    case sessionFailed(String)
    /// Returned when the model produces fewer than 2 distinct components.
    /// A single-component result is not a composite — caller falls back to
    /// the regex `parse` (which also returns nil for a single food).
    case notComposite
    /// Returned when the model produces more than `CompositeFoodBounds.maxComponents`
    /// components. Real meals top out around 6 (thali). Larger counts are a
    /// hallucination — bail to regex.
    case bounded(componentCount: Int)
}

// MARK: - Bounds (design-666 sanity post-extraction)

public enum CompositeFoodBounds {
    /// 2 = base + at least one accompaniment; below this it isn't a composite.
    public static let minComponents = 2
    /// Thali / shared-plate ceiling. Anything beyond is almost always the
    /// model splitting a single dish name into ingredient words.
    public static let maxComponents = 8

    /// nil = entry passes; otherwise returns the violation kind so the
    /// extractor can throw the right typed error.
    public enum Violation: Equatable, Sendable {
        case notComposite
        case tooMany(Int)
    }

    public static func violation(in entry: FMCompositeFoodEntry) -> Violation? {
        let n = entry.components.count
        if n < minComponents { return .notComposite }
        if n > maxComponents { return .tooMany(n) }
        return nil
    }
}

// MARK: - Extractor

public enum CompositeFoodExtractor {

    /// Extract a composite-food split from a free-text user message.
    /// Throws `.unavailable` on iOS<26 / macOS<26 (or when FoundationModels is
    /// not linked); throws `.notComposite` when the model returns fewer than
    /// two components; throws `.bounded` when over the thali ceiling. All
    /// throw cases tell the caller to fall back to the regex `parse`.
    public static func extract(text: String) async throws -> FMCompositeFoodEntry {
#if canImport(FoundationModels)
        if #available(macOS 26, iOS 26, *) {
            let prompt = buildPrompt(for: text)
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt, generating: FMCompositeFoodSchema.self)
                let entry = FMCompositeFoodEntry(
                    components: response.content.components.map {
                        FMCompositeFoodEntry.Component(foodName: $0.foodName, isMain: $0.isMain)
                    }
                )
                if let v = CompositeFoodBounds.violation(in: entry) {
                    switch v {
                    case .notComposite: throw FMCompositeFoodExtractorError.notComposite
                    case .tooMany(let n): throw FMCompositeFoodExtractorError.bounded(componentCount: n)
                    }
                }
                return entry
            } catch let err as FMCompositeFoodExtractorError {
                throw err
            } catch {
                throw FMCompositeFoodExtractorError.sessionFailed("\(error)")
            }
        }
#endif
        throw FMCompositeFoodExtractorError.unavailable
    }

    /// Prompt sent to the foundation model. Indian-food first because the
    /// regex path's hardcoded `["served with", "alongside", "plus", "with"]`
    /// list misses regional connectors like "garnished with", "topped with",
    /// and bare-juxtaposition compounds like "dal chawal" / "idli sambar".
    public static func buildPrompt(for text: String) -> String {
        """
        Split the user's food description into its distinct food components, ordered as the user mentioned them.

        A composite is one message describing two or more foods eaten together. Examples:
        - "coffee with milk" → ["coffee" (main), "milk"]
        - "oatmeal with milk and honey" → ["oatmeal" (main), "milk", "honey"]
        - "biryani with raita" → ["biryani" (main), "raita"]
        - "dal chawal" → ["dal" (main), "chawal"] (bare-juxtaposition Indian compound — split)
        - "idli sambar" → ["idli" (main), "sambar"]
        - "chicken served with rice and salad" → ["chicken" (main), "rice", "salad"]
        - "toast topped with butter and jam" → ["toast" (main), "butter", "jam"]

        Rules:
        - If the user named only one food ("biryani"), return that one component (caller will not log as composite).
        - Treat known compound additives as one component: "cream and sugar", "salt and pepper", "bread and butter".
        - Do NOT split a single dish name into ingredient words — "chicken biryani" is one component, not [chicken, biryani].
        - Keep the food names verbatim (preserve quantities like "100ml milk", "2 tbsp honey"). Downstream parses quantity.
        - Mark exactly one component as the main dish (isMain=true). Accompaniments / additives are isMain=false. If unclear, the first item is main.

        Text:

        \(text)
        """
    }
}

// MARK: - Generable schema (compiled only on macOS 26+ / iOS 26+)

#if canImport(FoundationModels)
@available(macOS 26, iOS 26, *)
@Generable
struct FMCompositeFoodSchema: Sendable {
    @Guide(description: "Each distinct food component the user mentioned, ordered as said. Two or more for a composite; one when the user named only a single dish.")
    let components: [Component]

    @Generable
    struct Component: Sendable {
        @Guide(description: "Food name verbatim including any user-given quantity (e.g. 'coffee', '100ml milk', 'chicken biryani'). Do not normalize.")
        let foodName: String
        @Guide(description: "True for the dish's main item, false for accompaniments / additives. Exactly one component should be true.")
        let isMain: Bool
    }
}
#endif
