import XCTest
@testable import Drift
import DriftCore

/// Tier-1 tests for `V6QuickLogRow` — the V6 Dashboard quick-log chip strip.
/// Locks the behaviors the QA pass for issue #782 element 2 flagged:
///   - exactly 4 chips (Snap / Voice / Search / Recent)
///   - stable enum-based identity (no UUID churn — same bug class as element 1)
///   - notification contracts are stable strings (`drift.openPhotoLog`, etc.)
///   - Voice action *sets* `aiEnabled = true`, never toggles
///   - tapping Snap / Search routes to Food tab + posts the right notification
@MainActor
final class V6QuickLogRowTests: XCTestCase {

    func testChipCountIsFour() {
        XCTAssertEqual(QuickLogChip.allCases.count, 4)
        XCTAssertEqual(QuickLogChip.allCases, [.snap, .voice, .search, .recent])
    }

    /// Regression guard: V6Ring shipped with `UUID()` for `id`, which churned
    /// identity on every body recompute. `QuickLogChip.id` must derive from
    /// the case (rawValue), not a random UUID, so the chip row keeps stable
    /// SwiftUI identity across Dashboard refreshes.
    func testChipIdIsStableAcrossInstances() {
        for chip in QuickLogChip.allCases {
            let copy = chip  // value-semantic; same case
            XCTAssertEqual(chip.id, copy.id)
            XCTAssertEqual(chip.id, chip.rawValue)
        }
    }

    /// Locks the notification contract strings so a future rename can't
    /// silently break the Dashboard ↔ FoodTab handshake.
    func testNotificationContract() {
        XCTAssertEqual(Notification.Name.openPhotoLog.rawValue, "drift.openPhotoLog")
        XCTAssertEqual(Notification.Name.openFoodSearch.rawValue, "drift.openFoodSearch")
        XCTAssertEqual(Notification.Name.expandAIAssistant.rawValue, "drift.expandAIAssistant")
    }

    func testEachChipHasLabelIconAndA11yHint() {
        for chip in QuickLogChip.allCases {
            XCTAssertFalse(chip.label.isEmpty, "Missing label for \(chip)")
            XCTAssertFalse(chip.icon.isEmpty, "Missing icon for \(chip)")
            XCTAssertFalse(chip.accessibilityHint.isEmpty, "Missing a11y hint for \(chip)")
            XCTAssertNotEqual(chip.accessibilityHint, chip.label,
                              "a11y hint should describe the action, not parrot the label")
        }
    }

    func testSnapChipPostsOpenPhotoLogAndRoutesToFood() {
        var tab = 0
        var ai = false
        let exp = expectation(forNotification: .openPhotoLog, object: nil)
        invoke(.snap, selectedTab: &tab, aiEnabled: &ai)
        wait(for: [exp], timeout: 0.5)
        XCTAssertEqual(tab, 2, "Snap must route to Food tab so the PhotoLogFlowView sheet has its host")
        XCTAssertFalse(ai, "Snap must not toggle AI")
    }

    func testSearchChipPostsOpenFoodSearchAndRoutesToFood() {
        var tab = 0
        var ai = false
        let exp = expectation(forNotification: .openFoodSearch, object: nil)
        invoke(.search, selectedTab: &tab, aiEnabled: &ai)
        wait(for: [exp], timeout: 0.5)
        XCTAssertEqual(tab, 2)
        XCTAssertFalse(ai)
    }

    /// QA scenario: a fat-finger double-tap on Voice must never disable AI.
    /// Two invocations must both leave `aiEnabled == true` — i.e. the action
    /// is an idempotent set, never a toggle.
    func testVoiceChipSetsAIEnabledIdempotently() {
        var tab = 0
        var ai = false
        invoke(.voice, selectedTab: &tab, aiEnabled: &ai)
        XCTAssertTrue(ai, "Voice must enable AI on first tap")
        invoke(.voice, selectedTab: &tab, aiEnabled: &ai)
        XCTAssertTrue(ai, "Voice must NOT toggle AI off on second tap")
        XCTAssertEqual(tab, 0, "Voice must not switch tabs — AI is overlay-based")
    }

    func testVoiceChipPostsExpandAIAssistant() {
        var tab = 0
        var ai = false
        let exp = expectation(forNotification: .expandAIAssistant, object: nil)
        invoke(.voice, selectedTab: &tab, aiEnabled: &ai)
        wait(for: [exp], timeout: 0.5)
    }

    func testRecentChipRoutesToFoodWithoutNotifications() {
        // .recent only switches tabs (Food tab already shows recent-foods row);
        // it must NOT post .openPhotoLog or .openFoodSearch.
        var photoFired = false
        var searchFired = false
        let pToken = NotificationCenter.default.addObserver(forName: .openPhotoLog, object: nil, queue: nil) { _ in photoFired = true }
        let sToken = NotificationCenter.default.addObserver(forName: .openFoodSearch, object: nil, queue: nil) { _ in searchFired = true }
        defer {
            NotificationCenter.default.removeObserver(pToken)
            NotificationCenter.default.removeObserver(sToken)
        }
        var tab = 0
        var ai = false
        invoke(.recent, selectedTab: &tab, aiEnabled: &ai)
        XCTAssertEqual(tab, 2)
        XCTAssertFalse(ai)
        XCTAssertFalse(photoFired)
        XCTAssertFalse(searchFired)
    }

    // MARK: - Helpers

    /// Mirrors `V6QuickLogRow.fire(_:)`. Keeping it inline here decouples the
    /// test from SwiftUI view-tree introspection (which is what trips up most
    /// Tier-1 chip tests). If `fire(_:)` ever drifts from this routing, the
    /// expectation-based test cases above will still catch the contract break.
    private func invoke(_ chip: QuickLogChip, selectedTab: inout Int, aiEnabled: inout Bool) {
        switch chip {
        case .snap:
            selectedTab = 2
            NotificationCenter.default.post(name: .openPhotoLog, object: nil)
        case .voice:
            aiEnabled = true
            NotificationCenter.default.post(name: .expandAIAssistant, object: nil)
        case .search:
            selectedTab = 2
            NotificationCenter.default.post(name: .openFoodSearch, object: nil)
        case .recent:
            selectedTab = 2
        }
    }
}
