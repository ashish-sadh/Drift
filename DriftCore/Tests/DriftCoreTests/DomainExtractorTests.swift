import XCTest
@testable import DriftCore

/// Tier-0 gold set for Stage 3 domain extraction — amounts, food names, weight values, exercise data.
/// 50 typed queries covering: gram/volume units, fractions, multipliers, count units, word amounts,
/// ranges, food intent parsing, weight intent parsing, workout exercise parsing, and known limits.
/// All 45 non-limit cases are deterministic pure-function assertions. No LLM, no DB, no simulator.
/// Run: cd DriftCore && swift test --filter DomainExtractorTests
final class DomainExtractorTests: XCTestCase {

    // MARK: - A: extractAmount — gram/volume units (7 cases)

    func test_extract_gramsAttached() {
        // "100g chicken" — unit glued to number
        let (s, food, g) = AIActionExecutor.extractAmount(from: "100g chicken")
        XCTAssertNil(s)
        XCTAssertEqual(food, "chicken")
        XCTAssertEqual(g!, 100.0, accuracy: 0.01)
    }

    func test_extract_gramsWord() {
        // "200 grams rice" — spelled-out unit
        let (s, food, g) = AIActionExecutor.extractAmount(from: "200 grams rice")
        XCTAssertNil(s)
        XCTAssertEqual(food, "rice")
        XCTAssertEqual(g!, 200.0, accuracy: 0.01)
    }

    func test_extract_oz() {
        // "2 oz salmon" — imperial weight
        let (s, food, g) = AIActionExecutor.extractAmount(from: "2 oz salmon")
        XCTAssertNil(s)
        XCTAssertEqual(food, "salmon")
        XCTAssertEqual(g!, 56.699, accuracy: 0.01)
    }

    func test_extract_kg() {
        // "1 kg oats" — metric kilogram
        let (s, food, g) = AIActionExecutor.extractAmount(from: "1 kg oats")
        XCTAssertNil(s)
        XCTAssertEqual(food, "oats")
        XCTAssertEqual(g!, 1000.0, accuracy: 0.01)
    }

    func test_extract_cup() {
        // "1 cup milk" — volume → grams (240g/cup)
        let (s, food, g) = AIActionExecutor.extractAmount(from: "1 cup milk")
        XCTAssertNil(s)
        XCTAssertEqual(food, "milk")
        XCTAssertEqual(g!, 240.0, accuracy: 0.01)
    }

    func test_extract_tbsp() {
        // "1 tbsp ghee" — tablespoon → 15g
        let (s, food, g) = AIActionExecutor.extractAmount(from: "1 tbsp ghee")
        XCTAssertNil(s)
        XCTAssertEqual(food, "ghee")
        XCTAssertEqual(g!, 15.0, accuracy: 0.01)
    }

    func test_extract_tsp() {
        // "2 tsp honey" — teaspoon → 5g each
        let (s, food, g) = AIActionExecutor.extractAmount(from: "2 tsp honey")
        XCTAssertNil(s)
        XCTAssertEqual(food, "honey")
        XCTAssertEqual(g!, 10.0, accuracy: 0.01)
    }

    // MARK: - B: extractAmount — fractions (5 cases)

    func test_extract_halfACup() {
        // "half a cup rice" — two-word amount + volume unit
        let (s, food, g) = AIActionExecutor.extractAmount(from: "half a cup rice")
        XCTAssertNil(s)
        XCTAssertEqual(food, "rice")
        XCTAssertEqual(g!, 120.0, accuracy: 0.01)
    }

    func test_extract_halfATbsp() {
        // "half a tbsp peanut butter" — multi-word food name
        let (s, food, g) = AIActionExecutor.extractAmount(from: "half a tbsp peanut butter")
        XCTAssertNil(s)
        XCTAssertEqual(food, "peanut butter")
        XCTAssertEqual(g!, 7.5, accuracy: 0.01)
    }

    func test_extract_fractionOneThird() {
        // "1/3 avocado" — slash fraction → servings
        let (s, food, g) = AIActionExecutor.extractAmount(from: "1/3 avocado")
        XCTAssertEqual(s!, 1.0 / 3.0, accuracy: 0.01)
        XCTAssertEqual(food, "avocado")
        XCTAssertNil(g)
    }

    func test_extract_fractionOneHalf() {
        // "1/2 banana" — slash fraction
        let (s, food, g) = AIActionExecutor.extractAmount(from: "1/2 banana")
        XCTAssertEqual(s!, 0.5, accuracy: 0.01)
        XCTAssertEqual(food, "banana")
        XCTAssertNil(g)
    }

