import XCTest
@testable import DriftCore

/// Dashboard 7-day Feedback activation banner predicate (#759). The banner
/// shows once per install during the [7d, 14d) window since `installDate`.
/// Auto-dismisses at 14d even without user interaction.
final class FeedbackPromptPreferenceTests: XCTestCase {

    private let installKey = "drift_install_date"
    private let seenKey = "drift_feedback_prompt_seen"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: installKey)
        UserDefaults.standard.removeObject(forKey: seenKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: installKey)
        UserDefaults.standard.removeObject(forKey: seenKey)
        super.tearDown()
    }

    // MARK: - Predicate

    func test_predicate_hidden_whenInstallDateMissing() {
        let now = Date()
        XCTAssertFalse(Preferences.shouldShowFeedbackPrompt(now: now, installDate: nil, hasSeen: false))
    }

    func test_predicate_hidden_beforeDay7() {
        let now = Date()
        let day0 = now
        let day6 = now.addingTimeInterval(-6 * 86400)
        XCTAssertFalse(Preferences.shouldShowFeedbackPrompt(now: now, installDate: day0, hasSeen: false))
        XCTAssertFalse(Preferences.shouldShowFeedbackPrompt(now: now, installDate: day6, hasSeen: false))
    }

    func test_predicate_shown_atDay7() {
        let now = Date()
        let day7 = now.addingTimeInterval(-7 * 86400)
        XCTAssertTrue(Preferences.shouldShowFeedbackPrompt(now: now, installDate: day7, hasSeen: false))
    }

    func test_predicate_shown_throughDay13() {
        let now = Date()
        let day10 = now.addingTimeInterval(-10 * 86400)
        let day13 = now.addingTimeInterval(-13 * 86400 - 3600) // 13d 1h
        XCTAssertTrue(Preferences.shouldShowFeedbackPrompt(now: now, installDate: day10, hasSeen: false))
        XCTAssertTrue(Preferences.shouldShowFeedbackPrompt(now: now, installDate: day13, hasSeen: false))
    }

    func test_predicate_hidden_atDay14AutoDismiss() {
        let now = Date()
        let day14 = now.addingTimeInterval(-14 * 86400)
        let day30 = now.addingTimeInterval(-30 * 86400)
        XCTAssertFalse(Preferences.shouldShowFeedbackPrompt(now: now, installDate: day14, hasSeen: false))
        XCTAssertFalse(Preferences.shouldShowFeedbackPrompt(now: now, installDate: day30, hasSeen: false))
    }

    func test_predicate_hidden_whenAlreadySeen() {
        let now = Date()
        let day10 = now.addingTimeInterval(-10 * 86400)
        XCTAssertFalse(Preferences.shouldShowFeedbackPrompt(now: now, installDate: day10, hasSeen: true))
    }

    // MARK: - Install date seeding

    func test_seedInstallDate_writesWhenUnset() {
        XCTAssertNil(Preferences.installDate)
        let anchor = Date(timeIntervalSince1970: 1_700_000_000)
        Preferences.seedInstallDateIfNeeded(now: anchor)
        XCTAssertEqual(Preferences.installDate?.timeIntervalSince1970 ?? 0, anchor.timeIntervalSince1970, accuracy: 1)
    }

    func test_seedInstallDate_idempotent() {
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let later = Date(timeIntervalSince1970: 1_800_000_000)
        Preferences.seedInstallDateIfNeeded(now: first)
        Preferences.seedInstallDateIfNeeded(now: later)
        XCTAssertEqual(Preferences.installDate?.timeIntervalSince1970 ?? 0, first.timeIntervalSince1970, accuracy: 1,
                       "Second seed must not overwrite the original install timestamp.")
    }

    // MARK: - Seen flag

    func test_hasSeenFeedbackPrompt_defaultsFalse() {
        XCTAssertFalse(Preferences.hasSeenFeedbackPrompt)
    }

    func test_hasSeenFeedbackPrompt_persists() {
        Preferences.hasSeenFeedbackPrompt = true
        XCTAssertTrue(Preferences.hasSeenFeedbackPrompt)
    }
}
