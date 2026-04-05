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

@Test @MainActor func aiContextBuilderReturnsString() async throws {
    let context = AIContextBuilder.buildContext()
    #expect(!context.isEmpty, "Context should not be empty")
    #expect(context.contains("food") || context.contains("No") || context.contains("Target"))
}

// MARK: - AIRuleEngine Tests

@Test @MainActor func aiRuleEngineDailySummary() async throws {
    let summary = AIRuleEngine.dailySummary()
    #expect(summary.contains("Here's your day"), "Should start with day summary header")
}

@Test @MainActor func aiRuleEngineYesterdaySummary() async throws {
    let summary = AIRuleEngine.yesterdaySummary()
    #expect(!summary.isEmpty, "Yesterday summary should not be empty")
}

@Test @MainActor func aiRuleEngineQuickInsight() async throws {
    let insight = AIRuleEngine.quickInsight()
    if let insight {
        #expect(!insight.isEmpty)
    }
}

// MARK: - More AIActionParser Tests

@Test func aiParseShowWeight() async throws {
    let (action, _) = AIActionParser.parse("Here's your weight. [SHOW_WEIGHT]")
    if case .showWeight = action {
        // Expected
    } else {
        #expect(Bool(false), "Expected showWeight action")
    }
}

// MARK: - AIActionExecutor Tests

@Test func aiExecutorParseFoodLog() async throws {
    let intent = AIActionExecutor.parseFoodIntent("log 2 eggs")
    #expect(intent != nil)
    #expect(intent?.query == "eggs")
    #expect(intent?.servings == 2)
}

@Test func aiExecutorParseFoodFraction() async throws {
    let intent = AIActionExecutor.parseFoodIntent("ate 1/3 avocado")
    #expect(intent != nil)
    #expect(intent?.query == "avocado")
    #expect(intent?.servings != nil)
    #expect(abs((intent?.servings ?? 0) - 0.333) < 0.01)
}

@Test func aiExecutorParseFoodNoAmount() async throws {
    let intent = AIActionExecutor.parseFoodIntent("had chicken breast")
    #expect(intent != nil)
    #expect(intent?.query == "chicken breast")
    #expect(intent?.servings == nil)
}

@Test func aiExecutorParseFoodHalf() async throws {
    let intent = AIActionExecutor.parseFoodIntent("log half avocado")
    #expect(intent != nil)
    #expect(intent?.servings == 0.5)
}

@Test func aiExecutorNoFoodIntent() async throws {
    let intent = AIActionExecutor.parseFoodIntent("how many calories today")
    #expect(intent == nil)
}

@Test func aiExecutorParseWeight() async throws {
    let intent = AIActionExecutor.parseWeightIntent("I weigh 165 lbs")
    #expect(intent != nil)
    #expect(intent?.weightValue == 165)
    #expect(intent?.unit == .lbs)
}

@Test func aiExecutorParseWeightKg() async throws {
    let intent = AIActionExecutor.parseWeightIntent("weight is 75.2 kg")
    #expect(intent != nil)
    #expect(intent?.weightValue == 75.2)
    #expect(intent?.unit == .kg)
}

@Test func aiParseMultipleActionsFirstWins() async throws {
    // If response has multiple actions, first one should be extracted
    let (action, _) = AIActionParser.parse("[LOG_FOOD: rice] and [START_WORKOUT: push]")
    if case .logFood(let name, _) = action {
        #expect(name == "rice")
    } else {
        #expect(Bool(false), "Expected logFood (first action)")
    }
}
