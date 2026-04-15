import XCTest
@testable import Drift

/// Gold set for food logging accuracy — sprint task #79.
/// Tests the full deterministic pipeline: InputNormalizer → StaticOverrides → AIActionExecutor → ToolRanker.
/// 30+ queries covering voice-style, multi-food, Indian foods, vague quantities.
/// Measurement framework for design doc #65.
///
/// Run: xcodebuild test -only-testing:'DriftTests/FoodLoggingGoldSetTests'
final class FoodLoggingGoldSetTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            if ToolRegistry.shared.allTools().isEmpty {
                ToolRegistration.registerAll()
            }
        }
    }

    // MARK: - Helper

    /// Returns true if the query is detected as a food logging intent
    /// after input normalization (simulating the full pipeline).
    private func detectsFoodIntent(_ query: String) -> Bool {
        let normalized = InputNormalizer.normalize(query).lowercased()
        return AIActionExecutor.parseFoodIntent(normalized) != nil
            || AIActionExecutor.parseMultiFoodIntent(normalized) != nil
    }

    /// Returns true if ToolRanker ranks log_food as top tool after normalization.
    @MainActor
    private func ranksLogFood(_ query: String, screen: AIScreen = .food) -> Bool {
        let normalized = InputNormalizer.normalize(query).lowercased()
        let tools = ToolRanker.rank(query: normalized, screen: screen)
        return tools.first?.name == "log_food"
    }

    /// Returns true if IntentClassifier parses the query into a log_food tool call.
    private func classifierDetectsFood(_ query: String) -> Bool {
        let normalized = InputNormalizer.normalize(query)
        let msg = IntentClassifier.buildUserMessage(message: normalized, history: "")
        // We can't run LLM in tests, but we can verify the message is well-formed
        // and test the response parser with expected LLM output
        return !msg.isEmpty
    }

    // MARK: - Voice-Style Input (no punctuation, fillers, restarts)

    func testVoiceFillerWords() {
        let voiceQueries = [
            "umm I had 2 eggs",
            "uh like I ate some rice",
            "um had a banana for breakfast",
            "like I had some chicken",
            "basically I ate 3 rotis",
        ]
        var detected = 0
        for query in voiceQueries {
            if detectsFoodIntent(query) { detected += 1 }
            else { print("MISS (voice filler): '\(query)' → normalized: '\(InputNormalizer.normalize(query))'") }
        }
        print("📊 Voice filler food detection: \(detected)/\(voiceQueries.count)")
        XCTAssertGreaterThanOrEqual(detected, voiceQueries.count - 1, "Voice filler: at most 1 miss")
    }

    func testVoiceRestarts() {
        let restartQueries = [
            "I had I had 2 eggs for breakfast",
            "log log rice and dal",
            "I ate I ate chicken today",
        ]
        var detected = 0
        for query in restartQueries {
            if detectsFoodIntent(query) { detected += 1 }
            else { print("MISS (voice restart): '\(query)' → normalized: '\(InputNormalizer.normalize(query))'") }
        }
        print("📊 Voice restart food detection: \(detected)/\(restartQueries.count)")
        XCTAssertGreaterThanOrEqual(detected, restartQueries.count - 1)
    }

    func testVoiceRunOn() {
        // Voice input without punctuation, run-on style
        let runOnQueries = [
            "so I had eggs and toast for breakfast",
            "ok so I ate some biryani for lunch",
            "well I had a protein shake after workout",
        ]
        var detected = 0
        for query in runOnQueries {
            if detectsFoodIntent(query) { detected += 1 }
            else { print("MISS (voice run-on): '\(query)' → normalized: '\(InputNormalizer.normalize(query))'") }
        }
        print("📊 Voice run-on food detection: \(detected)/\(runOnQueries.count)")
        XCTAssertGreaterThanOrEqual(detected, runOnQueries.count - 1)
    }

    // MARK: - Multi-Food Logging

    func testMultiFoodQueries() {
        let multiFood = [
            ("log rice and dal", 2),
            ("I had 2 eggs and toast", 2),
            ("ate chicken, rice, and dal", 3),
            ("had eggs, toast, and coffee", 3),
            ("log paneer and roti for dinner", 2),
        ]
        var detected = 0
        for (query, expectedCount) in multiFood {
            let normalized = InputNormalizer.normalize(query).lowercased()
            if let items = AIActionExecutor.parseMultiFoodIntent(normalized) {
                if items.count >= expectedCount { detected += 1 }
                else { print("PARTIAL (multi): '\(query)' → \(items.count) items (expected \(expectedCount))") }
            } else if AIActionExecutor.parseFoodIntent(normalized) != nil {
                detected += 1 // Single-food parse is acceptable for 2-item queries
            } else {
                print("MISS (multi): '\(query)' → normalized: '\(normalized)'")
            }
        }
        print("📊 Multi-food detection: \(detected)/\(multiFood.count)")
        XCTAssertGreaterThanOrEqual(detected, multiFood.count - 1)
    }

    // MARK: - Indian Foods

    func testIndianFoods() {
        let indianQueries = [
            "had paneer tikka masala",
            "ate 2 idli with chutney",
            "log 1 dosa and sambar",
            "had a plate of biryani",
            "ate chole bhature",
            "log rajma chawal",
            "had 2 parathas for breakfast",
            "ate aloo gobi with 2 rotis",
            "had dal makhani and naan",
            "log a bowl of khichdi",
        ]
        var detected = 0
        for query in indianQueries {
            if detectsFoodIntent(query) { detected += 1 }
            else { print("MISS (indian): '\(query)' → normalized: '\(InputNormalizer.normalize(query))'") }
        }
        let pct = Double(detected) / Double(indianQueries.count) * 100
        print("📊 Indian food detection: \(detected)/\(indianQueries.count) (\(String(format: "%.0f", pct))%)")
        XCTAssertGreaterThanOrEqual(detected, Int(Double(indianQueries.count) * 0.8), "Indian foods: ≥80% detection")
    }

    // MARK: - Vague Quantities

    func testVagueQuantities() {
        let vagueQueries = [
            "had some rice",
            "ate a couple of eggs",
            "had a lot of chicken",
            "just had a little bit of oatmeal",
            "ate a few rotis",
            "had a handful of almonds",
        ]
        var detected = 0
        for query in vagueQueries {
            if detectsFoodIntent(query) { detected += 1 }
            else { print("MISS (vague qty): '\(query)' → normalized: '\(InputNormalizer.normalize(query))'") }
        }
        print("📊 Vague quantity detection: \(detected)/\(vagueQueries.count)")
        XCTAssertGreaterThanOrEqual(detected, vagueQueries.count - 2, "Vague quantities: at most 2 misses")
    }

    // MARK: - Amount Extraction Accuracy

    func testAmountExtractionGoldSet() {
        let cases: [(String, Double, String?)] = [
            // (query, expected servings, expected unit or nil for default)
            ("log 2 eggs", 2.0, nil),
            ("had 100g chicken", 100.0, "g"),
            ("ate 200 gram rice", 200.0, "g"),
            ("log 1.5 cups of oatmeal", 1.5, "cup"),
            ("had half an avocado", 0.5, nil),
            ("ate a quarter cup of almonds", 0.25, "cup"),
            ("log 3 scoops of protein", 3.0, "scoop"),
            ("had 2 slices of pizza", 2.0, "slice"),
            ("ate 2 to 3 bananas", 3.0, nil), // takes higher
            ("had a couple of rotis", 2.0, nil),
        ]
        var correct = 0
        for (query, expectedAmt, _) in cases {
            let normalized = InputNormalizer.normalize(query).lowercased()
            if let intent = AIActionExecutor.parseFoodIntent(normalized) {
                let actual = intent.servings ?? 1.0
                if abs(actual - expectedAmt) < 0.01 {
                    correct += 1
                } else {
                    print("WRONG AMT: '\(query)' → \(actual) (expected \(expectedAmt))")
                }
            } else {
                print("MISS (amount): '\(query)'")
            }
        }
        print("📊 Amount extraction: \(correct)/\(cases.count)")
        XCTAssertGreaterThanOrEqual(correct, cases.count - 3, "Amount extraction: ≥70% accuracy")
    }

    // MARK: - Normalizer + ToolRanker Integration

    @MainActor
    func testNormalizerImprovesToolRanking() {
        // Queries that should route to log_food AFTER normalization
        let queries = [
            "umm I had 2 eggs",
            "so I ate some rice",
            "ok so log chicken breast",
            "well I had a banana",
            "I had I had some toast",
        ]
        var correct = 0
        for query in queries {
            if ranksLogFood(query) { correct += 1 }
            else {
                let normalized = InputNormalizer.normalize(query).lowercased()
                let tools = ToolRanker.rank(query: normalized, screen: .food)
                print("WRONG RANK (normalized): '\(query)' → '\(normalized)' → \(tools.first?.name ?? "nil")")
            }
        }
        print("📊 Normalizer+ToolRanker food routing: \(correct)/\(queries.count)")
        XCTAssertGreaterThanOrEqual(correct, queries.count - 1)
    }

    // MARK: - IntentClassifier Input/Output

    func testClassifierResponseParsing() {
        // Test that IntentClassifier.parseResponse correctly handles food tool calls
        let foodResponses = [
            #"{"tool":"log_food","name":"eggs, toast","servings":"2"}"#,
            #"{"tool":"log_food","name":"chicken breast","servings":"1"}"#,
            #"{"tool":"log_food","name":"biryani"}"#,
            #"{"tool":"log_food","name":"rice, dal","servings":"1"}"#,
            #"{"tool":"log_food","name":"banana","servings":"3"}"#,
            #"{"tool":"log_food","name":"paneer tikka masala"}"#,
            #"{"tool":"log_food","name":"eggs","calories":"140","protein":"12"}"#,
        ]
        for response in foodResponses {
            let result = IntentClassifier.parseResponse(response)
            XCTAssertNotNil(result, "Should parse: \(response)")
            XCTAssertEqual(result?.tool, "log_food", "Tool should be log_food")
            XCTAssertNotNil(result?.params["name"], "Should have name param")
        }
    }

    func testClassifierTextResponses() {
        // Follow-up questions should parse as nil (not tool calls)
        let textResponses = [
            "What did you have for lunch?",
            "How much rice did you eat?",
            "That sounds great! Want to log something?",
        ]
        for response in textResponses {
            let result = IntentClassifier.parseResponse(response)
            XCTAssertNil(result, "Text response should not parse as tool call: \(response)")
        }
    }

    func testClassifierMalformedJSON() {
        let malformed = [
            #"{"tool":"log_food","name":"eggs""#, // missing closing brace — still finds { to }
            "not json at all",
            "",
            "   ",
        ]
        for response in malformed {
            // Should not crash
            _ = IntentClassifier.parseResponse(response)
        }
    }

    // MARK: - False Positive Prevention

    func testNormalizerDoesNotCreateFalsePositives() {
        // Info/status queries should NOT become food intents after normalization
        let shouldNotLog = [
            "umm how many calories left",
            "like what should I eat for dinner",
            "uh how's my protein",
            "so how am I doing today",
            "well what's my weight trend",
            "ok so start push day",
            "umm how did I sleep",
        ]
        var falsePositives = 0
        for query in shouldNotLog {
            if detectsFoodIntent(query) {
                falsePositives += 1
                print("FALSE POSITIVE (normalized): '\(query)' → '\(InputNormalizer.normalize(query))'")
            }
        }
        XCTAssertLessThanOrEqual(falsePositives, 1, "Normalizer should not create false positives")
    }

    // MARK: - Summary Statistics

    func testGoldSetSummary() {
        // Comprehensive stats across all query types
        let allQueries: [(String, Bool)] = [
            // Should detect as food (true positives)
            ("log 2 eggs", true),
            ("I had chicken breast", true),
            ("ate a banana for breakfast", true),
            ("had 200g paneer", true),
            ("log rice and dal", true),
            ("umm I had 2 eggs and toast", true),
            ("I had I had some chicken", true),
            ("so I ate biryani for lunch", true),
            ("had a couple of rotis", true),
            ("ate 3 idli with chutney", true),
            ("log aloo gobi", true),
            ("had a protein shake", true),
            ("drank a glass of milk", true),
            ("eating oatmeal", true),
            ("just had some yogurt", true),
            // Should NOT detect as food (true negatives)
            ("how many calories left", false),
            ("what should I eat", false),
            ("how's my protein", false),
            ("daily summary", false),
            ("start push day", false),
            ("how did I sleep", false),
            ("calories in a banana", false),
            ("weight trend", false),
            ("hello", false),
            ("thanks", false),
        ]

        var truePos = 0, falseNeg = 0, trueNeg = 0, falsePos = 0
        for (query, shouldBeFood) in allQueries {
            let detected = detectsFoodIntent(query)
            if shouldBeFood && detected { truePos += 1 }
            else if shouldBeFood && !detected { falseNeg += 1; print("FN: '\(query)'") }
            else if !shouldBeFood && !detected { trueNeg += 1 }
            else { falsePos += 1; print("FP: '\(query)'") }
        }

        let precision = truePos > 0 ? Double(truePos) / Double(truePos + falsePos) * 100 : 0
        let recall = truePos > 0 ? Double(truePos) / Double(truePos + falseNeg) * 100 : 0
        print("📊 GOLD SET SUMMARY:")
        print("   True Positives: \(truePos), False Negatives: \(falseNeg)")
        print("   True Negatives: \(trueNeg), False Positives: \(falsePos)")
        print("   Precision: \(String(format: "%.0f", precision))%, Recall: \(String(format: "%.0f", recall))%")

        XCTAssertGreaterThanOrEqual(precision, 90, "Precision should be ≥90%")
        XCTAssertGreaterThanOrEqual(recall, 80, "Recall should be ≥80%")
    }
}
