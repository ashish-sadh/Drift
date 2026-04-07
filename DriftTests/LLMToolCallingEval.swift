import XCTest
@testable import Drift

/// Evaluates whether Qwen2.5-1.5B can reliably select the right tool from a schema list.
/// Loads the actual model and runs 100 queries. Takes ~25 min.
/// Run: xcodebuild test -only-testing:'DriftTests/LLMToolCallingEval'
final class LLMToolCallingEval: XCTestCase {

    nonisolated(unsafe) static var backend: LlamaCppBackend?

    override class func setUp() {
        super.setUp()
        let path = URL(fileURLWithPath: "/tmp/qwen2.5-1.5b-instruct-q4_k_m.gguf")
        guard FileManager.default.fileExists(atPath: path.path) else {
            print("⚠️ Model not found at /tmp/ — skipping LLM eval")
            return
        }
        let b = LlamaCppBackend(modelPath: path)
        try? b.loadSync()
        backend = b
        print("✅ Model loaded for tool-calling eval")
    }

    // MARK: - System Prompt

    private func systemPrompt(screen: String) -> String {
        // Exactly what the app sends — tools filtered by screen
        let allTools: [(name: String, params: String, desc: String)] = [
            ("log_food", "name:string, amount:number", "Log a food entry"),
            ("get_nutrition", "name:string", "Look up nutrition for a food"),
            ("get_calories_left", "", "Show remaining calories and protein"),
            ("suggest_meal", "", "Suggest foods that fit remaining budget"),
            ("top_protein", "", "Show top high-protein foods"),
            ("explain_calories", "", "Explain calorie math: TDEE, deficit, target"),
            ("log_weight", "value:number, unit:string", "Log a body weight entry"),
            ("get_trend", "", "Show weight trend: current, rate, direction"),
            ("get_goal", "", "Show goal progress"),
            ("get_body_composition", "", "Show body fat %, BMI, water %"),
            ("start_template", "name:string", "Start a workout from saved template"),
            ("build_smart_session", "muscle_group:string", "Build a workout (max 5 exercises)"),
            ("suggest_workout", "", "Suggest what to train based on history"),
            ("progressive_overload", "exercise:string", "Check progress on an exercise"),
            ("get_sleep", "", "Show last night's sleep data"),
            ("get_recovery", "", "Show recovery score, HRV, resting HR"),
            ("get_readiness", "", "Assess training readiness"),
            ("get_supplement_status", "", "Check supplement status"),
        ]

        // Screen-filter: put relevant tools first, limit to 6
        let screenService: String? = switch screen {
        case "food": "food"
        case "weight": "weight"
        case "exercise": "exercise"
        default: nil
        }

        let sorted = allTools.sorted { a, b in
            let aMatch = screenService != nil && a.name.contains(screenService!)
            let bMatch = screenService != nil && b.name.contains(screenService!)
            if aMatch && !bMatch { return true }
            if !aMatch && bMatch { return false }
            return false
        }

        let toolLines = sorted.prefix(8).map { "- \($0.name)(\($0.params)) — \($0.desc)" }

        return """
        You help with food, weight, and workout tracking. Rules: \
        1) Use ONLY the numbers from context. Never invent data. \
        2) When user wants to LOG something, call a tool: {"tool":"log_food","params":{"name":"eggs","amount":"2"}} \
        3) When user asks a QUESTION about their data, call a tool: {"tool":"get_calories_left","params":{}} \
        4) When user just TALKS, respond naturally in 1-2 sentences. No tool call needed. \
        5) Do NOT give health/medical advice. Show their data instead. \
        6) If unsure what user wants, ask ONE question. \
        Example: "I had eggs" → {"tool":"log_food","params":{"name":"eggs"}} \
        Example: "how many calories left" → {"tool":"get_calories_left","params":{}} \
        Example: "start push day" → {"tool":"start_template","params":{"name":"push day"}} \
        Example: "what should I train" → {"tool":"suggest_workout","params":{}} \
        Example: "build me a chest workout" → {"tool":"build_smart_session","params":{"muscle_group":"chest"}} \
        Example: "thanks" → Just say "You're welcome!" (no tool call) \
        Tools:\n\(toolLines.joined(separator: "\n"))
        """
    }

    private func context() -> String {
        "Calories: 1200 eaten, 1800 target, 600 remaining\nMacros: 80P 150C 40F\nWeight: 165 lbs, -0.8/wk"
    }

    // MARK: - Test Runner

    private func runQuery(_ query: String, screen: String = "dashboard", expectedTool: String?) async -> (response: String, tool: String?, correct: Bool) {
        guard let backend = Self.backend else { return ("skipped", nil, false) }

        let prompt = "Context about the user:\n\(context())\n\nUser: \(query)"
        let response = await backend.respond(to: prompt, systemPrompt: systemPrompt(screen: screen))

        let call = parseToolCallJSON(response)
        let actualTool = call?.tool

        let correct: Bool
        if let expected = expectedTool {
            correct = actualTool == expected
        } else {
            // Expected no tool call
            correct = actualTool == nil
        }

        return (response, actualTool, correct)
    }

