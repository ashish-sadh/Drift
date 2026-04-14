import XCTest
@testable import Drift

final class NotificationServiceTests: XCTestCase {

    // MARK: - Preference Defaults

    func testHealthNudgesDefaultsToOff() {
        UserDefaults.standard.removeObject(forKey: "drift_health_nudges")
        XCTAssertFalse(Preferences.healthNudgesEnabled, "Health nudges should default to OFF")
    }

    func testOnlineFoodSearchDefaultsToOn() {
        UserDefaults.standard.removeObject(forKey: "drift_online_food_search")
        XCTAssertTrue(Preferences.onlineFoodSearchEnabled, "Online food search should default to ON")
    }

    // MARK: - Toggles

    func testHealthNudgesToggle() {
        let original = UserDefaults.standard.object(forKey: "drift_health_nudges")
        defer { if let o = original { UserDefaults.standard.set(o, forKey: "drift_health_nudges") } else { UserDefaults.standard.removeObject(forKey: "drift_health_nudges") } }

        Preferences.healthNudgesEnabled = true
        XCTAssertTrue(Preferences.healthNudgesEnabled)
        Preferences.healthNudgesEnabled = false
        XCTAssertFalse(Preferences.healthNudgesEnabled)
    }

    func testOnlineFoodSearchToggle() {
        let original = UserDefaults.standard.object(forKey: "drift_online_food_search")
        defer { if let o = original { UserDefaults.standard.set(o, forKey: "drift_online_food_search") } else { UserDefaults.standard.removeObject(forKey: "drift_online_food_search") } }

        Preferences.onlineFoodSearchEnabled = false
        XCTAssertFalse(Preferences.onlineFoodSearchEnabled)
        Preferences.onlineFoodSearchEnabled = true
        XCTAssertTrue(Preferences.onlineFoodSearchEnabled)
    }
}
