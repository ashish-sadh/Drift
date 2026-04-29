import XCTest
@testable import DriftCore

/// Tier-0: deterministic help-card routing — no LLM, no network.
@MainActor
final class HelpCardTests: XCTestCase {

    // MARK: - Routing

    func testHelp_routesToHelpCard() {
        let result = StaticOverrides.match("help")
        guard case .helpCard(let card) = result else {
            XCTFail("Expected .helpCard, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(card.categories.count, 5)
    }

    func testWhatCanYouDo_routesToHelpCard() {
        let result = StaticOverrides.match("what can you do")
        guard case .helpCard = result else {
            XCTFail("Expected .helpCard, got \(String(describing: result))")
            return
        }
    }

    func testWhatCanYouDoQuestion_routesToHelpCard() {
        let result = StaticOverrides.match("what can you do?")
        guard case .helpCard = result else {
            XCTFail("Expected .helpCard, got \(String(describing: result))")
            return
        }
    }

    func testWhatCanIAskYou_routesToHelpCard() {
        let result = StaticOverrides.match("what can i ask you")
        guard case .helpCard = result else {
            XCTFail("Expected .helpCard, got \(String(describing: result))")
            return
        }
    }

    func testWhatDoYouKnow_routesToHelpCard() {
        let result = StaticOverrides.match("what do you know")
        guard case .helpCard = result else {
            XCTFail("Expected .helpCard, got \(String(describing: result))")
            return
        }
    }

    // MARK: - Card structure

    func testDefaultCard_hasFiveCategories() {
        XCTAssertEqual(HelpCardData.defaultCard.categories.count, 5)
    }

    func testDefaultCard_eachCategoryHasTwoExamples() {
        for cat in HelpCardData.defaultCard.categories {
            XCTAssertEqual(cat.examples.count, 2, "Category '\(cat.title)' should have 2 examples")
        }
    }

    func testDefaultCard_categoryTitles() {
        let titles = HelpCardData.defaultCard.categories.map(\.title)
        XCTAssertEqual(titles, ["Food", "Weight", "Exercise", "Health", "Analytics"])
    }

    // MARK: - Non-help phrases do not match help

    func testLogFood_doesNotRouteToHelpCard() {
        let result = StaticOverrides.match("log 2 eggs")
        if case .helpCard = result {
            XCTFail("'log 2 eggs' should not route to helpCard")
        }
    }
}
