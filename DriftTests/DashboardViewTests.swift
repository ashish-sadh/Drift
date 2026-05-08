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
}
