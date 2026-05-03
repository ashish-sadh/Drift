import XCTest
@testable import DriftCore

/// Tier-0 tests for MedicationInfoTool.
/// Covers: relativeDate/timeString pure helpers, ToolRanker routing for history queries,
/// and false-positive prevention (logging queries must not route to medication_info).
///
/// Run: cd DriftCore && swift test --filter MedicationInfoToolTests
final class MedicationInfoToolTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated { ToolRegistration.registerAll() }
    }

    // MARK: - relativeDate (pure)

    func testRelativeDate_today() {
        let now = Date()
        XCTAssertEqual(MedicationInfoTool.relativeDate(now, now: now), "today")
    }

    func testRelativeDate_yesterday() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(MedicationInfoTool.relativeDate(yesterday, now: now), "yesterday")
    }

    func testRelativeDate_threeDaysAgo() {
        let now = Date()
        let date = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        XCTAssertEqual(MedicationInfoTool.relativeDate(date, now: now), "3 days ago")
    }

    func testRelativeDate_oneWeekAgo() {
        let now = Date()
        let date = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        XCTAssertEqual(MedicationInfoTool.relativeDate(date, now: now), "1 week ago")
    }

    func testRelativeDate_twoWeeksAgo() {
        let now = Date()
        let date = Calendar.current.date(byAdding: .day, value: -14, to: now)!
        XCTAssertEqual(MedicationInfoTool.relativeDate(date, now: now), "2 weeks ago")
    }

    // MARK: - ToolRanker: medication_info routing

    @MainActor func testToolRanker_MedicationHistoryQueries() {
        let cases = [
            "when did i last take my ozempic shot",
            "when did i last take metformin",
            "last dose of semaglutide",
            "last time i took insulin",
            "how often do i take mounjaro",
            "medication history",
            "when did i inject ozempic",
        ]
        var correct = 0
        for query in cases {
            let tools = ToolRanker.rank(query: query.lowercased(), screen: .food)
            if tools.first?.name == "medication_info" { correct += 1 }
            else { print("MISS (med_info): '\(query)' → \(tools.first?.name ?? "nil")") }
        }
        print("📊 medication_info routing: \(correct)/\(cases.count)")
        XCTAssertGreaterThanOrEqual(correct, cases.count - 1, "At most 1 medication history routing miss")
    }

    @MainActor func testToolRanker_LoggingQueriesStayOnLogMedication() {
        let cases = [
            "took my ozempic",
            "injected semaglutide",
            "log metformin 500mg",
            "took my glp1 shot",
        ]
        for query in cases {
            let tools = ToolRanker.rank(query: query.lowercased(), screen: .food)
            let top = tools.first?.name
            XCTAssertNotEqual(top, "medication_info",
                "'\(query)' should NOT route to medication_info (got \(top ?? "nil"))")
        }
    }

    // MARK: - Tool registration

    @MainActor func testMedicationInfoToolIsRegistered() {
        let tool = ToolRegistry.shared.tool(named: "medication_info")
        XCTAssertNotNil(tool, "medication_info must be registered in ToolRegistration.registerAll()")
    }
}
