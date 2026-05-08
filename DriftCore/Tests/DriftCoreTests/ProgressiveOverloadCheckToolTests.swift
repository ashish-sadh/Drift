import XCTest
@testable import DriftCore

/// Tier-0: deterministic formatting logic — no LLM, no DB, no network.
final class ProgressiveOverloadCheckToolTests: XCTestCase {

    // MARK: - formatSingle

    func testFormatSingle_onPlateauCompound() {
        let result = PlateauResult(
            exercise: "Bench Press", isOnPlateau: true,
            sessionsChecked: 4, suggestion: "Try adding 5 lbs → 140 lbs next session.",
            isCompound: true
        )
        let output = ProgressiveOverloadCheckTool.formatSingle(result)
        XCTAssertTrue(output.contains("Bench Press"))
        XCTAssertTrue(output.contains("Plateau"))
        XCTAssertTrue(output.contains("5 lbs"))
    }

    func testFormatSingle_onPlateauIsolation() {
        let result = PlateauResult(
            exercise: "Bicep Curl", isOnPlateau: true,
            sessionsChecked: 3, suggestion: "Try adding 1 rep to each set, or perform a drop-set at the end.",
            isCompound: false
        )
        let output = ProgressiveOverloadCheckTool.formatSingle(result)
        XCTAssertTrue(output.contains("Bicep Curl"))
        XCTAssertTrue(output.contains("drop-set"))
    }

    func testFormatSingle_noPlateauEnoughData() {
        let result = PlateauResult(
            exercise: "Squat", isOnPlateau: false,
            sessionsChecked: 5, suggestion: "", isCompound: true
        )
        let output = ProgressiveOverloadCheckTool.formatSingle(result)
        XCTAssertTrue(output.contains("Squat"))
        XCTAssertTrue(output.contains("No plateau"))
        XCTAssertFalse(output.contains("only"))
    }

    func testFormatSingle_tooFewSessions_singular() {
        let result = PlateauResult(
            exercise: "Deadlift", isOnPlateau: false,
            sessionsChecked: 1, suggestion: "", isCompound: true
        )
        let output = ProgressiveOverloadCheckTool.formatSingle(result)
        XCTAssertTrue(output.contains("only 1 session"))
        XCTAssertFalse(output.contains("sessions"))
    }

    func testFormatSingle_tooFewSessions_plural() {
        let result = PlateauResult(
            exercise: "Deadlift", isOnPlateau: false,
            sessionsChecked: 2, suggestion: "", isCompound: true
        )
        let output = ProgressiveOverloadCheckTool.formatSingle(result)
        XCTAssertTrue(output.contains("only 2 sessions"))
    }

    // MARK: - formatAll

    func testFormatAll_empty() {
        let output = ProgressiveOverloadCheckTool.formatAll([])
        XCTAssertTrue(output.contains("No plateaus detected"))
    }

    func testFormatAll_single() {
        let result = PlateauResult(
            exercise: "Deadlift", isOnPlateau: true,
            sessionsChecked: 3, suggestion: "Try adding 5 lbs → 205 lbs next session.",
            isCompound: true
        )
        let output = ProgressiveOverloadCheckTool.formatAll([result])
        XCTAssertTrue(output.contains("1 exercise on plateau:"))
        XCTAssertTrue(output.contains("Deadlift"))
        XCTAssertTrue(output.hasPrefix("1 exercise"))
    }

    func testFormatAll_multiple() {
        let r1 = PlateauResult(
            exercise: "Squat", isOnPlateau: true,
            sessionsChecked: 3, suggestion: "Try adding 5 lbs → 185 lbs next session.",
            isCompound: true
        )
        let r2 = PlateauResult(
            exercise: "Lateral Raise", isOnPlateau: true,
            sessionsChecked: 4, suggestion: "Try adding 1 rep to each set, or perform a drop-set at the end.",
            isCompound: false
        )
        let output = ProgressiveOverloadCheckTool.formatAll([r1, r2])
        XCTAssertTrue(output.contains("2 exercises on plateau:"))
        XCTAssertTrue(output.contains("Squat"))
        XCTAssertTrue(output.contains("Lateral Raise"))
    }

    func testFormatAll_eachResultBulletPrefixed() {
        let r = PlateauResult(
            exercise: "OHP", isOnPlateau: true,
            sessionsChecked: 3, suggestion: "Try adding 5 lbs → 100 lbs next session.",
            isCompound: true
        )
        let output = ProgressiveOverloadCheckTool.formatAll([r])
        let lines = output.components(separatedBy: "\n")
        XCTAssertTrue(lines.contains { $0.hasPrefix("• ") }, "Each result should be bullet-prefixed")
    }
}
