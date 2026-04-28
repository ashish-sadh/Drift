import Foundation
@testable import DriftCore
import Testing

/// Tier-0: pure logic + seeded in-memory DB. No network, no cloud vision.
struct PhotoLogMatcherTests {

    // MARK: - Word Overlap

    @Test func exactMatchIsFullOverlap() {
        #expect(PhotoLogMatcher.wordOverlap("aloo gobi", "aloo gobi") == 1.0)
    }

    @Test func partialOverlap() {
        let overlap = PhotoLogMatcher.wordOverlap("scrambled eggs", "eggs")
        #expect(overlap == 0.5)   // 1 of 2 query words found
    }

    @Test func noOverlapIsZero() {
        #expect(PhotoLogMatcher.wordOverlap("biryani", "apple") == 0.0)
    }

    @Test func overlapIsCaseInsensitive() {
        #expect(PhotoLogMatcher.wordOverlap("Dal Tadka", "dal tadka") == 1.0)
    }

    @Test func emptyQueryReturnsZero() {
        #expect(PhotoLogMatcher.wordOverlap("", "dal") == 0.0)
    }

    @Test func singleWordQueryFullMatch() {
        #expect(PhotoLogMatcher.wordOverlap("biryani", "chicken biryani") == 1.0)
    }

    // MARK: - Portion Defaults

    @Test func curryDefault200g() {
        #expect(PhotoLogMatcher.portionDefault(category: "Indian Curries", recognizedName: "aloo gobi") == 200)
    }

    @Test func indianMealDefault200g() {
        #expect(PhotoLogMatcher.portionDefault(category: "Indian Meals", recognizedName: "thali") == 200)
    }

    @Test func beverageDefault250ml() {
        #expect(PhotoLogMatcher.portionDefault(category: "Beverages", recognizedName: "mango juice") == 250)
    }

    @Test func smoothieDetectedByName() {
        #expect(PhotoLogMatcher.portionDefault(category: "", recognizedName: "banana smoothie") == 250)
    }

    @Test func chaiDetectedByName() {
        #expect(PhotoLogMatcher.portionDefault(category: "", recognizedName: "masala chai") == 250)
    }

    @Test func lassiDetectedByName() {
        #expect(PhotoLogMatcher.portionDefault(category: "", recognizedName: "mango lassi") == 250)
    }

    @Test func riceDefault150g() {
        #expect(PhotoLogMatcher.portionDefault(category: "Indian Staples", recognizedName: "basmati rice") == 150)
    }

    @Test func grainDefault150g() {
        #expect(PhotoLogMatcher.portionDefault(category: "Grains", recognizedName: "quinoa") == 150)
    }

    @Test func saladDefault100g() {
        #expect(PhotoLogMatcher.portionDefault(category: "Salads", recognizedName: "garden salad") == 100)
    }

    @Test func dessertDefault80g() {
        #expect(PhotoLogMatcher.portionDefault(category: "Indian Sweets", recognizedName: "gulab jamun") == 80)
    }

    @Test func proteinDefault100g() {
        #expect(PhotoLogMatcher.portionDefault(category: "Chicken", recognizedName: "grilled chicken") == 100)
    }

    @Test func fruitDefault100g() {
        #expect(PhotoLogMatcher.portionDefault(category: "Fruits", recognizedName: "apple") == 100)
    }

    @Test func unknownCategoryDefaultsTo150g() {
        #expect(PhotoLogMatcher.portionDefault(category: "Unknown", recognizedName: "mystery dish") == 150)
    }

    // MARK: - DB Matching (seeded in-memory DB)

    @Test func matchesExactNameFromDB() throws {
        let db = try AppDatabase.empty()
        var food = Food(name: "Dal Tadka", category: "Indian Curries",
                       servingSize: 200, servingUnit: "g",
                       calories: 120, proteinG: 6, carbsG: 18, fatG: 3)
        try db.saveScannedFood(&food)

        let match = PhotoLogMatcher.matchFood(recognizedName: "dal tadka", db: db)
        let name = try #require(match).name
        #expect(name.lowercased().contains("dal"))
    }

    @Test func matchesPartialNameAboveThreshold() throws {
        let db = try AppDatabase.empty()
        var food = Food(name: "Scrambled Eggs", category: "Breakfast",
                       servingSize: 100, servingUnit: "g",
                       calories: 148, proteinG: 10, carbsG: 1, fatG: 11)
        try db.saveScannedFood(&food)

        let match = PhotoLogMatcher.matchFood(recognizedName: "scrambled eggs", db: db)
        #expect(match != nil)
    }

    @Test func rejectsLowOverlapMatch() throws {
        let db = try AppDatabase.empty()
        var food = Food(name: "Oat Bran Muffin", category: "Bakery",
                       servingSize: 80, servingUnit: "g",
                       calories: 200, proteinG: 5, carbsG: 30, fatG: 7)
        try db.saveScannedFood(&food)

        // "oats" ≠ "oat" — no shared words, overlap = 0.0, below threshold
        let match = PhotoLogMatcher.matchFood(recognizedName: "oats", db: db)
        #expect(match == nil)
    }

    @Test func returnsNilWhenDBIsEmpty() throws {
        let db = try AppDatabase.empty()
        let match = PhotoLogMatcher.matchFood(recognizedName: "aloo gobi", db: db)
        #expect(match == nil)
    }

    @Test func fuzzyMatchAmbiguousName() throws {
        let db = try AppDatabase.empty()
        var food = Food(name: "Chicken Biryani", category: "Indian Meals",
                       servingSize: 300, servingUnit: "g",
                       calories: 350, proteinG: 22, carbsG: 42, fatG: 9)
        try db.saveScannedFood(&food)

        let match = PhotoLogMatcher.matchFood(recognizedName: "biryani", db: db)
        #expect(match != nil)
    }
}