    func test_extract_quarterServing() {
        // "a quarter serving oatmeal" — two-word amount + count unit
        let (s, food, g) = AIActionExecutor.extractAmount(from: "a quarter serving oatmeal")
        XCTAssertEqual(s!, 0.25, accuracy: 0.01)
        XCTAssertEqual(food, "oatmeal")
        XCTAssertNil(g)
    }

    // MARK: - C: extractAmount — multiplier keywords (5 cases)

    func test_extract_doubleThe() {
        let (s, food, g) = AIActionExecutor.extractAmount(from: "double the chicken")
        XCTAssertEqual(s!, 2.0, accuracy: 0.01)
        XCTAssertEqual(food, "chicken")
        XCTAssertNil(g)
    }

    func test_extract_tripleThe() {
        let (s, food, g) = AIActionExecutor.extractAmount(from: "triple the rice")
        XCTAssertEqual(s!, 3.0, accuracy: 0.01)
        XCTAssertEqual(food, "rice")
        XCTAssertNil(g)
    }

    func test_extract_twice() {
        let (s, food, g) = AIActionExecutor.extractAmount(from: "twice the salmon")
        XCTAssertEqual(s!, 2.0, accuracy: 0.01)
        XCTAssertEqual(food, "salmon")
        XCTAssertNil(g)
    }

    func test_extract_2x() {
        let (s, food, g) = AIActionExecutor.extractAmount(from: "2x oats")
        XCTAssertEqual(s!, 2.0, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "oats")
        XCTAssertNil(g)
    }

    func test_extract_3x() {
        let (s, food, g) = AIActionExecutor.extractAmount(from: "3x protein powder")
        XCTAssertEqual(s!, 3.0, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "protein powder")
        XCTAssertNil(g)
    }

    // MARK: - D: extractAmount — count/piece units (3 cases)

    func test_extract_pieces() {
        let (s, food, g) = AIActionExecutor.extractAmount(from: "2 pieces chicken")
        XCTAssertEqual(s!, 2.0, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "chicken")
        XCTAssertNil(g)
    }

    func test_extract_scoops() {
        let (s, food, g) = AIActionExecutor.extractAmount(from: "3 scoops protein")
        XCTAssertEqual(s!, 3.0, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "protein")
        XCTAssertNil(g)
    }

    func test_extract_serving() {
        let (s, food, g) = AIActionExecutor.extractAmount(from: "1 serving oatmeal")
        XCTAssertEqual(s!, 1.0, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "oatmeal")
        XCTAssertNil(g)
    }

    // MARK: - E: extractAmount — word amounts (3 cases)

    func test_extract_aFew() {
        // "a few" → 3 servings
        let (s, food, g) = AIActionExecutor.extractAmount(from: "a few cookies")
        XCTAssertEqual(s!, 3.0, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "cookies")
        XCTAssertNil(g)
    }

    func test_extract_aCoupleOf() {
        // "a couple of" → 2 servings
        let (s, food, g) = AIActionExecutor.extractAmount(from: "a couple of eggs")
        XCTAssertEqual(s!, 2.0, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "eggs")
        XCTAssertNil(g)
    }

    func test_extract_halfCupOf() {
        // "half cup of rice" — word amount + volume unit + "of" connector
        let (s, food, g) = AIActionExecutor.extractAmount(from: "half cup of rice")
        XCTAssertNil(s)
        XCTAssertEqual(food.lowercased(), "rice")
        XCTAssertEqual(g!, 120.0, accuracy: 0.01)
    }

    // MARK: - F: extractAmount — ranges (2 cases)

    func test_extract_rangeTo() {
        // "2 to 3 eggs" → takes higher bound
        let (s, food, g) = AIActionExecutor.extractAmount(from: "2 to 3 eggs")
        XCTAssertEqual(s!, 3.0, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "eggs")
        XCTAssertNil(g)
    }

    func test_extract_rangeOr() {
        // "2 or 3 bananas" → takes higher bound
        let (s, food, g) = AIActionExecutor.extractAmount(from: "2 or 3 bananas")
        XCTAssertEqual(s!, 3.0, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "bananas")
        XCTAssertNil(g)
    }

    // MARK: - G: parseFoodIntent — logging verbs and natural prefixes (7 cases)

    func test_intent_logEggs() {
        // "log 2 eggs" — count with singularization
        let intent = AIActionExecutor.parseFoodIntent("log 2 eggs")
        XCTAssertNotNil(intent)
        XCTAssertEqual(intent!.query, "egg")
        XCTAssertEqual(intent!.servings!, 2.0, accuracy: 0.01)
        XCTAssertNil(intent!.gramAmount)
    }

    func test_intent_ateChickenForLunch() {
        // "ate 100g chicken for lunch" — gram amount + meal hint
        let intent = AIActionExecutor.parseFoodIntent("ate 100g chicken for lunch")
        XCTAssertNotNil(intent)
        XCTAssertEqual(intent!.query, "chicken")
        XCTAssertEqual(intent!.gramAmount!, 100.0, accuracy: 0.01)
        XCTAssertEqual(intent!.mealHint, "lunch")
        XCTAssertNil(intent!.servings)
    }

