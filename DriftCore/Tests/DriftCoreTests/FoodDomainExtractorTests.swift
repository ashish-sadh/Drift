import XCTest
@testable import DriftCore

/// Tier-0 tests for portion multiplier parsing in AIActionExecutor.extractAmount
/// and parseFoodIntent. No DB, no LLM, deterministic.
///
/// Run: cd DriftCore && swift test --filter FoodDomainExtractorTests
final class FoodDomainExtractorTests: XCTestCase {

    // MARK: - Multiplier keywords

    func testExtractAmount_doubleTheFood() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "double the chicken")
        XCTAssertEqual(servings!, 2.0, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "chicken")
        XCTAssertNil(grams)
    }

    func testExtractAmount_tripleTheFood() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "triple the rice")
        XCTAssertEqual(servings!, 3.0, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "rice")
        XCTAssertNil(grams)
    }

    func testExtractAmount_twiceTheFood() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "twice the salmon")
        XCTAssertEqual(servings!, 2.0, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "salmon")
        XCTAssertNil(grams)
    }

    func testExtractAmount_2xFood() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "2x oats")
        XCTAssertEqual(servings!, 2.0, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "oats")
        XCTAssertNil(grams)
    }

    func testExtractAmount_doubleNoArticle() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "double protein powder")
        XCTAssertEqual(servings!, 2.0, accuracy: 0.01)
        XCTAssertTrue(food.lowercased().contains("protein"))
        XCTAssertNil(grams)
    }

    // MARK: - half a <unit> patterns

    func testExtractAmount_halfACupOfRice() {
        // rice = 185g/cup → 0.5 * 185 = 92.5g (food-aware, was flat 120g)
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "half a cup of rice")
        XCTAssertNil(servings)
        XCTAssertEqual(food.lowercased(), "rice")
        XCTAssertEqual(grams!, 92.5, accuracy: 0.5)
    }

    func testExtractAmount_halfATbspPeanutButter() {
        // peanut butter has no RawIngredient match → flat 15g/tbsp → 7.5g
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "half a tbsp peanut butter")
        XCTAssertNil(servings)
        XCTAssertTrue(food.lowercased().contains("peanut butter"))
        XCTAssertEqual(grams!, 7.5, accuracy: 0.01)
    }

    func testExtractAmount_halfATspHoney() {
        // honey = 340g/cup → 340/48 ≈ 7.08g/tsp → 0.5 * 7.08 ≈ 3.54g (food-aware, was flat 2.5g)
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "half a tsp honey")
        XCTAssertNil(servings)
        XCTAssertEqual(food.lowercased(), "honey")
        XCTAssertEqual(grams!, 340.0 / 48 * 0.5, accuracy: 0.5)
    }

    // MARK: - Fractional servings passthrough (already worked, regression guard)

    func testExtractAmount_oneAndHalfServingsOfOatmeal() {
        let (servings, food, grams) = AIActionExecutor.extractAmount(from: "1.5 servings of oatmeal")
        XCTAssertEqual(servings!, 1.5, accuracy: 0.01)
        XCTAssertEqual(food.lowercased(), "oatmeal")
        XCTAssertNil(grams)
    }

    // MARK: - parseFoodIntent integration

    func testParseFoodIntent_doubleTheChicken() {
        let intent = AIActionExecutor.parseFoodIntent("log double the chicken")
        XCTAssertNotNil(intent)
        XCTAssertEqual(intent!.servings!, 2.0, accuracy: 0.01)
        XCTAssertTrue(intent!.query.lowercased().contains("chicken"))
    }

    func testParseFoodIntent_tripleRice() {
        let intent = AIActionExecutor.parseFoodIntent("ate triple the rice")
        XCTAssertNotNil(intent)
        XCTAssertEqual(intent!.servings!, 3.0, accuracy: 0.01)
        XCTAssertTrue(intent!.query.lowercased().contains("rice"))
    }

    func testParseFoodIntent_oneAndHalfServingsOatmeal() {
        let intent = AIActionExecutor.parseFoodIntent("log 1.5 servings of oatmeal")
        XCTAssertNotNil(intent)
        XCTAssertEqual(intent!.servings!, 1.5, accuracy: 0.01)
        XCTAssertTrue(intent!.query.lowercased().contains("oatmeal"))
    }

    func testParseFoodIntent_halfACupMilk() {
        let intent = AIActionExecutor.parseFoodIntent("had half a cup of milk")
        XCTAssertNotNil(intent)
        XCTAssertNil(intent!.servings)
        XCTAssertEqual(intent!.gramAmount!, 122.0, accuracy: 0.5)
        XCTAssertTrue(intent!.query.lowercased().contains("milk"))
    }
}
