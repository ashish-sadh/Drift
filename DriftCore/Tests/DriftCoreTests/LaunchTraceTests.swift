import XCTest
@testable import DriftCore

final class LaunchTraceTests: XCTestCase {
    func testFormatStep_producesExpectedShape() {
        XCTAssertEqual(
            LaunchTrace.formatStep("healthkit_auth", elapsedMs: 1234),
            "launch_trace step=healthkit_auth elapsed_ms=1234"
        )
    }

    func testFormatStep_zeroElapsed() {
        XCTAssertEqual(
            LaunchTrace.formatStep("sync_weight", elapsedMs: 0),
            "launch_trace step=sync_weight elapsed_ms=0"
        )
    }

    func testFormatTotal_producesExpectedShape() {
        XCTAssertEqual(
            LaunchTrace.formatTotal(elapsedMs: 5678),
            "launch_trace step=sync_complete total_ms=5678"
        )
    }

    func testElapsedMs_returnsZeroForNow() {
        // Same instant → ~0ms (allow 1ms slack for thread scheduling jitter).
        let now = Date()
        XCTAssertLessThanOrEqual(LaunchTrace.elapsedMs(since: now), 1)
    }

    func testElapsedMs_returnsAtLeastWaitedTime() {
        let start = Date()
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertGreaterThanOrEqual(LaunchTrace.elapsedMs(since: start), 50)
    }
}
