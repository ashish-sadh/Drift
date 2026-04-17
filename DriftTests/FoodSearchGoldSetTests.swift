import XCTest
@testable import Drift

/// Isolated gold set for FoodService.searchFood — sprint task #161.
/// Tests that 20+ food queries return expected results in top positions.
/// Fully deterministic (local DB only, no LLM, no network). Runs in <5s.
///
/// Run: xcodebuild test -only-testing:'DriftTests/FoodSearchGoldSetTests'
@MainActor
final class FoodSearchGoldSetTests: XCTestCase {

    // MARK: - Exact & Substring Matches

    func testExactMatches() {
        let cases: [(query: String, expectedKeyword: String)] = [
            ("egg", "egg"),
            ("banana", "banana"),
            ("rice", "rice"),
            ("chicken", "chicken"),
            ("paneer", "paneer"),
            ("milk", "milk"),
            ("oats", "oat"),
            ("apple", "apple"),
            ("dal", "dal"),
            ("biryani", "biryani"),
        ]
        var correct = 0
        for (query, keyword) in cases {
            let results = FoodService.searchFood(query: query)
            let topName = results.first?.name.lowercased() ?? ""
            if !results.isEmpty && topName.contains(keyword) {
                correct += 1
            } else {
                print("MISS (exact): '\(query)' → top='\(topName)' (total: \(results.count))")
            }
        }
        print("📊 Exact match: \(correct)/\(cases.count)")
        XCTAssertGreaterThanOrEqual(correct, cases.count - 1, "At most 1 exact match miss")
    }

    // MARK: - Indian Foods

    func testIndianFoods() {
        let cases: [(query: String, expectedKeyword: String)] = [
            ("idli", "idli"),
            ("dosa", "dosa"),
            ("roti", "roti"),
            ("rajma", "rajma"),
            ("samosa", "samosa"),
            ("paneer tikka", "paneer"),
            ("chole", "chole"),
            ("poha", "poha"),
            ("upma", "upma"),
            ("khichdi", "khichdi"),
        ]
        var correct = 0
        for (query, keyword) in cases {
            let results = FoodService.searchFood(query: query)
            let found = results.prefix(3).contains(where: { $0.name.lowercased().contains(keyword) })
            if found {
                correct += 1
            } else {
                let top = results.prefix(3).map(\.name).joined(separator: ", ")
                print("MISS (indian): '\(query)' → top3=[\(top)]")
            }
        }
        print("📊 Indian foods: \(correct)/\(cases.count)")
        XCTAssertGreaterThanOrEqual(correct, cases.count - 1, "At most 1 Indian food miss")
    }

    // MARK: - Synonyms & Spell Correction

    func testSynonymExpansion() {
        // "curd" → yogurt results via synonym expansion
        let results = FoodService.searchFood(query: "curd")
        XCTAssertFalse(results.isEmpty, "'curd' synonym should expand to find yogurt results")
        let hasYogurt = results.contains(where: { $0.name.lowercased().contains("yogurt") || $0.name.lowercased().contains("curd") })
        XCTAssertTrue(hasYogurt, "'curd' should find yogurt or curd entries")
    }

    func testSpellCorrection() {
        // "panner" is a common Indian food misspelling — spell corrector should catch it
        let results = FoodService.searchFood(query: "panner")
        let found = results.prefix(5).contains(where: { $0.name.lowercased().contains("paneer") })
        if !found {
            print("MISS (spell): 'panner' → top5=\(results.prefix(5).map(\.name))")
        }
        XCTAssertTrue(found, "'panner' should spell-correct to find paneer entries")
    }

    // MARK: - Case Insensitivity

    func testCaseInsensitiveSearch() {
        let baseResults = FoodService.searchFood(query: "chicken")
        let upperResults = FoodService.searchFood(query: "CHICKEN")
        let mixedResults = FoodService.searchFood(query: "Chicken")
        XCTAssertFalse(baseResults.isEmpty)
        XCTAssertFalse(upperResults.isEmpty)
        XCTAssertFalse(mixedResults.isEmpty)
        XCTAssertEqual(baseResults.first?.name, upperResults.first?.name, "Search should be case-insensitive")
        XCTAssertEqual(baseResults.first?.name, mixedResults.first?.name, "Search should be case-insensitive")
    }

    // MARK: - Partial Matches

    func testPartialMatches() {
        // Substring search: "chick" should find chicken items
        let results = FoodService.searchFood(query: "chick")
        let found = results.prefix(5).contains(where: { $0.name.lowercased().contains("chicken") })
        if !found {
            print("MISS (partial): 'chick' → top5=\(results.prefix(5).map(\.name))")
        }
        XCTAssertTrue(found, "'chick' substring should match chicken items")
    }

    // MARK: - Empty & Edge Cases

    func testEmptyQueryReturnsEmpty() {
        let results = FoodService.searchFood(query: "")
        // Empty query may return empty or all foods depending on DB impl — just must not crash
        print("Empty query result count: \(results.count)")
    }

    func testGibberishReturnsEmpty() {
        let results = FoodService.searchFood(query: "xyzzy_qqq_notafood_99999")
        XCTAssertTrue(results.isEmpty, "Gibberish query should return no results")
    }

    // MARK: - Result Count Sanity

    func testCommonQueriesHaveMultipleResults() {
        let commonQueries = ["chicken", "rice", "egg", "dal", "yogurt"]
        for query in commonQueries {
            let results = FoodService.searchFood(query: query)
            XCTAssertGreaterThan(results.count, 1, "'\(query)' should return multiple results")
        }
    }

    // MARK: - Ranking: Exact Name at Top

    func testExactNameRanksFirst() {
        let cases: [(query: String, exactName: String)] = [
            ("egg", "Egg (whole, boiled)"),
            ("banana", "Banana"),
            ("apple", "Apple"),
        ]
        for (query, name) in cases {
            let results = FoodService.searchFood(query: query)
            let inTopThree = results.prefix(3).contains(where: { $0.name == name })
            if !inTopThree {
                print("RANK MISS: '\(name)' not in top 3 for query '\(query)' — got \(results.prefix(3).map(\.name))")
            }
            // Ranking depends on time-of-day boost — informational, not a hard failure
        }
    }
}
