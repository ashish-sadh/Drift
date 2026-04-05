import Foundation
import Testing
@testable import Drift

// MARK: - AIActionParser Tests

@Test func aiParseLogFood() async throws {
    let (action, clean) = AIActionParser.parse("Sure! [LOG_FOOD: chicken breast 200g] Let me know if you need more.")
    if case .logFood(let name, let amount) = action {
        #expect(name == "chicken breast")
        #expect(amount == "200g")
    } else {
        #expect(Bool(false), "Expected logFood action")
    }
    #expect(clean.contains("Sure!"))
    #expect(!clean.contains("[LOG_FOOD"))
}

@Test func aiParseStartWorkout() async throws {
    let (action, clean) = AIActionParser.parse("Let's go! [START_WORKOUT: legs]")
    if case .startWorkout(let type) = action {
        #expect(type == "legs")
    } else {
        #expect(Bool(false), "Expected startWorkout action")
    }
    #expect(clean == "Let's go!")
}

@Test func aiParseNoAction() async throws {
    let (action, clean) = AIActionParser.parse("You're doing great! Keep it up.")
    if case .none = action {
        // Expected
    } else {
        #expect(Bool(false), "Expected no action")
    }
    #expect(clean == "You're doing great! Keep it up.")
}

@Test func aiParseFoodWithoutAmount() async throws {
    let (action, _) = AIActionParser.parse("[LOG_FOOD: banana]")
    if case .logFood(let name, let amount) = action {
        #expect(name == "banana")
        #expect(amount == nil)
    } else {
        #expect(Bool(false), "Expected logFood")
    }
}

@Test func aiParseFoodWithServings() async throws {
    let (action, _) = AIActionParser.parse("[LOG_FOOD: oatmeal 1 cup]")
    if case .logFood(let name, let amount) = action {
        #expect(name == "oatmeal")
        #expect(amount == "1 cup")
    } else {
        #expect(Bool(false), "Expected logFood")
    }
}

// MARK: - AIContextBuilder Tests

@Test func aiContextBuilderReturnsString() async throws {
    let context = AIContextBuilder.buildContext()
    #expect(!context.isEmpty, "Context should not be empty")
    // On test DB, should at least say "No food logged today"
    #expect(context.contains("food") || context.contains("No"))
}
