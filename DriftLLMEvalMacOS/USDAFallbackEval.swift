import XCTest
import DriftCore
import Foundation

/// Live USDA coverage eval — queries 100 foods from the top-500-foods.txt fixture
/// and asserts ≥95% return kcal > 0 with at least one non-zero macro.
/// Gated behind DRIFT_USDA_EVAL=1 so it never runs in CI.
/// Rate-limited: USDAFoodService caps at 50 req/session; eval runs 50 queries per pass.
final class USDAFallbackEval: XCTestCase {

    // MARK: - Coverage eval

    @MainActor
    func testUSDA_top50Coverage() async throws {
        guard ProcessInfo.processInfo.environment["DRIFT_USDA_EVAL"] == "1" else {
            throw XCTSkip("Set DRIFT_USDA_EVAL=1 to run USDA coverage eval")
        }

        let foods: [String] = Array(loadFixtureFoods().prefix(50))
        guard !foods.isEmpty else {
            XCTFail("fixture empty — run from Drift workspace root")
            return
        }

        var hits = 0
        var misses: [String] = []

        for query in foods {
            let results = await safeSearch(query: query)
            if let first = results.first, first.calories > 0,
               (first.proteinG > 0 || first.carbsG > 0 || first.fatG > 0) {
                hits += 1
            } else {
                misses.append(query)
            }
        }

        let pct = Int(Double(hits) / Double(foods.count) * 100)
        print("📊 USDAFallbackEval/top50: \(hits)/\(foods.count) (\(pct)%)")
        if !misses.isEmpty {
            print("❌ Misses: \(misses.joined(separator: ", "))")
        }

        XCTAssertGreaterThanOrEqual(
            Double(hits) / Double(foods.count), 0.95,
            "USDA coverage \(pct)% — below 95% threshold. Misses: \(misses)"
        )
    }

    @MainActor
    func testUSDA_indianFoodsCoverage() async throws {
        guard ProcessInfo.processInfo.environment["DRIFT_USDA_EVAL"] == "1" else {
            throw XCTSkip("Set DRIFT_USDA_EVAL=1 to run USDA coverage eval")
        }

        let indianFoods = [
            "biryani", "chicken biryani", "dal", "dal tadka", "rajma", "chole",
            "palak paneer", "butter chicken", "tandoori chicken", "roti",
            "chapati", "naan", "paratha", "idli", "dosa", "samosa",
            "paneer", "khichdi", "upma", "poha",
        ]

        var hits = 0
        var misses: [String] = []

        for query in indianFoods {
            let results = await safeSearch(query: query)
            if results.first != nil { hits += 1 } else { misses.append(query) }
        }

        let pct = Int(Double(hits) / Double(indianFoods.count) * 100)
        print("📊 USDAFallbackEval/indian: \(hits)/\(indianFoods.count) (\(pct)%)")
        if !misses.isEmpty {
            print("⚠️ Indian food misses (expected): \(misses.joined(separator: ", "))")
        }

        // Indian food USDA coverage is lower — warn at 60%, not a hard failure
        XCTAssertGreaterThanOrEqual(
            Double(hits) / Double(indianFoods.count), 0.60,
            "USDA Indian food coverage \(pct)% — below 60% soft threshold"
        )
    }

    // MARK: - Helpers

    @MainActor
    private func safeSearch(query: String) async -> [USDAFoodService.FoodItem] {
        (try? await USDAFoodService.search(query: query, limit: 3)) ?? []
    }

    private func fixtureURL() -> URL? {
        // Resolve relative to this source file
        let srcRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()          // DriftLLMEvalMacOS/
            .deletingLastPathComponent()          // Drift/
            .appendingPathComponent("DriftTests/Fixtures/top-500-foods.txt")
        return FileManager.default.fileExists(atPath: srcRoot.path) ? srcRoot : nil
    }

    private func loadFixtureFoods() -> [String] {
        guard let url = fixtureURL(),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }
}
