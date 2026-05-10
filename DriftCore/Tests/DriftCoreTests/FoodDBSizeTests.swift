import Foundation
import Testing
@testable import DriftCore

// Tier-0: foods.json size ceiling (#717).
//
// foods.json ships embedded in the bundle and seeds the DB on cold launch.
// Without a hard cap, USDA-style bulk imports silently bloat install size,
// cold-launch time, and search-result clutter.
//
// Ceiling: 6,000 entries. Hand-curated Indian-first + international cuisine
// sits around 5,000. New imports must be curated, not bulk.

struct FoodDBSizeTests {

    @Test func foodsJSONSizeUnderCeiling() throws {
        // Read from source path — Bundle.module of the test target does not
        // include the source target's resources. The production code path
        // is `Bundle.module` from inside DriftCore (AppDatabase.seedFoodsFromJSON).
        let sourcePath = #filePath
            .replacingOccurrences(of: "Tests/DriftCoreTests/FoodDBSizeTests.swift",
                                  with: "Sources/DriftCore/Resources/foods.json")
        let url = URL(fileURLWithPath: sourcePath)
        let data = try Data(contentsOf: url)
        let decoded = try #require(try JSONSerialization.jsonObject(with: data) as? [Any])
        #expect(decoded.count <= 6000,
            "foods.json has \(decoded.count) entries — ceiling is 6,000. New imports must be curated, not bulk.")
    }
}
