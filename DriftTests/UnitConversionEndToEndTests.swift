import XCTest
@testable import DriftCore
@testable import Drift

/// End-to-end (food, unit, amount) → kcal assertions.
/// Complements SmartUnitsGoldSetTests (which only checks which units get offered)
/// by verifying the final calorie number. Pinned to the audit at
/// Docs/audits/unit-conversions-audit-2026-04-24.md — each test corresponds to
/// a row in §3 of that audit.
///
/// Fully deterministic (pure functions, no DB, no LLM). Runs in <1s.
/// Run: xcodebuild test -only-testing:'DriftTests/UnitConversionEndToEndTests'
final class UnitConversionEndToEndTests: XCTestCase {

    /// Shortcut re-used from SmartUnitsGoldSetTests — same scaling formula
    /// the real UI runs through FoodLogSheet.multiplier.
    private func kcal(food: Food, unitLabel: String, amount: Double) -> Double {
        let units = FoodUnit.smartUnits(for: food)
        guard let unit = units.first(where: { $0.label == unitLabel }) else {
            XCTFail("Food '\(food.name)' does not offer unit '\(unitLabel)'. Offered: \(units.map(\.label))")
            return .nan
        }
        let mult = FoodLogSheet.multiplier(amount: amount,
                                           unitGramsEquivalent: unit.gramsEquivalent,
                                           servingSize: food.servingSize)
        return food.calories * mult
    }

    // MARK: - Fix 1: the strawberry regression

    /// Before fix: `5 strawberries` → 5 × 150g = 750g → 240 kcal (4× over).
    /// After fix + pieceSizeG=12g: 5 × 12g = 60g → 48 × 0.4 = 19 kcal.
    func testStrawberryPiece_matchesMediumBerryWeight() {
        let food = Food(name: "Strawberries, Fresh", category: "Grocery",
                        servingSize: 150, servingUnit: "g",
                        calories: 48, pieceSizeG: 12)
        let cal = kcal(food: food, unitLabel: "piece", amount: 5)
        // 48 kcal per 150g × (60g / 150g) = 19.2 kcal
        XCTAssertEqual(cal, 19.2, accuracy: 0.5,
                       "5 strawberries must be ~19 kcal (60g), not 240 kcal (750g).")
    }

    /// Without a trusted pieceSizeG AND no pieceGrams() match, the unit
    /// must NOT be offered. Users get g/serving instead.
    func testPieceFallback_refusedWhenPieceWeightUnknown() {
        // "Zamalak Custard" — invented name guaranteed to miss all substring
        // dictionaries in ServingUnit.swift. No pieceSizeG override.
        let mystery = Food(name: "Zamalak Custard", category: "Test",
                           servingSize: 200, servingUnit: "g", calories: 300)
        let units = FoodUnit.smartUnits(for: mystery)
        XCTAssertFalse(units.contains { $0.label == "piece" },
                       "Unknown food with no pieceSizeG override must NOT synthesize a piece unit — this is the strawberry anti-pattern.")
    }

    /// Existing behaviour preserved: known produce in pieceGrams() still gets
    /// `piece` without needing a per-food override.
    func testPieceFallback_allowedForKnownProduce() {
        let tomato = Food(name: "Tomato", category: "Veggies",
                          servingSize: 200, servingUnit: "g", calories: 36)
        let units = FoodUnit.smartUnits(for: tomato)
        XCTAssertTrue(units.contains { $0.label == "piece" },
                      "pieceGramsIfKnown matches 'tomato' → 120g per piece, must still offer piece.")
    }

    /// Per-food override takes precedence over pieceGramsIfKnown.
    func testPieceSizeG_overridesDictionary() {
        // Cherry tomato (pieceGrams default for 'tomato' = 120g, but real cherry
        // tomato ≈ 17g — override should win).
        let cherry = Food(name: "Cherry Tomato", category: "Veggies",
                          servingSize: 149, servingUnit: "g", calories: 27,
                          pieceSizeG: 17)
        let unit = FoodUnit.smartUnits(for: cherry).first(where: { $0.label == "piece" })
        XCTAssertEqual(unit?.gramsEquivalent, 17,
                       "pieceSizeG=17 must override the pieceGrams('tomato')=120 default.")
    }

    // MARK: - Fix 2: tbsp/scoop overrides

