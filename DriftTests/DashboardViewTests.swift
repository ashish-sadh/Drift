import XCTest
import SwiftUI
@testable import Drift

final class DashboardViewTests: XCTestCase {

    func testMacroRingsViewExists() {
        let view = MacroRingsView(
            calories: 1200, calorieTarget: 1800,
            protein: 60, proteinTarget: 120,
            carbs: 150, carbsTarget: 200,
            fat: 40, fatTarget: 60
        )
        // Verifies the view can be constructed without crashing
        XCTAssertNotNil(view)
    }

    func testMacroRingsViewOverTarget() {
        let view = MacroRingsView(
            calories: 2200, calorieTarget: 1800,
            protein: 130, proteinTarget: 120,
            carbs: 220, carbsTarget: 200,
            fat: 70, fatTarget: 60
        )
        XCTAssertNotNil(view)
    }

    /// Regression for #699 — tooltipView was inheriting the ring's 140×140
    /// frame and wrapping each row character-by-character. Construction with
    /// the screenshot's actual values (529 cal / 49g / 62g / 9g vs 2200/120/200/60
    /// targets) must succeed; the source-content guard below pins the layout fix.
    func testMacroRingsViewWithScreenshotValues() {
        let view = MacroRingsView(
            calories: 529, calorieTarget: 2200,
            protein: 49, proteinTarget: 120,
            carbs: 62, carbsTarget: 200,
            fat: 9, fatTarget: 60
        )
        XCTAssertNotNil(view)
    }

    /// Source-content guard for #699 — ensures the layout fix can't be
    /// reverted silently. `.fixedSize(horizontal:)` lets the tooltip take
    /// natural width and not inherit the 140×140 ring constraint.
    func testMacroRingsTooltipHasFixedSizeForReadability() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // DriftTests/
            .deletingLastPathComponent()  // <project root>
        let source = projectRoot
            .appendingPathComponent("Drift")
            .appendingPathComponent("Views")
            .appendingPathComponent("Shared")
            .appendingPathComponent("MacroRingsView.swift")
        let content = try String(contentsOf: source, encoding: .utf8)
        XCTAssertTrue(
            content.contains(".fixedSize(horizontal: true, vertical: false)"),
            "MacroRingsView tooltip must keep .fixedSize(horizontal:) so the tooltip doesn't inherit the ring's 140pt frame and wrap character-by-character (#699)."
        )
    }
}
