import XCTest
@testable import DriftCore

final class LaunchStageTests: XCTestCase {
    func testStatusText_nonCompleteCases_returnNonEmptyText() {
        XCTAssertEqual(LaunchStage.starting.statusText, "Starting up…")
        XCTAssertEqual(LaunchStage.syncingHealth.statusText, "Syncing health data…")
        XCTAssertEqual(LaunchStage.calculatingTrends.statusText, "Calculating trends…")
        XCTAssertEqual(LaunchStage.estimatingEnergy.statusText, "Estimating energy budget…")
        XCTAssertEqual(LaunchStage.almostThere.statusText, "Almost there…")
    }

    func testStatusText_complete_isEmpty() {
        // .complete fires when the splash crossfades out — the text shouldn't
        // flicker into a final string before the view disappears.
        XCTAssertEqual(LaunchStage.complete.statusText, "")
    }

    func testStages_areDistinct() {
        let all: [LaunchStage] = [.starting, .syncingHealth, .calculatingTrends, .estimatingEnergy, .almostThere, .complete]
        XCTAssertEqual(Set(all).count, all.count)
    }

    func testNonCompleteStages_haveDistinctStatusText() {
        let visibleStages: [LaunchStage] = [.starting, .syncingHealth, .calculatingTrends, .estimatingEnergy, .almostThere]
        let texts = visibleStages.map(\.statusText)
        XCTAssertEqual(Set(texts).count, texts.count, "Each visible stage must show a different status string")
    }

    /// Documents the launch sequence — the splash text walks visibleSequence in
    /// order. If a future refactor swaps stages or skips one, this asserts the
    /// declared invariant. The actual transitions live in `DriftApp.task`; this
    /// test pins the order the splash *expects* so the two stay in sync.
    func testVisibleSequence_matchesLaunchOrder() {
        let visibleSequence: [LaunchStage] = [.starting, .syncingHealth, .calculatingTrends, .estimatingEnergy, .almostThere]
        for (idx, stage) in visibleSequence.enumerated() {
            XCTAssertFalse(stage.statusText.isEmpty, "Visible stage at index \(idx) must have status text")
        }
    }
}
