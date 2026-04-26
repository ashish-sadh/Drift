import XCTest
@testable import DriftCore
import Foundation

/// Unit tests for the USDA fallback path.
/// Most tests are deterministic (no network). Live search tests are gated behind
/// the USDA_LIVE_TEST=1 environment variable so CI stays fast.
@MainActor
final class USDAFallbackTests: XCTestCase {

    // MARK: - FoodItem struct

    func testFoodItem_constructsAndPreservesValues() {
        let item = USDAFoodService.FoodItem(
            name: "Chicken Breast",
            calories: 165,
            proteinG: 31,
            carbsG: 0,
            fatG: 3.6,
            fiberG: 0,
            servingSizeG: 100
        )
        XCTAssertEqual(item.name, "Chicken Breast")
        XCTAssertEqual(item.calories, 165)
        XCTAssertEqual(item.proteinG, 31)
        XCTAssertEqual(item.carbsG, 0)
        XCTAssertEqual(item.fatG, 3.6, accuracy: 0.01)
        XCTAssertEqual(item.servingSizeG, 100)
    }

    func testFoodItem_zeroFiberIsValid() {
        let item = USDAFoodService.FoodItem(
            name: "Egg", calories: 155, proteinG: 13, carbsG: 1.1, fatG: 11, fiberG: 0, servingSizeG: 100
        )
        XCTAssertEqual(item.fiberG, 0)
    }

    // MARK: - Fixture file

    func testFixture_fileExists() {
        let url = fixtureURL()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
            "top-500-foods.txt not found at \(url.path)")
    }

    func testFixture_containsExpectedFoods() {
        let foods = loadFixtureFoods()
        XCTAssertGreaterThanOrEqual(foods.count, 100, "fixture should have ≥100 foods")

        let required = ["apple", "chicken breast", "biryani", "eggs", "oatmeal", "salmon"]
        for food in required {
            XCTAssertTrue(
                foods.contains(where: { $0.lowercased().contains(food.lowercased()) }),
                "fixture missing expected food: \(food)"
            )
        }
    }

    func testFixture_noBlankOrCommentLines() {
        let foods = loadFixtureFoods()
        for food in foods {
            XCTAssertFalse(food.hasPrefix("#"), "comment line leaked through: \(food)")
            XCTAssertFalse(food.isEmpty, "empty line leaked through")
        }
    }

    // MARK: - searchWithFallback — online disabled (no network)

    func testSearchWithFallback_onlineDisabled_returnsLocalOnly() async {
        let saved = Preferences.onlineFoodSearchEnabled
        Preferences.onlineFoodSearchEnabled = false
        defer { Preferences.onlineFoodSearchEnabled = saved }

        // "egg" is in local DB — should return without any USDA call
        let results = await FoodService.searchWithFallback(query: "egg")
        XCTAssertFalse(results.isEmpty, "local DB should have egg")
    }

    // MARK: - Live USDA tests (gated)

    func testLiveSearch_commonFoods() async throws {
        guard ProcessInfo.processInfo.environment["USDA_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set USDA_LIVE_TEST=1 to run live USDA tests")
        }

        let queries = ["apple", "chicken breast", "oatmeal", "egg", "brown rice"]
        var hits = 0
        for query in queries {
            let results = try await USDAFoodService.search(query: query, limit: 3)
            if let first = results.first, first.calories > 0 {
                hits += 1
            }
        }
        let pct = Int(Double(hits) / Double(queries.count) * 100)
        print("📊 USDAFallbackTests/live: \(hits)/\(queries.count) returned kcal>0 (\(pct)%)")
        XCTAssertGreaterThanOrEqual(hits, queries.count * 4 / 5, "Live USDA: <80% returned calories")
    }

    func testLiveSearch_indianFoods() async throws {
        guard ProcessInfo.processInfo.environment["USDA_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set USDA_LIVE_TEST=1 to run live USDA tests")
        }

        let queries = ["biryani", "dal", "chapati", "paneer", "samosa"]
        var hits = 0
        for query in queries {
            let results = try await USDAFoodService.search(query: query, limit: 3)
            if results.first != nil { hits += 1 }
        }
        print("📊 USDAFallbackTests/live-indian: \(hits)/\(queries.count) returned results")
        // Indian foods have lower USDA coverage — warn but don't fail
        XCTAssertGreaterThanOrEqual(hits, 2, "USDA returned 0 results for most Indian foods")
    }

    // MARK: - Helpers

    private func fixtureURL() -> URL {
        // Works both in unit tests (bundle) and in direct file access
        if let bundleURL = Bundle(for: USDAFallbackTests.self)
            .url(forResource: "top-500-foods", withExtension: "txt") {
            return bundleURL
        }
        // Fall back to path relative to source root
        let srcRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // DriftTests/
            .appendingPathComponent("Fixtures/top-500-foods.txt")
        return srcRoot
    }

    private func loadFixtureFoods() -> [String] {
        guard let text = try? String(contentsOf: fixtureURL(), encoding: .utf8) else { return [] }
        return text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }
}
