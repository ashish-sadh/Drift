import XCTest

/// Regression test for #684 — the Send Feedback row in MoreTabView was removed
/// because email is a useless feedback channel for an AI-first health app.
/// Real feedback channels: AI chat, on-device telemetry (#261), GitHub Issues
/// via Command Center. This pins the removal so a future session doesn't
/// silently re-add a mailto: link or mail-composer.
///
/// Source-content hygiene check (Tier 0) instead of a Tier-1 ViewInspector
/// test — this reads the actual file from the project tree under `swift test`
/// (native host process, full FS access) and is faster, simpler, and catches
/// a re-add *anywhere* in the file rather than one specific row.
final class MoreTabFeedbackRegressionTests: XCTestCase {
    func testMoreTabView_hasNoFeedbackEmailReferences() throws {
        let projectRoot = Self.projectRoot()
        let source = projectRoot
            .appendingPathComponent("Drift")
            .appendingPathComponent("Views")
            .appendingPathComponent("Settings")
            .appendingPathComponent("MoreTabView.swift")
        let content = try String(contentsOf: source, encoding: .utf8)

        let forbidden = [
            "mailto:",
            "MFMailComposeViewController",
            "MFMailCompose",
            "Send Feedback",
            "sendFeedback",
            "showingMailFallback",
            "feedback@",
        ]
        for token in forbidden {
            XCTAssertFalse(
                content.contains(token),
                "MoreTabView.swift contains forbidden token \"\(token)\" — issue #684 removed Send Feedback because email is a useless feedback channel."
            )
        }
    }

    /// Resolve the project root from this test file's compile-time path.
    /// `#filePath` is `<root>/DriftCore/Tests/DriftCoreTests/<this>.swift`.
    private static func projectRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent() // DriftCoreTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // DriftCore/
            .deletingLastPathComponent() // <project root>
    }
}