    // MARK: - Food Logging (30)

    func testFoodLogging() async throws {
        guard Self.backend != nil else { throw XCTSkip("Model not available") }

        let queries: [(String, String)] = [
            ("I had 2 eggs", "log_food"),
            ("log chicken breast", "log_food"),
            ("ate a banana for lunch", "log_food"),
            ("had dal and rice", "log_food"),
            ("log a protein shake", "log_food"),
            ("I just had a samosa", "log_food"),
            ("ate 3 rotis for dinner", "log_food"),
            ("log oatmeal for breakfast", "log_food"),
            ("had a bowl of soup", "log_food"),
            ("I drank a coffee", "log_food"),
            ("ate pizza last night", "log_food"),
            ("log paneer butter masala", "log_food"),
            ("had a sandwich and chips", "log_food"),
            ("log a cup of rice", "log_food"),
            ("I made pasta for dinner", "log_food"),
            ("ate a couple of eggs", "log_food"),
            ("had biryani for lunch", "log_food"),
            ("log half an avocado", "log_food"),
            ("I had toast with butter", "log_food"),
            ("drank a glass of milk", "log_food"),
        ]

        var correct = 0
        for (query, expected) in queries {
            let result = await runQuery(query, screen: "food", expectedTool: expected)
            if result.correct { correct += 1 }
            else { print("❌ FOOD LOG: '\(query)' → tool=\(result.tool ?? "none") response=\(result.response.prefix(80))") }
        }

        let pct = Double(correct) / Double(queries.count) * 100
        print("📊 Food Logging: \(correct)/\(queries.count) (\(String(format: "%.0f", pct))%)")
        XCTAssertGreaterThanOrEqual(correct, 10, "Food logging: \(correct)/\(queries.count)")
    }

    // MARK: - Food Understanding (15)

    func testFoodUnderstanding() async throws {
        guard Self.backend != nil else { throw XCTSkip("Model not available") }

        let queries: [(String, String)] = [
            ("calories left?", "get_calories_left"),
            ("how much protein in banana", "get_nutrition"),
            ("what should I eat for dinner", "suggest_meal"),
            ("calories in a samosa", "get_nutrition"),
            ("how many carbs in rice", "get_nutrition"),
            ("suggest something high protein", "suggest_meal"),
            ("what are good protein sources", "top_protein"),
            ("explain my calories", "explain_calories"),
            ("am I eating too much", "get_calories_left"),
            ("what did I eat today", "get_calories_left"),
            ("I'm hungry what should I have", "suggest_meal"),
            ("how's my protein intake", "get_calories_left"),
            ("nutrition info for chicken", "get_nutrition"),
            ("I need to eat more fiber", "suggest_meal"),
            ("is my diet balanced", "get_calories_left"),
        ]

        var correct = 0
        for (query, expected) in queries {
            let result = await runQuery(query, screen: "food", expectedTool: expected)
            if result.correct { correct += 1 }
            else { print("❌ FOOD Q: '\(query)' → tool=\(result.tool ?? "none")") }
        }

        let pct = Double(correct) / Double(queries.count) * 100
        print("📊 Food Understanding: \(correct)/\(queries.count) (\(String(format: "%.0f", pct))%)")
        XCTAssertGreaterThanOrEqual(correct, 5, "Food understanding: \(correct)/\(queries.count)")
    }

    // MARK: - Weight (15)

    func testWeightQueries() async throws {
        guard Self.backend != nil else { throw XCTSkip("Model not available") }

        let queries: [(String, String)] = [
            ("I weigh 165 lbs", "log_weight"),
            ("my weight is 75 kg", "log_weight"),
            ("how's my weight trend", "get_trend"),
            ("am I on track to reach my goal", "get_goal"),
            ("how much have I lost this month", "get_trend"),
            ("show my weight history", "get_trend"),
            ("what's my body fat", "get_body_composition"),
            ("what's my BMI", "get_body_composition"),
            ("am I losing weight", "get_trend"),
            ("scale says 170 today", "log_weight"),
            ("how fast am I losing", "get_trend"),
            ("what's my goal progress", "get_goal"),
            ("weighed in at 80 kg", "log_weight"),
            ("when will I reach my target", "get_goal"),
            ("my weight is going up why", "get_trend"),
        ]

        var correct = 0
        for (query, expected) in queries {
            let result = await runQuery(query, screen: "weight", expectedTool: expected)
            if result.correct { correct += 1 }
            else { print("❌ WEIGHT: '\(query)' → tool=\(result.tool ?? "none")") }
        }

        let pct = Double(correct) / Double(queries.count) * 100
        print("📊 Weight: \(correct)/\(queries.count) (\(String(format: "%.0f", pct))%)")
        XCTAssertGreaterThanOrEqual(correct, 5, "Weight: \(correct)/\(queries.count)")
    }

    // MARK: - Exercise Coach (25)

