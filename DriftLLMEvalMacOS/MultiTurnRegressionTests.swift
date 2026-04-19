import XCTest
import Foundation

/// Hard multi-turn regression suite — 20 scenarios across 5 failure categories:
///   H1–H5  : Mid-log topic switch (user pivots topic mid-stream then resumes)
///   H6–H10 : Pronoun after gap    (reference to earlier turn after 2+ intervening turns)
///   H11–H14: Clarifier + continue (assistant clarifies → user answers → follow-up)
///   H15–H17: Cross-domain         (two different health domains in 3 turns)
///   H18–H20: Confirm-then-edit    (log confirmed → user corrects quantity/unit/removes)
///
/// Pass threshold: ≥80% of all turns correct across all 20 scenarios.
/// Each scenario also enforces a local floor (≥67% of its turns).
///
/// Run:
///   xcodebuild test -scheme DriftLLMEvalMacOS -destination 'platform=macOS' \
///     -only-testing:'DriftLLMEvalMacOS/MultiTurnRegressionTests'
final class MultiTurnRegressionTests: XCTestCase {

    nonisolated(unsafe) static var gemmaBackend: LlamaCppBackend?
    static let gemmaPath = URL.homeDirectory
        .appending(path: "drift-state/models/gemma-4-e2b-q4_k_m.gguf")

    override class func setUp() {
        super.setUp()
        guard FileManager.default.fileExists(atPath: gemmaPath.path) else {
            fatalError("❌ Gemma 4 not found at \(gemmaPath.path)\nRun: bash scripts/download-models.sh")
        }
        let b = LlamaCppBackend(modelPath: gemmaPath, threads: 6)
        try? b.loadSync()
        guard b.isLoaded else {
            fatalError("❌ Gemma 4 failed to load — check model file integrity")
        }
        gemmaBackend = b
        print("✅ [MultiTurnRegressionTests] Gemma 4 loaded")
    }

    // MARK: - Types

    struct HardTurn {
        let query: String
        let expectedTool: String?   // nil = text response (no JSON tool call)
    }

    struct Scenario {
        let name: String
        let turns: [HardTurn]
        var localFloor: Int { max(1, Int(ceil(Double(turns.count) * 0.67))) }
    }

    // MARK: - Corpus (single source of truth for all 20 scenarios)

