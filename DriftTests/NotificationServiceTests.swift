import XCTest
@testable import Drift

final class NotificationServiceTests: XCTestCase {

    // MARK: - Preferences

    func testHealthNudgesDefaultsToOn() {
        // Clear any existing value
        UserDefaults.standard.removeObject(forKey: "drift_health_nudges")
        XCTAssertTrue(Preferences.healthNudgesEnabled)
    }

    func testHealthNudgesToggleOff() {
        Preferences.healthNudgesEnabled = false
        XCTAssertFalse(Preferences.healthNudgesEnabled)
        // Restore
        UserDefaults.standard.removeObject(forKey: "drift_health_nudges")
    }

    func testHealthNudgesToggleOn() {
        Preferences.healthNudgesEnabled = false
        Preferences.healthNudgesEnabled = true
        XCTAssertTrue(Preferences.healthNudgesEnabled)
        // Restore
        UserDefaults.standard.removeObject(forKey: "drift_health_nudges")
    }
}