    func test_intent_halfBananaForBreakfast() {
        // "had 1/2 banana for breakfast" — fraction + meal hint
        let intent = AIActionExecutor.parseFoodIntent("had 1/2 banana for breakfast")
        XCTAssertNotNil(intent)
        XCTAssertEqual(intent!.query, "banana")
        XCTAssertEqual(intent!.servings!, 0.5, accuracy: 0.01)
        XCTAssertEqual(intent!.mealHint, "breakfast")
    }

    func test_intent_doubleRice() {
        // "i had double the rice" — natural prefix + multiplier
        let intent = AIActionExecutor.parseFoodIntent("i had double the rice")
        XCTAssertNotNil(intent)
        XCTAssertEqual(intent!.query, "rice")
        XCTAssertEqual(intent!.servings!, 2.0, accuracy: 0.01)
    }

    func test_intent_halfCupOats() {
        // "log half a cup of oats" — fraction + volume → grams, singularized
        let intent = AIActionExecutor.parseFoodIntent("log half a cup of oats")
        XCTAssertNotNil(intent)
        XCTAssertEqual(intent!.query, "oat")
        XCTAssertEqual(intent!.gramAmount!, 120.0, accuracy: 0.01)
        XCTAssertNil(intent!.servings)
    }

    func test_intent_indianCompoundName() {
        // "had dal makhni for dinner" — multi-word Indian food name + meal hint
        let intent = AIActionExecutor.parseFoodIntent("had dal makhni for dinner")
        XCTAssertNotNil(intent)
        XCTAssertEqual(intent!.query, "dal makhni")
        XCTAssertEqual(intent!.mealHint, "dinner")
    }

    func test_intent_rotisPlural() {
        // "had 2 rotis" — Indian food, plural singularized
        let intent = AIActionExecutor.parseFoodIntent("had 2 rotis")
        XCTAssertNotNil(intent)
        XCTAssertEqual(intent!.query, "roti")
        XCTAssertEqual(intent!.servings!, 2.0, accuracy: 0.01)
    }

    // MARK: - H: parseFoodIntent — nil cases (3 cases)

    func test_intent_nilForQuestion() {
        // No logging verb or natural prefix → nil
        XCTAssertNil(AIActionExecutor.parseFoodIntent("how many calories today"))
    }

    func test_intent_nilForWeight() {
        // Non-food word "weight" is in the rejection list
        XCTAssertNil(AIActionExecutor.parseFoodIntent("log weight"))
    }

    func test_intent_nilForWorkout() {
        // Non-food word "workout" is in the rejection list
        XCTAssertNil(AIActionExecutor.parseFoodIntent("log a workout"))
    }

    // MARK: - I: parseWeightIntent (6 cases)

    func test_weight_kgIntent() {
        let w = AIActionExecutor.parseWeightIntent("i weigh 74 kg")
        XCTAssertNotNil(w)
        XCTAssertEqual(w!.weightValue, 74.0, accuracy: 0.01)
        XCTAssertEqual(w!.unit, .kg)
    }

    func test_weight_lbsIntent() {
        let w = AIActionExecutor.parseWeightIntent("weight is 165 lbs")
        XCTAssertNotNil(w)
        XCTAssertEqual(w!.weightValue, 165.0, accuracy: 0.01)
        XCTAssertEqual(w!.unit, .lbs)
    }

    func test_weight_weighedInDecimal() {
        let w = AIActionExecutor.parseWeightIntent("weighed in at 72.5 kg")
        XCTAssertNotNil(w)
        XCTAssertEqual(w!.weightValue, 72.5, accuracy: 0.01)
        XCTAssertEqual(w!.unit, .kg)
    }

    func test_weight_scaleSaysDefaultUnit() {
        // No unit in text → uses defaultUnit parameter
        let w = AIActionExecutor.parseWeightIntent("scale says 180", defaultUnit: .lbs)
        XCTAssertNotNil(w)
        XCTAssertEqual(w!.weightValue, 180.0, accuracy: 0.01)
        XCTAssertEqual(w!.unit, .lbs)
    }

    func test_weight_logWeightKg() {
        let w = AIActionExecutor.parseWeightIntent("log weight 85 kg")
        XCTAssertNotNil(w)
        XCTAssertEqual(w!.weightValue, 85.0, accuracy: 0.01)
        XCTAssertEqual(w!.unit, .kg)
    }

    func test_weight_nilForFoodContext() {
        // "chicken weighs" doesn't match any weight-intent trigger
        XCTAssertNil(AIActionExecutor.parseWeightIntent("chicken weighs 200g"))
    }

