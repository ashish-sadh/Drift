import XCTest
@testable import DriftCore

/// Tier 0 — pure logic, no LLM, no simulator.
/// Tests the /debug last-failures chat command added in #447.
///
/// Run: `cd DriftCore && swift test --filter DebugCommandTests`
final class DebugCommandTests: XCTestCase {

    // MARK: - Command routing (DEBUG-only)

    func testDebugLastFailures_MatchesInDebugBuild() {
        #if DEBUG
        MainActor.assumeIsolated {
            let result = StaticOverrides.match("/debug last-failures")
            XCTAssertNotNil(result, "/debug last-failures must match in DEBUG builds")
            if case .handler = result { } else {
                XCTFail("Expected .handler result for /debug last-failures")
            }
        }
        #endif
    }

    func testDebugLastFailuresN_MatchesWithCount() {
        #if DEBUG
        MainActor.assumeIsolated {
            let result = StaticOverrides.match("/debug last-failures 10")
            XCTAssertNotNil(result, "/debug last-failures 10 must match in DEBUG builds")
        }
        #endif
    }

    func testDebugOtherSubcommand_DoesNotMatch() {
        // Unknown /debug subcommand falls through to LLM
        MainActor.assumeIsolated {
            let result = StaticOverrides.match("/debug unknown-command")
            XCTAssertNil(result, "Unknown /debug subcommand must return nil (fall through to LLM)")
        }
    }

    // MARK: - Output formatting with test DB

    func testLastFailuresOutput_EmptyTelemetry_ShowsNoFailuresMessage() throws {
        #if DEBUG
        let db = try AppDatabase.empty()
        let telemetry = ChatTelemetryService(db: db)
        let output = StaticOverrides.lastFailuresOutput(limit: 5, telemetry: telemetry)
        XCTAssertTrue(output.contains("No failures"),
            "Empty DB should produce a 'No failures' message, got: \(output)")
        #endif
    }

    func testLastFailuresOutput_OnlySuccesses_ShowsNoFailuresMessage() throws {
        #if DEBUG
        let db = try AppDatabase.empty()
        try db.insertChatTurn(ChatTurnRow(
            timestamp: "2026-04-26T10:00:00Z",
            queryFingerprint: "abc123",
            intentLabel: "tool_call",
            toolCalled: "log_food",
            outcome: "success",
            latencyMs: 300,
            turnIndex: 1,
            queryText: "log 2 eggs"
        ))
        let telemetry = ChatTelemetryService(db: db)
        let output = StaticOverrides.lastFailuresOutput(limit: 5, telemetry: telemetry)
        XCTAssertTrue(output.contains("No failures"),
            "Only-success DB should produce 'No failures' message")
        #endif
    }

    func testLastFailuresOutput_WithFailures_ShowsQueryAndStage() throws {
        #if DEBUG
        let db = try AppDatabase.empty()
        try db.insertChatTurn(ChatTurnRow(
            timestamp: "2026-04-26T10:01:00Z",
            queryFingerprint: "deadbeef1234",
            intentLabel: "tool_call",
            toolCalled: "log_food",
            outcome: "failed",
            latencyMs: 1200,
            turnIndex: 2,
            queryText: "log my biryani"
        ))
        try db.insertChatTurn(ChatTurnRow(
            timestamp: "2026-04-26T10:02:00Z",
            queryFingerprint: "cafebabe5678",
            intentLabel: "timeout",
            toolCalled: nil,
            outcome: "timeout",
            latencyMs: 20000,
            turnIndex: 3,
            queryText: "show me my trends"
        ))
        let telemetry = ChatTelemetryService(db: db)
        let output = StaticOverrides.lastFailuresOutput(limit: 5, telemetry: telemetry)
        XCTAssertTrue(output.contains("log my biryani"), "Output must include the failed query text")
        XCTAssertTrue(output.contains("log_food"), "Output must include the tool that failed")
        XCTAssertTrue(output.contains("failed"), "Output must include the outcome")
        XCTAssertTrue(output.contains("show me my trends"), "Output must include the timeout query")
        XCTAssertTrue(output.contains("1."), "Output must be numbered")
        #endif
    }

    func testLastFailuresOutput_LimitRespected() throws {
        #if DEBUG
        let db = try AppDatabase.empty()
        for i in 1...8 {
            try db.insertChatTurn(ChatTurnRow(
                timestamp: "2026-04-26T10:0\(i):00Z",
                queryFingerprint: "fp\(i)",
                intentLabel: "tool_call",
                toolCalled: "log_food",
                outcome: "failed",
                latencyMs: 500,
                turnIndex: i,
                queryText: "failure query \(i)"
            ))
        }
        let telemetry = ChatTelemetryService(db: db)
        let output3 = StaticOverrides.lastFailuresOutput(limit: 3, telemetry: telemetry)
        XCTAssertTrue(output3.contains("3)") || output3.contains("(3"),
            "limit=3 header should say 3 failures")
        XCTAssertFalse(output3.contains("4."),
            "limit=3 should not show a 4th entry")
        #endif
    }

}
