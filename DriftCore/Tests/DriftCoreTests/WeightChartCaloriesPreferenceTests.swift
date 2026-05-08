import XCTest
@testable import DriftCore

/// Default-on heuristic for the weight-chart calorie overlay (#669):
/// auto-on when the user has logged calories on ≥4 of the last 7 days.
/// Manual toggle wins regardless.
final class WeightChartCaloriesPreferenceTests: XCTestCase {

    private let key = "drift_weight_chart_calories"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: key)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func test_defaultOff_whenSparseTracking() {
        XCTAssertFalse(Preferences.weightChartCaloriesEnabled(daysWithCaloriesInLastWeek: 0))
        XCTAssertFalse(Preferences.weightChartCaloriesEnabled(daysWithCaloriesInLastWeek: 3))
    }

    func test_defaultOn_whenRegularTracking() {
        XCTAssertTrue(Preferences.weightChartCaloriesEnabled(daysWithCaloriesInLastWeek: 4))
        XCTAssertTrue(Preferences.weightChartCaloriesEnabled(daysWithCaloriesInLastWeek: 7))
    }

    func test_manualOn_overridesSparseTracking() {
        Preferences.setWeightChartCaloriesEnabled(true)
        XCTAssertTrue(Preferences.weightChartCaloriesEnabled(daysWithCaloriesInLastWeek: 0))
    }

    func test_manualOff_overridesRegularTracking() {
        Preferences.setWeightChartCaloriesEnabled(false)
        XCTAssertFalse(Preferences.weightChartCaloriesEnabled(daysWithCaloriesInLastWeek: 7))
    }

    func test_userSetFlag_reflectsExplicitChoice() {
        XCTAssertFalse(Preferences.weightChartCaloriesUserSet)
        Preferences.setWeightChartCaloriesEnabled(true)
        XCTAssertTrue(Preferences.weightChartCaloriesUserSet)
    }
}
