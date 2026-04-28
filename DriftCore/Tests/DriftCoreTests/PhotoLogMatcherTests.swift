import Foundation
@testable import DriftCore
import Testing

/// Tier-0: pure logic. No network, no cloud vision, no DB.
struct PhotoLogMatcherTests {

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

    // MARK: - Portion Multiplier Parsing

    @Test func portionHalfReturnsPointFive() {
        #expect(PhotoLogMatcher.parsePortionMultiplier("half") == 0.5)
        #expect(PhotoLogMatcher.parsePortionMultiplier("half of it") == 0.5)
        #expect(PhotoLogMatcher.parsePortionMultiplier("I had smaller portion. Half of it") == 0.5)
        #expect(PhotoLogMatcher.parsePortionMultiplier("1/2") == 0.5)
    }

    @Test func portionDoubleReturnsTwo() {
        #expect(PhotoLogMatcher.parsePortionMultiplier("double") == 2.0)
        #expect(PhotoLogMatcher.parsePortionMultiplier("twice the amount") == 2.0)
        #expect(PhotoLogMatcher.parsePortionMultiplier("2x") == 2.0)
    }

    @Test func portionExplicitMultiplier() {
        #expect(PhotoLogMatcher.parsePortionMultiplier("1.5x") == 1.5)
        #expect(PhotoLogMatcher.parsePortionMultiplier("3x") == 3.0)
        #expect(PhotoLogMatcher.parsePortionMultiplier("2.5x") == 2.5)
    }

    @Test func portionPercentage() {
        let result = PhotoLogMatcher.parsePortionMultiplier("50%")
        #expect(result == 0.5)
        let result75 = PhotoLogMatcher.parsePortionMultiplier("75%")
        #expect(result75 == 0.75)
    }

    @Test func portionSmallerReturnsPointFive() {
        #expect(PhotoLogMatcher.parsePortionMultiplier("smaller portion") == 0.5)
        #expect(PhotoLogMatcher.parsePortionMultiplier("smaller") == 0.5)
    }

    @Test func portionLargerReturnsOneFive() {
        #expect(PhotoLogMatcher.parsePortionMultiplier("bigger portion") == 1.5)
        #expect(PhotoLogMatcher.parsePortionMultiplier("larger") == 1.5)
    }

    @Test func portionQuarterReturnsPointTwoFive() {
        #expect(PhotoLogMatcher.parsePortionMultiplier("quarter") == 0.25)
        #expect(PhotoLogMatcher.parsePortionMultiplier("1/4") == 0.25)
    }

    @Test func foodNameReturnsNil() {
        // Food names must not be mistaken for portion cues
        #expect(PhotoLogMatcher.parsePortionMultiplier("paratha") == nil)
        #expect(PhotoLogMatcher.parsePortionMultiplier("palak paneer") == nil)
        #expect(PhotoLogMatcher.parsePortionMultiplier("this is actually rice") == nil)
    }

    @Test func emptyHintReturnsNil() {
        #expect(PhotoLogMatcher.parsePortionMultiplier("") == nil)
        #expect(PhotoLogMatcher.parsePortionMultiplier("   ") == nil)
    }

}