    // MARK: - J: parseWorkoutExercises (4 cases)

    func test_workout_singleExercise() {
        let ex = AIActionParser.parseWorkoutExercises("Push Ups 3x15")
        XCTAssertEqual(ex.count, 1)
        XCTAssertEqual(ex[0].name, "Push Ups")
        XCTAssertEqual(ex[0].sets, 3)
        XCTAssertEqual(ex[0].reps, 15)
        XCTAssertNil(ex[0].weight)
    }

    func test_workout_exerciseWithWeight() {
        let ex = AIActionParser.parseWorkoutExercises("Bench Press 4x10@135")
        XCTAssertEqual(ex.count, 1)
        XCTAssertEqual(ex[0].name, "Bench Press")
        XCTAssertEqual(ex[0].sets, 4)
        XCTAssertEqual(ex[0].reps, 10)
        XCTAssertEqual(ex[0].weight!, 135.0, accuracy: 0.01)
    }

    func test_workout_multipleExercises() {
        let ex = AIActionParser.parseWorkoutExercises("Push Ups 3x15, Bench Press 3x10@135")
        XCTAssertEqual(ex.count, 2)
        XCTAssertEqual(ex[0].name, "Push Ups")
        XCTAssertNil(ex[0].weight)
        XCTAssertEqual(ex[1].name, "Bench Press")
        XCTAssertEqual(ex[1].weight!, 135.0, accuracy: 0.01)
    }

    func test_workout_heavyLift() {
        let ex = AIActionParser.parseWorkoutExercises("Deadlifts 1x5@225")
        XCTAssertEqual(ex.count, 1)
        XCTAssertEqual(ex[0].name, "Deadlifts")
        XCTAssertEqual(ex[0].sets, 1)
        XCTAssertEqual(ex[0].reps, 5)
        XCTAssertEqual(ex[0].weight!, 225.0, accuracy: 0.01)
    }

    // MARK: - K: Known limits (5 cases)
    // Parser gaps documented with XCTExpectFailure — the test method passes so CI stays green
    // while clearly signalling what needs improvement.

    func test_knownLimit_qualifierPrefix() {
        // KNOWN LIMIT: adverb qualifiers ("approximately", "roughly", "about") are not stripped
        // before the amount; "approximately 100g chicken" returns food="approximately 100g chicken".
        XCTExpectFailure("qualifier adverb not stripped — food name absorbs the qualifier") {
            let intent = AIActionExecutor.parseFoodIntent("log approximately 100g chicken")
            XCTAssertEqual(intent?.gramAmount ?? 0, 100.0, accuracy: 0.01)
            XCTAssertEqual(intent?.query, "chicken")
        }
    }

    func test_knownLimit_timeExpression() {
        // KNOWN LIMIT: time expressions ("this morning", "last night") are not stripped from the
        // food remainder; "oatmeal this morning" surfaces as the food query.
        XCTExpectFailure("time expression not stripped — bleeds into food query") {
            let intent = AIActionExecutor.parseFoodIntent("had oatmeal this morning")
            XCTAssertEqual(intent?.query, "oatmeal")
        }
    }

    func test_knownLimit_bareGramNumber() {
        // KNOWN LIMIT: bare numbers > 10 without an explicit unit are rejected by the >10 guard;
        // "200 rice" loses the gram amount entirely.
        XCTExpectFailure("bare number >10 treated as non-amount without explicit unit") {
            let intent = AIActionExecutor.parseFoodIntent("had 200 rice")
            XCTAssertEqual(intent?.gramAmount ?? 0, 200.0, accuracy: 0.01)
        }
    }

    func test_knownLimit_hyphenatedRange() {
        // KNOWN LIMIT: leading hyphenated range ("2-3") is not split; it falls through as
        // part of the food name instead of being parsed as a serving range.
        XCTExpectFailure("hyphenated range at start not parsed as amount") {
            let (s, _, _) = AIActionExecutor.extractAmount(from: "2-3 chicken pieces")
            XCTAssertNotNil(s)
        }
    }

    func test_knownLimit_fractionPlusVolumeUnit() {
        // KNOWN LIMIT: fraction parser (1/2 → 0.5) fires before the volume-unit converter;
        // "1/2 cup rice" returns servings=0.5 with food="cup rice" instead of gramAmount=120.
        XCTExpectFailure("fraction wins over volume unit — cup stays in food name") {
            let (s, food, g) = AIActionExecutor.extractAmount(from: "1/2 cup rice")
            XCTAssertNil(s)
            XCTAssertEqual(food, "rice")
            XCTAssertEqual(g ?? 0, 120.0, accuracy: 0.01)  // g is nil in current impl; ?? 0 avoids crash
        }
    }
}
