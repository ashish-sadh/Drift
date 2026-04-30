import XCTest
@testable import DriftCore

final class CrossSessionHistoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CrossSessionHistory.clear()
        Preferences.conversationHistoryEnabled = true
    }

    override func tearDown() {
        CrossSessionHistory.clear()
        Preferences.conversationHistoryEnabled = true
        super.tearDown()
    }

    func testSaveAndLoadRoundtrip() {
        let turns: [HistoryTurn] = [
            .init(role: .user, text: "I had biryani for dinner"),
            .init(role: .assistant, text: "Logged Biryani — 350 cal"),
        ]
        CrossSessionHistory.save(turns)
        let loaded = CrossSessionHistory.loadIfFresh()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.count, 2)
        XCTAssertEqual(loaded?[0].role, .user)
        XCTAssertEqual(loaded?[0].text, "I had biryani for dinner")
        XCTAssertEqual(loaded?[1].role, .assistant)
    }

    func testTTLExpiry() {
        let turns = [HistoryTurn(role: .user, text: "log eggs")]
        CrossSessionHistory.save(turns)
        // Simulate loading 25 hours after save — past the 24h TTL
        let future = Date(timeIntervalSinceNow: CrossSessionHistory.ttl + 3600)
        let loaded = CrossSessionHistory.loadIfFresh(now: future)
        XCTAssertNil(loaded, "Expired context must return nil")
    }

    func testWithinTTLLoads() {
        let turns = [HistoryTurn(role: .user, text: "log eggs")]
        CrossSessionHistory.save(turns)
        let justUnder = Date(timeIntervalSinceNow: CrossSessionHistory.ttl - 60)
        let loaded = CrossSessionHistory.loadIfFresh(now: justUnder)
        XCTAssertNotNil(loaded, "Context within TTL must load")
    }

    func testRespectsDisabledPref() {
        Preferences.conversationHistoryEnabled = false
        let turns = [HistoryTurn(role: .user, text: "had rice")]
        CrossSessionHistory.save(turns)
        XCTAssertNil(CrossSessionHistory.loadIfFresh(), "Disabled pref must prevent load")
    }

    func testMaxTurnsTruncation() {
        let turns = (1...8).map { HistoryTurn(role: .user, text: "turn \($0)") }
        CrossSessionHistory.save(turns)
        let loaded = CrossSessionHistory.loadIfFresh()
        XCTAssertEqual(loaded?.count, CrossSessionHistory.maxTurns, "Must persist at most maxTurns")
        XCTAssertEqual(loaded?.last?.text, "turn 8", "Must keep the most recent turns")
    }

    func testClearRemovesData() {
        CrossSessionHistory.save([.init(role: .user, text: "hello")])
        CrossSessionHistory.clear()
        XCTAssertNil(CrossSessionHistory.loadIfFresh())
    }

    func testEmptyTurnsNotSaved() {
        CrossSessionHistory.save([])
        XCTAssertNil(CrossSessionHistory.loadIfFresh(), "Empty turns must not persist")
    }

    func testRolePreservation() {
        let turns: [HistoryTurn] = [
            .init(role: .user, text: "user msg"),
            .init(role: .assistant, text: "assistant msg"),
            .init(role: .user, text: "follow-up"),
        ]
        CrossSessionHistory.save(turns)
        let loaded = CrossSessionHistory.loadIfFresh()!
        XCTAssertEqual(loaded[0].role, .user)
        XCTAssertEqual(loaded[1].role, .assistant)
        XCTAssertEqual(loaded[2].role, .user)
    }
}
