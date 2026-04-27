import XCTest
@testable import DriftCore

/// Tier 0 — pure logic, no LLM, no simulator.
/// Tests the context-aware tie-break logic that resolves ambiguous messages
/// using conversation phase and recent tool history before asking the user. #449.
///
/// Run: `cd DriftCore && swift test --filter IntentContextResolverTests`
final class IntentContextResolverTests: XCTestCase {

    // MARK: - awaitingMealItems phase

    func testAddNumber_InMealPhase_ResolvesToEditMeal() {
        let result = IntentContextResolver.resolve(
            message: "add 50",
            phase: .awaitingMealItems(mealName: "lunch"),
            lastTool: nil,
            lastTopic: .food
        )
        guard case .resolved(let tool, let params) = result else {
            XCTFail("Expected .resolved, got .pass for 'add 50' in meal phase")
            return
        }
        XCTAssertEqual(tool, "edit_meal")
        XCTAssertEqual(params["meal_period"], "lunch")
        XCTAssertEqual(params["action"], "update_quantity")
        XCTAssertEqual(params["new_value"], "50")
    }

    func testAddNumberWithUnit_InMealPhase_ResolvesToEditMeal() {
        let result = IntentContextResolver.resolve(
            message: "add 50g",
            phase: .awaitingMealItems(mealName: "dinner"),
            lastTool: nil,
            lastTopic: .food
        )
        guard case .resolved(let tool, let params) = result else {
            XCTFail("Expected .resolved, got .pass for 'add 50g' in meal phase")
            return
        }
        XCTAssertEqual(tool, "edit_meal")
        XCTAssertEqual(params["new_value"], "50g")
    }

    func testAddNumberWithCalUnit_InMealPhase_ResolvesToEditMeal() {
        let result = IntentContextResolver.resolve(
            message: "add 100 cal",
            phase: .awaitingMealItems(mealName: "breakfast"),
            lastTool: nil,
            lastTopic: .food
        )
        guard case .resolved(let tool, _) = result else {
            XCTFail("Expected .resolved for 'add 100 cal' in meal phase")
            return
        }
        XCTAssertEqual(tool, "edit_meal")
    }

    // MARK: - lastTool context

    func testAddNumber_AfterFoodLog_ResolvesToEditMeal() {
        let result = IntentContextResolver.resolve(
            message: "add 50",
            phase: .idle,
            lastTool: "log_food",
            lastTopic: .food
        )
        guard case .resolved(let tool, let params) = result else {
            XCTFail("Expected .resolved, got .pass for 'add 50' after food log")
            return
        }
        XCTAssertEqual(tool, "edit_meal")
        XCTAssertEqual(params["action"], "update_quantity")
        XCTAssertEqual(params["new_value"], "50")
    }

    func testAddNumber_NoFoodContext_ReturnsPass() {
        let result = IntentContextResolver.resolve(
            message: "add 50",
            phase: .idle,
            lastTool: nil,
            lastTopic: .unknown
        )
        XCTAssertEqual(result, .pass,
            "'add 50' with no food context should not resolve — show clarification card instead")
    }

    func testAddNumber_AfterWeightLog_ReturnsPass() {
        let result = IntentContextResolver.resolve(
            message: "add 50",
            phase: .idle,
            lastTool: "log_weight",
            lastTopic: .weight
        )
        XCTAssertEqual(result, .pass,
            "'add 50' after weight log has no food context — should not resolve")
    }

    // MARK: - Food name after "add" → should NOT resolve (food log, not edit)

    func testAddFoodName_InMealPhase_ReturnsPass() {
        // "add 50 eggs" — the "50" is a quantity for a food, not an edit quantity
        // This should fall through to the normal food-log path.
        let result = IntentContextResolver.resolve(
            message: "add 50 eggs",
            phase: .awaitingMealItems(mealName: "lunch"),
            lastTool: nil,
            lastTopic: .food
        )
        XCTAssertEqual(result, .pass,
            "'add 50 eggs' has a food name — should not be treated as a bare quantity edit")
    }

    func testAddFoodNameOnly_InMealPhase_ReturnsPass() {
        // "add chicken" — starts with "add" but no number
        let result = IntentContextResolver.resolve(
            message: "add chicken",
            phase: .awaitingMealItems(mealName: "dinner"),
            lastTool: nil,
            lastTopic: .food
        )
        XCTAssertEqual(result, .pass,
            "'add chicken' has no quantity token — not an edit, should be handled by meal-build path")
    }

    // MARK: - awaitingExercises phase

    func testExerciseInput_InWorkoutPhase_ResolvesToLogActivity() {
        let result = IntentContextResolver.resolve(
            message: "bench press 3x10 at 135",
            phase: .awaitingExercises,
            lastTool: nil,
            lastTopic: .exercise
        )
        guard case .resolved(let tool, let params) = result else {
            XCTFail("Expected .resolved for exercise input in workout phase")
            return
        }
        XCTAssertEqual(tool, "log_activity")
        XCTAssertEqual(params["name"], "bench press 3x10 at 135")
    }

    func testQuestionInWorkoutPhase_ReturnsPass() {
        // "how many sets?" in workout phase is a question, not an exercise
        let result = IntentContextResolver.resolve(
            message: "how many sets?",
            phase: .awaitingExercises,
            lastTool: nil,
            lastTopic: .exercise
        )
        XCTAssertEqual(result, .pass,
            "Question cue in workout phase should not auto-resolve to log_activity")
    }

    // MARK: - extractAddQuantity unit tests

    func testExtractAddQuantity_BareNumber() {
        XCTAssertEqual(IntentContextResolver.extractAddQuantity("add 50"), "50")
    }

    func testExtractAddQuantity_WithGramUnit() {
        XCTAssertEqual(IntentContextResolver.extractAddQuantity("add 50g"), "50g")
    }

    func testExtractAddQuantity_WithSpaceUnit() {
        XCTAssertEqual(IntentContextResolver.extractAddQuantity("add 50 grams"), "50grams")
    }

    func testExtractAddQuantity_WithCalUnit() {
        XCTAssertEqual(IntentContextResolver.extractAddQuantity("add 100 cal"), "100cal")
    }

    func testExtractAddQuantity_FoodName_ReturnsNil() {
        XCTAssertNil(IntentContextResolver.extractAddQuantity("add 50 eggs"),
            "Should return nil when second token is a food name, not a unit")
    }

    func testExtractAddQuantity_NoBareNumber_ReturnsNil() {
        XCTAssertNil(IntentContextResolver.extractAddQuantity("add chicken"))
    }

    func testExtractAddQuantity_NoPrefix_ReturnsNil() {
        XCTAssertNil(IntentContextResolver.extractAddQuantity("log 50"))
    }

    func testExtractAddQuantity_Plus_Prefix() {
        XCTAssertEqual(IntentContextResolver.extractAddQuantity("plus 30"), "30")
    }
}