    static let allScenarios: [Scenario] = [
        // H1–H5: Mid-log topic switch
        Scenario(name: "H1:log→protein-pivot→resume", turns: [
            HardTurn(query: "log 2 eggs for breakfast",                  expectedTool: "log_food"),
            HardTurn(query: "actually wait, what's my protein today?",   expectedTool: "food_info"),
            HardTurn(query: "ok also log some oatmeal",                  expectedTool: "log_food"),
        ]),
        Scenario(name: "H2:log-weight→sleep-pivot→weight-trend", turns: [
            HardTurn(query: "I weigh 73 kg today",                       expectedTool: "log_weight"),
            HardTurn(query: "by the way how was my sleep last night",    expectedTool: "sleep_recovery"),
            HardTurn(query: "back to weight — am I on track?",           expectedTool: "weight_info"),
        ]),
        Scenario(name: "H3:start-workout→food-pivot→log-food", turns: [
            HardTurn(query: "start push day",                            expectedTool: "start_workout"),
            HardTurn(query: "hold on, what should I eat before working out", expectedTool: "food_info"),
            HardTurn(query: "ok log 1 banana",                           expectedTool: "log_food"),
        ]),
        Scenario(name: "H4:supplements→food-log-pivot→food-info", turns: [
            HardTurn(query: "did I take creatine today?",                expectedTool: "supplements"),
            HardTurn(query: "log the protein shake I just had",          expectedTool: "log_food"),
            HardTurn(query: "how much protein was in that?",             expectedTool: "food_info"),
        ]),
        Scenario(name: "H5:calories-left→log-weight→trend", turns: [
            HardTurn(query: "calories left today?",                      expectedTool: "food_info"),
            HardTurn(query: "log weight 74.5 kg",                        expectedTool: "log_weight"),
            HardTurn(query: "am I losing weight?",                       expectedTool: "weight_info"),
        ]),

        // H6–H10: Pronoun after gap
        Scenario(name: "H6:log-chicken→macros→weight→delete-that", turns: [
            HardTurn(query: "log 200g chicken for dinner",               expectedTool: "log_food"),
            HardTurn(query: "how are my macros today?",                  expectedTool: "food_info"),
            HardTurn(query: "how's my weight trend?",                    expectedTool: "weight_info"),
            HardTurn(query: "delete that chicken I just logged",         expectedTool: "delete_food"),
        ]),
        Scenario(name: "H7:log-oatmeal→protein→sleep→how-much-was-that", turns: [
            HardTurn(query: "log oatmeal for breakfast",                 expectedTool: "log_food"),
            HardTurn(query: "how's my protein today?",                   expectedTool: "food_info"),
            HardTurn(query: "how's my sleep?",                           expectedTool: "sleep_recovery"),
            HardTurn(query: "how many calories was that oatmeal?",       expectedTool: "food_info"),
        ]),
        Scenario(name: "H8:start-pull→supplements→mark→workout-query", turns: [
            HardTurn(query: "start pull day",                            expectedTool: "start_workout"),
            HardTurn(query: "what supplements should I take after?",     expectedTool: "supplements"),
            HardTurn(query: "mark creatine as taken",                    expectedTool: "mark_supplement"),
            HardTurn(query: "how was that workout?",                     expectedTool: "exercise_info"),
        ]),
        Scenario(name: "H9:log-weight→food→sleep→fix-weight", turns: [
            HardTurn(query: "I weigh 75 kg",                             expectedTool: "log_weight"),
            HardTurn(query: "how many calories did I eat today?",        expectedTool: "food_info"),
            HardTurn(query: "how's my sleep?",                           expectedTool: "sleep_recovery"),
            HardTurn(query: "fix that weight — it was 74 not 75",        expectedTool: "log_weight"),
        ]),
        Scenario(name: "H10:log-banana→food-info→weight→remove-it", turns: [
            HardTurn(query: "log 1 banana",                              expectedTool: "log_food"),
            HardTurn(query: "what else should I eat today?",             expectedTool: "food_info"),
            HardTurn(query: "what's my weight goal?",                    expectedTool: "weight_info"),
            HardTurn(query: "actually remove that banana from my log",   expectedTool: "delete_food"),
        ]),

        // H11–H14: Clarifier + continuation
        Scenario(name: "H11:log-rice→basmati→add-dal", turns: [
            HardTurn(query: "log rice",                                  expectedTool: "log_food"),
            HardTurn(query: "make it basmati rice",                      expectedTool: "edit_meal"),
            HardTurn(query: "add some dal too",                          expectedTool: "log_food"),
        ]),
        Scenario(name: "H12:what-to-train→push-day→muscles", turns: [
            HardTurn(query: "what should I train today?",                expectedTool: "exercise_info"),
            HardTurn(query: "start push day",                            expectedTool: "start_workout"),
            HardTurn(query: "what muscles am I working?",                expectedTool: "exercise_info"),
        ]),
        Scenario(name: "H13:log-biryani→calories→another-serving", turns: [
            HardTurn(query: "log chicken biryani",                       expectedTool: "log_food"),
            HardTurn(query: "how many calories was that?",               expectedTool: "food_info"),
            HardTurn(query: "log another serving of it",                 expectedTool: "log_food"),
        ]),
        Scenario(name: "H14:supplements→mark-omega3→whats-left", turns: [
            HardTurn(query: "did I take my supplements?",                expectedTool: "supplements"),
            HardTurn(query: "mark omega 3 as taken",                     expectedTool: "mark_supplement"),
            HardTurn(query: "what else is left?",                        expectedTool: "supplements"),
        ]),

        // H15–H17: Cross-domain
        Scenario(name: "H15:bench-press→weight-trend→projection", turns: [
            HardTurn(query: "how's my bench press?",                     expectedTool: "exercise_info"),
            HardTurn(query: "and my weight trend?",                      expectedTool: "weight_info"),
            HardTurn(query: "when will I hit 170 lbs?",                  expectedTool: "weight_info"),
        ]),
        Scenario(name: "H16:sleep→calories→protein", turns: [
            HardTurn(query: "how's my sleep?",                           expectedTool: "sleep_recovery"),
            HardTurn(query: "what about my calories today?",             expectedTool: "food_info"),
            HardTurn(query: "am I hitting my protein goal?",             expectedTool: "food_info"),
        ]),
        Scenario(name: "H17:log-chicken→sleep-recovery→body-comp", turns: [
            HardTurn(query: "log 200g chicken breast for dinner",        expectedTool: "log_food"),
            HardTurn(query: "how was my sleep recovery last night?",     expectedTool: "sleep_recovery"),
            HardTurn(query: "what's my current body fat?",               expectedTool: "body_comp"),
        ]),

        // H18–H20: Confirm-then-edit
        Scenario(name: "H18:log-2eggs→make-it-3→protein-query", turns: [
            HardTurn(query: "log 2 eggs",                                expectedTool: "log_food"),
            HardTurn(query: "actually make it 3 eggs",                   expectedTool: "edit_meal"),
            HardTurn(query: "how much protein was that?",                expectedTool: "food_info"),
        ]),
        Scenario(name: "H19:log-75kg→oops-75lbs→progress", turns: [
            HardTurn(query: "log weight 75 kg",                          expectedTool: "log_weight"),
            HardTurn(query: "wait I meant 75 lbs not kg",                expectedTool: "log_weight"),
            HardTurn(query: "am I making progress?",                     expectedTool: "weight_info"),
        ]),
        Scenario(name: "H20:log-biryani→delete-it→log-paneer", turns: [
            HardTurn(query: "log chicken biryani for dinner",            expectedTool: "log_food"),
            HardTurn(query: "hmm I didn't actually eat that, delete it", expectedTool: "delete_food"),
            HardTurn(query: "log paneer tikka instead",                  expectedTool: "log_food"),
        ]),
    ]

