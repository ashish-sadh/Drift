import XCTest
@testable import Drift

/// Isolated gold set for IntentClassifier — sprint task #161.
/// Tests deterministic JSON parsing (parseResponse/mapResponse) and StaticOverrides routing.
/// Fully deterministic: no LLM, no network. Runs in <5s.
///
/// Run: xcodebuild test -only-testing:'DriftTests/IntentClassifierGoldSetTests'
final class IntentClassifierGoldSetTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            if ToolRegistry.shared.allTools().isEmpty {
                ToolRegistration.registerAll()
            }
        }
    }

    // MARK: - parseResponse: Tool Call Parsing

    func testParseResponse_FoodLogging() {
        let cases: [(json: String, tool: String, param: String, value: String)] = [
            (#"{"tool":"log_food","name":"egg","servings":"2"}"#, "log_food", "name", "egg"),
            (#"{"tool":"log_food","name":"biryani"}"#, "log_food", "name", "biryani"),
            (#"{"tool":"log_food","name":"paneer tikka masala","servings":"1"}"#, "log_food", "name", "paneer tikka masala"),
            (#"{"tool":"log_food","name":"chipotle bowl","calories":"800","protein":"40","carbs":"90","fat":"20"}"#, "log_food", "name", "chipotle bowl"),
            (#"{"tool":"log_food","name":"dal","servings":"1"}"#, "log_food", "name", "dal"),
        ]
        var correct = 0
        for (json, expectedTool, param, expectedValue) in cases {
            guard let intent = IntentClassifier.parseResponse(json) else {
                print("MISS (parseResponse log_food): \(json)")
                continue
            }
            if intent.tool == expectedTool && intent.params[param] == expectedValue {
                correct += 1
            } else {
                print("WRONG (log_food): got tool=\(intent.tool) \(param)=\(intent.params[param] ?? "nil"), expected tool=\(expectedTool) \(param)=\(expectedValue)")
            }
        }
        print("📊 parseResponse food logging: \(correct)/\(cases.count)")
        XCTAssertEqual(correct, cases.count, "All log_food JSON should parse correctly")
    }

    func testParseResponse_FoodInfo() {
        let cases: [(json: String, expectedQuery: String)] = [
            (#"{"tool":"food_info","query":"daily summary"}"#, "daily summary"),
            (#"{"tool":"food_info","query":"calories left"}"#, "calories left"),
            (#"{"tool":"food_info","query":"calories in samosa"}"#, "calories in samosa"),
            (#"{"tool":"food_info","query":"weekly summary"}"#, "weekly summary"),
            (#"{"tool":"food_info","query":"protein"}"#, "protein"),
        ]
        var correct = 0
        for (json, expectedQuery) in cases {
            guard let intent = IntentClassifier.parseResponse(json) else {
                print("MISS (parseResponse food_info): \(json)")
                continue
            }
            if intent.tool == "food_info" && intent.params["query"] == expectedQuery {
                correct += 1
            } else {
                print("WRONG (food_info): got tool=\(intent.tool) query=\(intent.params["query"] ?? "nil"), expected query=\(expectedQuery)")
            }
        }
        print("📊 parseResponse food_info: \(correct)/\(cases.count)")
        XCTAssertEqual(correct, cases.count, "All food_info JSON should parse correctly")
    }

    func testParseResponse_WeightAndExercise() {
        let cases: [(json: String, tool: String)] = [
            (#"{"tool":"log_weight","value":"75","unit":"kg"}"#, "log_weight"),
            (#"{"tool":"weight_info","query":"goal progress"}"#, "weight_info"),
            (#"{"tool":"start_workout","name":"push day"}"#, "start_workout"),
            (#"{"tool":"log_activity","name":"yoga","duration":"30"}"#, "log_activity"),
            (#"{"tool":"exercise_info","query":"muscle recovery"}"#, "exercise_info"),
        ]
        var correct = 0
        for (json, expectedTool) in cases {
            guard let intent = IntentClassifier.parseResponse(json) else {
                print("MISS (parseResponse weight/exercise): \(json)")
                continue
            }
            if intent.tool == expectedTool { correct += 1 }
            else { print("WRONG: got \(intent.tool), expected \(expectedTool)") }
        }
        print("📊 parseResponse weight/exercise: \(correct)/\(cases.count)")
        XCTAssertEqual(correct, cases.count)
    }

    func testParseResponse_HealthDomains() {
        let cases: [(json: String, tool: String)] = [
            (#"{"tool":"sleep_recovery"}"#, "sleep_recovery"),
            (#"{"tool":"sleep_recovery","query":"hrv"}"#, "sleep_recovery"),
            (#"{"tool":"mark_supplement","name":"vitamin d"}"#, "mark_supplement"),
            (#"{"tool":"supplements"}"#, "supplements"),
            (#"{"tool":"body_comp"}"#, "body_comp"),
            (#"{"tool":"glucose"}"#, "glucose"),
            (#"{"tool":"biomarkers"}"#, "biomarkers"),
        ]
        var correct = 0
        for (json, expectedTool) in cases {
            guard let intent = IntentClassifier.parseResponse(json) else {
                print("MISS (parseResponse health): \(json)")
                continue
            }
            if intent.tool == expectedTool { correct += 1 }
            else { print("WRONG: got \(intent.tool), expected \(expectedTool)") }
        }
        print("📊 parseResponse health domains: \(correct)/\(cases.count)")
        XCTAssertEqual(correct, cases.count)
    }

    func testParseResponse_NavigationAndGoals() {
        let cases: [(json: String, tool: String, screen: String?)] = [
            (#"{"tool":"navigate_to","screen":"weight"}"#, "navigate_to", "weight"),
            (#"{"tool":"navigate_to","screen":"food"}"#, "navigate_to", "food"),
            (#"{"tool":"navigate_to","screen":"exercise"}"#, "navigate_to", "exercise"),
            (#"{"tool":"set_goal","target":"160","unit":"lbs"}"#, "set_goal", nil),
            (#"{"tool":"delete_food"}"#, "delete_food", nil),
        ]
        var correct = 0
        for (json, expectedTool, expectedScreen) in cases {
            guard let intent = IntentClassifier.parseResponse(json) else {
                print("MISS (parseResponse nav/goals): \(json)")
                continue
            }
            let toolOK = intent.tool == expectedTool
            let screenOK = expectedScreen == nil || intent.params["screen"] == expectedScreen
            if toolOK && screenOK { correct += 1 }
            else { print("WRONG: got tool=\(intent.tool) screen=\(intent.params["screen"] ?? "nil")") }
        }
        print("📊 parseResponse navigation/goals: \(correct)/\(cases.count)")
        XCTAssertEqual(correct, cases.count)
    }

    // MARK: - mapResponse: Text vs Tool Call

    func testMapResponse_ToolCallDetection() {
        let toolJSON = #"{"tool":"log_food","name":"rice"}"#
        guard case .toolCall(let intent) = IntentClassifier.mapResponse(toolJSON) else {
            XCTFail("Valid JSON tool call should return .toolCall")
            return
        }
        XCTAssertEqual(intent.tool, "log_food")
        XCTAssertEqual(intent.params["name"], "rice")
    }

    func testMapResponse_TextDetection() {
        let textResponse = "What did you have for lunch?"
        guard case .text(let text) = IntentClassifier.mapResponse(textResponse) else {
            XCTFail("Text response should return .text")
            return
        }
        XCTAssertFalse(text.isEmpty)
    }

    func testMapResponse_NilOnEmpty() {
        XCTAssertNil(IntentClassifier.mapResponse(nil))
        XCTAssertNil(IntentClassifier.mapResponse(""))
        XCTAssertNil(IntentClassifier.mapResponse("   "))
    }

    func testMapResponse_MalformedJSON() {
        // Missing tool key → should return nil or .text, never crash
        let noTool = #"{"name":"rice"}"#
        let result = IntentClassifier.mapResponse(noTool)
        // Either nil or .text is acceptable — just must not crash or return .toolCall
        if case .toolCall = result {
            XCTFail("JSON without 'tool' key should not produce a toolCall")
        }
    }

    // MARK: - StaticOverrides Routing Gold Set

    @MainActor
    func testStaticOverrides_Greetings() {
        let greetings = ["hi", "hello", "hey", "yo"]
        for query in greetings {
            guard let result = StaticOverrides.match(query) else {
                XCTFail("Greeting '\(query)' should be caught by StaticOverrides")
                continue
            }
            if case .response = result { /* pass */ }
            else { XCTFail("Greeting '\(query)' should return .response") }
        }
    }

    @MainActor
    func testStaticOverrides_Navigation() {
        let navQueries = [
            "show me my weight chart",
            "go to food tab",
            "open exercise",
        ]
        var navigated = 0
        for query in navQueries {
            let normalized = InputNormalizer.normalize(query).lowercased()
            guard let result = StaticOverrides.match(normalized) else {
                print("MISS (nav): '\(query)'")
                continue
            }
            if case .uiAction(let action, _) = result, case .navigate = action {
                navigated += 1
            } else {
                print("WRONG type (nav): '\(query)' → \(result)")
            }
        }
        print("📊 StaticOverrides navigation: \(navigated)/\(navQueries.count)")
        XCTAssertEqual(navigated, navQueries.count, "All navigation queries must route to .navigate")
    }

    @MainActor
    func testStaticOverrides_NonDomainCommands() {
        let staticCases = ["help", "scan barcode", "thanks", "ok"]
        var caught = 0
        for query in staticCases {
            if StaticOverrides.match(query) != nil { caught += 1 }
            else { print("MISS (static): '\(query)'") }
        }
        print("📊 StaticOverrides non-domain: \(caught)/\(staticCases.count)")
        XCTAssertEqual(caught, staticCases.count)
    }
}