    func testExerciseCoach() async throws {
        guard Self.backend != nil else { throw XCTSkip("Model not available") }

        let queries: [(String, String)] = [
            ("what should I train today", "suggest_workout"),
            ("start push day", "start_template"),
            ("start chest workout", "build_smart_session"),
            ("I want to do legs today", "build_smart_session"),
            ("build me a back workout", "build_smart_session"),
            ("suggest a shoulder routine", "build_smart_session"),
            ("what muscle haven't I trained", "suggest_workout"),
            ("how many workouts this week", "suggest_workout"),
            ("start a full body session", "build_smart_session"),
            ("am I making progress on bench", "progressive_overload"),
            ("am I getting stronger on squats", "progressive_overload"),
            ("start pull day", "start_template"),
            ("give me a quick arm workout", "build_smart_session"),
            ("I want to work out", "suggest_workout"),
            ("start leg day", "start_template"),
            ("build me a PPL split", "build_smart_session"),
            ("what did I train last", "suggest_workout"),
            ("coach me through a workout", "build_smart_session"),
            ("is my bench press improving", "progressive_overload"),
            ("suggest exercises for core", "build_smart_session"),
            ("start my usual workout", "start_template"),
            ("how's my training volume", "suggest_workout"),
            ("plan a hypertrophy session", "build_smart_session"),
        ]

        var correct = 0
        for (query, expected) in queries {
            let result = await runQuery(query, screen: "exercise", expectedTool: expected)
            if result.correct { correct += 1 }
            else { print("❌ EXERCISE: '\(query)' → tool=\(result.tool ?? "none")") }
        }

        let pct = Double(correct) / Double(queries.count) * 100
        print("📊 Exercise Coach: \(correct)/\(queries.count) (\(String(format: "%.0f", pct))%)")
        XCTAssertGreaterThanOrEqual(correct, 8, "Exercise: \(correct)/\(queries.count)")
    }

    // MARK: - Sleep & Recovery (10)

    func testSleepRecovery() async throws {
        guard Self.backend != nil else { throw XCTSkip("Model not available") }

        let queries: [(String, String)] = [
            ("how'd I sleep last night", "get_sleep"),
            ("what's my recovery score", "get_recovery"),
            ("should I train today or rest", "get_readiness"),
            ("I'm feeling tired", "get_sleep"),
            ("what's my HRV", "get_recovery"),
            ("am I recovered enough", "get_readiness"),
            ("how's my resting heart rate", "get_recovery"),
            ("I feel exhausted", "get_sleep"),
            ("did I sleep well", "get_sleep"),
            ("is my recovery good enough to lift", "get_readiness"),
        ]

        var correct = 0
        for (query, expected) in queries {
            let result = await runQuery(query, screen: "dashboard", expectedTool: expected)
            if result.correct { correct += 1 }
            else { print("❌ SLEEP: '\(query)' → tool=\(result.tool ?? "none")") }
        }

        let pct = Double(correct) / Double(queries.count) * 100
        print("📊 Sleep & Recovery: \(correct)/\(queries.count) (\(String(format: "%.0f", pct))%)")
        XCTAssertGreaterThanOrEqual(correct, 4, "Sleep: \(correct)/\(queries.count)")
    }

    // MARK: - No Tool Expected (15)

    func testNoToolExpected() async throws {
        guard Self.backend != nil else { throw XCTSkip("Model not available") }

        let queries: [(String, String?)] = [
            ("thanks!", nil),
            ("hello", nil),
            ("ok got it", nil),
            ("what can you do", nil),
            ("nice", nil),
            ("you're helpful", nil),
            ("what is a macro", nil),
            ("tell me about creatine", nil),
            ("what's a good heart rate", nil),
            ("how do I lose belly fat", nil),
            ("is keto good", nil),
        ]

        var correct = 0
        for (query, expected) in queries {
            let result = await runQuery(query, expectedTool: expected)
            if result.correct { correct += 1 }
            else { print("❌ NO-TOOL: '\(query)' → tool=\(result.tool ?? "none") (expected none)") }
        }

        let pct = Double(correct) / Double(queries.count) * 100
        print("📊 No Tool (should be natural): \(correct)/\(queries.count) (\(String(format: "%.0f", pct))%)")
        XCTAssertGreaterThanOrEqual(correct, 5, "No-tool: \(correct)/\(queries.count)")
    }

    // MARK: - Ambiguous / Tricky (5)

    func testAmbiguousQueries() async throws {
        guard Self.backend != nil else { throw XCTSkip("Model not available") }

        let queries: [(String, String)] = [
            ("log exercise", "suggest_workout"),
            ("log a workout", "suggest_workout"),
            ("did I take my vitamins", "get_supplement_status"),
            ("what supplements should I take", "get_supplement_status"),
        ]

        var correct = 0
        for (query, expected) in queries {
            let result = await runQuery(query, expectedTool: expected)
            if result.correct { correct += 1 }
            else { print("❌ AMBIGUOUS: '\(query)' → tool=\(result.tool ?? "none") expected=\(expected)") }
        }

        print("📊 Ambiguous: \(correct)/\(queries.count)")
    }

    // MARK: - Summary

    func testPrintSummary() {
        print("""
        ═══════════════════════════════════
        LLM TOOL-CALLING EVAL COMPLETE
        Run individual test methods for category breakdowns.
        ═══════════════════════════════════
        """)
    }
}