    /// Without tbspSizeG, honey falls back to 15g tbsp — audit §2 predicts
    /// -29% undercount. With an override set, we recover accuracy.
    func testTbspHoney_respectsOverride() {
        // Honey per-100g ≈ 304 kcal, real tbsp ≈ 21g.
        let honey = Food(name: "Honey", category: "Grocery",
                         servingSize: 21, servingUnit: "g", calories: 64,
                         tbspSizeG: 21)
        let unit = FoodUnit.smartUnits(for: honey).first(where: { $0.label == "tbsp" })
        XCTAssertEqual(unit?.gramsEquivalent, 21,
                       "tbspSizeG=21 must beat the flat 15g constant.")
    }

    func testTbspSauce_flaggedAsEstimateWithoutOverride() {
        // BBQ sauce hits the smartUnits tbspFoods branch (adds tbsp=15g flat).
        // Honey has its own 21g primaryUnit branch which is a measured real
        // value, so it's correctly *not* an estimate; BBQ sauce is the actual
        // 15g-flat-constant path.
        let sauce = Food(name: "BBQ Sauce", category: "Grocery",
                         servingSize: 30, servingUnit: "g", calories: 50)
        let unit = FoodUnit.smartUnits(for: sauce).first(where: { $0.label == "tbsp" })
        XCTAssertNotNil(unit, "Sauce must offer a tbsp unit.")
        XCTAssertEqual(unit?.isEstimate, true,
                       "tbsp without tbspSizeG must be flagged isEstimate so UI prefixes '≈'.")
    }

    func testScoopProteinPowder_respectsOverride() {
        // Whey tubs ship with ss = 100g but a real scoop is ~30g.
        let whey = Food(name: "Whey Protein Powder", category: "Supplement",
                        servingSize: 100, servingUnit: "g", calories: 400,
                        scoopSizeG: 30)
        let unit = FoodUnit.smartUnits(for: whey).first(where: { $0.label == "scoop" })
        XCTAssertEqual(unit?.gramsEquivalent, 30,
                       "scoopSizeG=30 must override the ss=100 fallback that would have reported 3× the kcal per scoop.")
    }

    // MARK: - Fix 3: UI honesty flag

    /// Spray is a real guess (0.25g) — must be flagged so UI shows "≈".
    func testSprayOliveOil_signalsEstimate() {
        let oil = Food(name: "Olive Oil", category: "Grocery",
                       servingSize: 14, servingUnit: "g", calories: 119)
        let spray = FoodUnit.smartUnits(for: oil).first(where: { $0.label == "spray" })
        XCTAssertNotNil(spray, "Oil should expose a spray unit.")
        XCTAssertEqual(spray?.isEstimate, true,
                       "spray=0.25g is a bottle-to-bottle guess; must be flagged isEstimate.")
    }

    /// Dictionary-sourced and override-sourced weights are NOT estimates.
    func testTrustedUnits_notFlaggedAsEstimate() {
        let tomato = Food(name: "Tomato", category: "Veggies",
                          servingSize: 200, servingUnit: "g", calories: 36)
        let piece = FoodUnit.smartUnits(for: tomato).first(where: { $0.label == "piece" })
        XCTAssertEqual(piece?.isEstimate, false,
                       "pieceGramsIfKnown match is measured data — must NOT be flagged isEstimate.")
    }

    // MARK: - Fix 2b: USDA foodPortions extraction

    func testUSDAExtractUnitWeights_strawberries() {
        let portions: [[String: Any]] = [
            ["amount": 1.0, "modifier": "cup, sliced", "gramWeight": 166.0],
            ["amount": 1.0, "modifier": "large (1-3/8\" dia)", "gramWeight": 18.0],
            ["amount": 1.0, "modifier": "medium (1-1/4\" dia)", "gramWeight": 12.0],
            ["amount": 1.0, "modifier": "small (1\" dia)", "gramWeight": 7.0],
        ]
        let (piece, cup, _) = USDAFoodService.extractUnitWeights(from: portions)
        XCTAssertEqual(piece, 12, "`medium` portion should become pieceSizeG=12.")
        XCTAssertEqual(cup, 166, "`cup, sliced` portion should become cupSizeG=166.")
    }

    func testUSDAExtractUnitWeights_emptyPortions() {
        let (piece, cup, tbsp) = USDAFoodService.extractUnitWeights(from: [])
        XCTAssertNil(piece)
        XCTAssertNil(cup)
        XCTAssertNil(tbsp)
    }
}
