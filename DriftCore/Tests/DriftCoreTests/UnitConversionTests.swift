import XCTest
@testable import DriftCore

/// Tier-0 tests for unit conversion in AIActionExecutor.normalizeToGrams
/// and ServingUnit.toGrams. No DB, no LLM, deterministic.
///
/// Run: cd DriftCore && swift test --filter UnitConversionTests
final class UnitConversionTests: XCTestCase {

    // MARK: - normalizeToGrams

    func testNormalizeToGrams_oz() {
        let result = AIActionExecutor.normalizeToGrams(2, unit: "oz")
        XCTAssertEqual(result!, 56.699, accuracy: 0.01)
    }

    func testNormalizeToGrams_kg() {
        XCTAssertEqual(AIActionExecutor.normalizeToGrams(1, unit: "kg")!, 1000, accuracy: 0.01)
        XCTAssertEqual(AIActionExecutor.normalizeToGrams(0.5, unit: "kg")!, 500, accuracy: 0.01)
    }

    func testNormalizeToGrams_cup() {
        XCTAssertEqual(AIActionExecutor.normalizeToGrams(1, unit: "cup")!, 240, accuracy: 0.01)
        XCTAssertEqual(AIActionExecutor.normalizeToGrams(2, unit: "cups")!, 480, accuracy: 0.01)
    }

    func testNormalizeToGrams_tbsp() {
        XCTAssertEqual(AIActionExecutor.normalizeToGrams(1, unit: "tbsp")!, 15, accuracy: 0.01)
        XCTAssertEqual(AIActionExecutor.normalizeToGrams(2, unit: "tbsp")!, 30, accuracy: 0.01)
    }

    func testNormalizeToGrams_tsp() {
        XCTAssertEqual(AIActionExecutor.normalizeToGrams(1, unit: "tsp")!, 5, accuracy: 0.01)
    }

    func testNormalizeToGrams_grams_passThrough() {
        XCTAssertEqual(AIActionExecutor.normalizeToGrams(200, unit: "g")!, 200, accuracy: 0.01)
        XCTAssertEqual(AIActionExecutor.normalizeToGrams(100, unit: "gram")!, 100, accuracy: 0.01)
        XCTAssertEqual(AIActionExecutor.normalizeToGrams(50, unit: "grams")!, 50, accuracy: 0.01)
    }

    func testNormalizeToGrams_ml_passThrough() {
        XCTAssertEqual(AIActionExecutor.normalizeToGrams(240, unit: "ml")!, 240, accuracy: 0.01)
    }

    func testNormalizeToGrams_countUnits_returnsNil() {
        XCTAssertNil(AIActionExecutor.normalizeToGrams(1, unit: "scoop"))
        XCTAssertNil(AIActionExecutor.normalizeToGrams(1, unit: "piece"))
        XCTAssertNil(AIActionExecutor.normalizeToGrams(1, unit: "serving"))
        XCTAssertNil(AIActionExecutor.normalizeToGrams(1, unit: "slice"))
    }

    // MARK: - extractAmount unit conversion

    func testExtractAmount_oz_convertsToGrams() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "2 oz chicken")
        XCTAssertNil(servings)
        XCTAssertEqual(food.lowercased(), "chicken")
        XCTAssertEqual(grams!, 56.699, accuracy: 0.01)
    }

    func testExtractAmount_cup_convertsToGrams() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "1 cup oats")
        XCTAssertNil(servings)
        XCTAssertEqual(food.lowercased(), "oats")
        XCTAssertEqual(grams!, 240, accuracy: 0.01)
    }

    func testExtractAmount_tbsp_convertsToGrams() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "1 tbsp peanut butter")
        XCTAssertNil(servings)
        XCTAssertTrue(food.lowercased().contains("peanut butter"))
        XCTAssertEqual(grams!, 15, accuracy: 0.01)
    }

    func testExtractAmount_tsp_convertsToGrams() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "2 tsp honey")
        XCTAssertNil(servings)
        XCTAssertEqual(food.lowercased(), "honey")
        XCTAssertEqual(grams!, 10, accuracy: 0.01)
    }

    func testExtractAmount_kg_convertsToGrams() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "0.5 kg rice")
        XCTAssertNil(servings)
        XCTAssertEqual(food.lowercased(), "rice")
        XCTAssertEqual(grams!, 500, accuracy: 0.01)
    }

    func testExtractAmount_scoop_remainsServings() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "2 scoops protein powder")
        XCTAssertEqual(servings!, 2, accuracy: 0.01)
        XCTAssertTrue(food.lowercased().contains("protein"))
        XCTAssertNil(grams)
    }

    func testExtractAmount_halfCup_convertsToGrams() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "half cup milk")
        XCTAssertNil(servings)
        XCTAssertEqual(food.lowercased(), "milk")
        XCTAssertEqual(grams!, 120, accuracy: 0.01)
    }

    func testExtractAmount_twoCups_convertsToGrams() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "2 cups oatmeal")
        XCTAssertNil(servings)
        XCTAssertEqual(food.lowercased(), "oatmeal")
        XCTAssertEqual(grams!, 480, accuracy: 0.01)
    }

    // MARK: - ServingUnit.ounces

    func testServingUnit_ounces_toGramsIngredient() {
        let result = ServingUnit.ounces.toGrams(2, ingredient: .chicken_raw)
        XCTAssertEqual(result, 56.699, accuracy: 0.01)
    }

    func testServingUnit_ounces_toGramsFoodServingSize() {
        let result = ServingUnit.ounces.toGrams(3, foodServingSize: 100)
        XCTAssertEqual(result, 85.0485, accuracy: 0.01)
    }

    func testServingUnit_ounces_label() {
        XCTAssertEqual(ServingUnit.ounces.label, "oz")
    }
}
