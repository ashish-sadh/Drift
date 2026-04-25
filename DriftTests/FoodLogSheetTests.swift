import Foundation
@testable import DriftCore
import Testing
@testable import Drift

// Pure multiplier math that `FoodLogSheet` uses to scale a Food's per-serving
// macros by the user's chosen amount + unit. Keeping this tested guards
// against regressions like #270 where the suggestion-strip path silently
// stopped rescaling macros on serving change.

@Test func multiplierIsOneWhenOneServingAtPieceUnit() {
    // Idli: servingSize=70g, "piece" unit has gramsEquivalent=70.
    // User keeps the default "1 piece" → multiplier should be 1.0.
    let m = FoodLogSheet.multiplier(amount: 1, unitGramsEquivalent: 70, servingSize: 70)
    #expect(m == 1.0)
}

@Test func multiplierScalesLinearlyWithPieceCount() {
    // 2 pieces → 2.0, 3 pieces → 3.0, etc.
    #expect(FoodLogSheet.multiplier(amount: 2, unitGramsEquivalent: 70, servingSize: 70) == 2.0)
    #expect(FoodLogSheet.multiplier(amount: 3, unitGramsEquivalent: 70, servingSize: 70) == 3.0)
}

@Test func multiplierHandlesGramsInputForPieceFood() {
    // 140g of a 70g-per-piece food → 2.0 (user entered grams instead of pieces).
    let m = FoodLogSheet.multiplier(amount: 140, unitGramsEquivalent: 1, servingSize: 70)
    #expect(m == 2.0)
}

@Test func multiplierZeroWhenAmountIsZero() {
    // Guard for the disabled Log button: amount=0 produces multiplier 0.
    let m = FoodLogSheet.multiplier(amount: 0, unitGramsEquivalent: 70, servingSize: 70)
    #expect(m == 0)
}

@Test func multiplierFallsBackToAmountWhenServingSizeIsZero() {
    // Quick-add foods can have servingSize=0 — fall back to raw amount
    // so a "1 serving" entry still logs something instead of NaN.
    let m = FoodLogSheet.multiplier(amount: 1.5, unitGramsEquivalent: 1, servingSize: 0)
    #expect(m == 1.5)
}

@Test func multiplierHandlesFractionalAmounts() {
    // Half an idli → 0.5
    let m = FoodLogSheet.multiplier(amount: 0.5, unitGramsEquivalent: 70, servingSize: 70)
    #expect(m == 0.5)
}

@Test func multiplierScalesCaloriesCorrectlyForTwoIdlis() {
    // Integration-y sanity check against the #270 repro: 2 idlis at 70cal
    // each should yield 140 kcal. Reproducing the full Food×multiplier path.
    let idli = Food(
        name: "Idli", category: "Indian",
        servingSize: 70, servingUnit: "piece",
        calories: 70, proteinG: 2, carbsG: 15, fatG: 0.2
    )
    let m = FoodLogSheet.multiplier(amount: 2, unitGramsEquivalent: 70, servingSize: idli.servingSize)
    #expect(Int(idli.calories * m) == 140)
    #expect(Int(idli.proteinG * m) == 4)
}