    // MARK: - Runner

    private func classify(_ message: String, history: String) async -> String? {
        guard let backend = Self.gemmaBackend else { return nil }
        let userMsg = history.isEmpty
            ? message
            : "Chat:\n\(String(history.prefix(1600)))\n\nUser: \(message)"
        return await backend.respond(to: userMsg, systemPrompt: PerStageEvalSupport.systemPrompt)
    }

    /// Returns (correct turns, total turns). Also asserts local floor.
    @discardableResult
    private func runScenario(_ scenario: Scenario, file: StaticString = #filePath, line: UInt = #line) async -> (Int, Int) {
        var history = ""
        var correct = 0

        for (i, turn) in scenario.turns.enumerated() {
            guard let response = await classify(turn.query, history: history) else {
                print("  ❌ [\(scenario.name)] T\(i+1) no response"); continue
            }
            let tool = PerStageEvalSupport.extractTool(response)
            let pass = tool == turn.expectedTool

            if pass {
                correct += 1
            } else {
                print("  ❌ [\(scenario.name)] T\(i+1) '\(turn.query)' → \(tool ?? "text") (want \(turn.expectedTool ?? "text"))")
            }

            let summary = tool.map { "[\($0)]" } ?? String(response.prefix(60))
            history += "User: \(turn.query)\nAssistant: \(summary)\n"
        }

        let total = scenario.turns.count
        print("  📊 [\(scenario.name)]: \(correct)/\(total)")

        XCTAssertGreaterThanOrEqual(correct, scenario.localFloor,
            "[\(scenario.name)] need ≥\(scenario.localFloor)/\(total), got \(correct)/\(total)",
            file: file, line: line)

        return (correct, total)
    }

    // MARK: - Individual scenario tests (H1–H20)

    func testH1()  async { await runScenario(Self.allScenarios[0]) }
    func testH2()  async { await runScenario(Self.allScenarios[1]) }
    func testH3()  async { await runScenario(Self.allScenarios[2]) }
    func testH4()  async { await runScenario(Self.allScenarios[3]) }
    func testH5()  async { await runScenario(Self.allScenarios[4]) }
    func testH6()  async { await runScenario(Self.allScenarios[5]) }
    func testH7()  async { await runScenario(Self.allScenarios[6]) }
    func testH8()  async { await runScenario(Self.allScenarios[7]) }
    func testH9()  async { await runScenario(Self.allScenarios[8]) }
    func testH10() async { await runScenario(Self.allScenarios[9]) }
    func testH11() async { await runScenario(Self.allScenarios[10]) }
    func testH12() async { await runScenario(Self.allScenarios[11]) }
    func testH13() async { await runScenario(Self.allScenarios[12]) }
    func testH14() async { await runScenario(Self.allScenarios[13]) }
    func testH15() async { await runScenario(Self.allScenarios[14]) }
    func testH16() async { await runScenario(Self.allScenarios[15]) }
    func testH17() async { await runScenario(Self.allScenarios[16]) }
    func testH18() async { await runScenario(Self.allScenarios[17]) }
    func testH19() async { await runScenario(Self.allScenarios[18]) }
    func testH20() async { await runScenario(Self.allScenarios[19]) }

    // MARK: - Global summary (≥80% floor across all 20 scenarios)

    func testHardSuiteBaseline() async {
        var totalCorrect = 0
        var totalTurns = 0

        print("\n📊 Hard Multi-Turn Suite — 20 Scenarios:")
        for scenario in Self.allScenarios {
            let (c, t) = await runScenario(scenario)
            totalCorrect += c
            totalTurns += t
        }

        let pct = Int(Double(totalCorrect) / Double(totalTurns) * 100)
        print("\n📊 Hard suite global: \(totalCorrect)/\(totalTurns) = \(pct)%")

        let floor = Int(ceil(Double(totalTurns) * 0.80))
        XCTAssertGreaterThanOrEqual(totalCorrect, floor,
            "Hard multi-turn global pass rate: \(totalCorrect)/\(totalTurns) = \(pct)% (need ≥80%)")
    }
}
