import Foundation
@testable import DriftCore
import Testing

// Tier-0 tests for the design-665 nutrition-label FM migration.
// Cover the pure helpers (bounds + prompt + flag default). FM-backed
// extraction itself runs as Tier-3 in FoundationModelsExtractionEvalTests.

// MARK: - NutritionBounds — hallucination guard

@Test func bounds_passClean() {
    let r = FMNutritionResult(
        name: "Clif Bar", servingSize: "1 Bar (68g)",
        calories: 240, proteinG: 9, carbsG: 41, fatG: 5, fiberG: 4, sugarG: 21, sodiumMg: 200
    )
    #expect(NutritionBounds.violation(in: r) == nil)
}

@Test func bounds_rejectImpossibleCalories() {
    let r = FMNutritionResult(
        name: "Hallucination", servingSize: "1 g",
        calories: 12_000, proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0, sugarG: 0, sodiumMg: 0
    )
    #expect(NutritionBounds.violation(in: r) == "calories")
}

@Test func bounds_rejectImpossibleProtein() {
    let r = FMNutritionResult(
        name: "Bad", servingSize: "1 serving",
        calories: 200, proteinG: 999, carbsG: 0, fatG: 0, fiberG: 0, sugarG: 0, sodiumMg: 0
    )
    #expect(NutritionBounds.violation(in: r) == "proteinG")
}

@Test func bounds_rejectImpossibleSodium() {
    let r = FMNutritionResult(
        name: "Bad", servingSize: "1 serving",
        calories: 200, proteinG: 5, carbsG: 5, fatG: 5, fiberG: 5, sugarG: 5, sodiumMg: 99_999
    )
    #expect(NutritionBounds.violation(in: r) == "sodiumMg")
}

@Test func bounds_zeroIsValid() {
    // A label that lists "0 g" everywhere is rare but legal — should not trigger
    let r = FMNutritionResult(
        name: "Water", servingSize: "240 mL",
        calories: 0, proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0, sugarG: 0, sodiumMg: 0
    )
    #expect(NutritionBounds.violation(in: r) == nil)
}

// MARK: - Feature flag default

@Test(.serialized) func fmNutritionExtractFlagBehavior() {
    // Single test instead of split — Swift Testing parallelizes by default
    // and the default + override paths share one UserDefaults key.
    let key = "drift_fm_nutrition_extract"
    defer { UserDefaults.standard.removeObject(forKey: key) }

    UserDefaults.standard.removeObject(forKey: key)
    #expect(Preferences.fmNutritionExtractEnabled == true,
            "Per design-665 the FM nutrition path defaults ON (kill-switch model)")

    Preferences.fmNutritionExtractEnabled = false
    #expect(Preferences.fmNutritionExtractEnabled == false,
            "Explicit off must persist")

    Preferences.fmNutritionExtractEnabled = true
    #expect(Preferences.fmNutritionExtractEnabled == true,
            "Explicit on must persist")
}

// MARK: - Prompt anchoring

@Test func prompt_asksForCanonicalUnits() {
    let p = NutritionExtractor.buildPrompt(for: "any")
    #expect(p.contains("kcal"))
    #expect(p.contains("grams"))
    #expect(p.contains("milligrams"))
}

@Test func prompt_handlesMultilingualLabels() {
    // The migration unlocks the non-English label case — pin the
    // multilingual instruction so a future prompt-refresh cycle doesn't drop it.
    let p = NutritionExtractor.buildPrompt(for: "any").lowercased()
    #expect(p.contains("any language") || p.contains("multilingual"))
    #expect(p.contains("spanish"))
    #expect(p.contains("hindi"))
}

@Test func prompt_treatsLessThanOneGramAsHalf() {
    // FDA labels say "<1 g" when value is between 0.5 and 1 — the rounded
    // half-gram is the most accurate single-value interpretation.
    let p = NutritionExtractor.buildPrompt(for: "any")
    #expect(p.contains("<1 g"))
    #expect(p.contains("0.5"))
}

@Test func prompt_includesInputText() {
    let unique = "MARKER_\(UUID().uuidString.prefix(8))"
    let p = NutritionExtractor.buildPrompt(for: unique)
    #expect(p.contains(unique))
}
