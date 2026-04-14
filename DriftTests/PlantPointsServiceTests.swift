import Foundation
import Testing
@testable import Drift

// MARK: - classify (6 tests)

@Test func classifyBananaIsPlant() {
    #expect(PlantPointsService.classify("banana") == .plant)
}

@Test func classifyBasilIsHerbSpice() {
    #expect(PlantPointsService.classify("basil") == .herbSpice)
}

@Test func classifyTurmericIsHerbSpice() {
    #expect(PlantPointsService.classify("turmeric") == .herbSpice)
}

@Test func classifyChickenIsNotPlant() {
    #expect(PlantPointsService.classify("chicken breast") == .notPlant)
}

@Test func classifyPaneerIsNotPlant() {
    #expect(PlantPointsService.classify("paneer") == .notPlant)
}

@Test func classifyBreadIsNotPlant() {
    #expect(PlantPointsService.classify("bread") == .notPlant)
}

// MARK: - calculate from strings (6 tests)

@Test func calculateEmptyListIsZero() {
    let result = PlantPointsService.calculate(from: [String]())
    #expect(result.total == 0)
    #expect(result.uniquePlants.isEmpty)
    #expect(result.uniqueHerbsSpices.isEmpty)
}

@Test func calculateSinglePlantOnePoint() {
    let result = PlantPointsService.calculate(from: ["spinach"])
    #expect(result.fullPoints == 1)
    #expect(result.quarterPoints == 0)
    #expect(result.total == 1.0)
}

@Test func calculateHerbIsQuarterPoint() {
    let result = PlantPointsService.calculate(from: ["basil"])
    #expect(result.quarterPoints == 0.25)
    #expect(result.fullPoints == 0)
}

@Test func calculateDuplicatesCountOnce() {
    let result = PlantPointsService.calculate(from: ["banana", "banana", "banana"])
    #expect(result.uniquePlants.count == 1)
    #expect(result.fullPoints == 1.0)
}

@Test func calculateMixedFoodsCorrectTotal() {
    // 3 plants (1pt each) + 2 herbs (0.25pt each) = 3.5
    let result = PlantPointsService.calculate(from: ["spinach", "broccoli", "tomato", "basil", "oregano"])
    #expect(result.fullPoints == 3)
    #expect(result.quarterPoints == 0.5)
    #expect(result.total == 3.5)
}

@Test func calculateNonPlantFoodsSkipped() {
    let result = PlantPointsService.calculate(from: ["chicken", "whey protein", "butter"])
    #expect(result.total == 0)
}

// MARK: - Hindi aliases (3 tests)

@Test func palakResolvesToSpinach() {
    let result = PlantPointsService.calculate(from: ["palak"])
    #expect(result.uniquePlants.contains("spinach"))
}

@Test func rajmaResolvesToKidneyBeans() {
    let result = PlantPointsService.calculate(from: ["rajma"])
    #expect(result.uniquePlants.contains("kidney beans"))
}

@Test func chanaMeansChickpeas() {
    let result = PlantPointsService.calculate(from: ["chana"])
    #expect(result.uniquePlants.contains("chickpeas"))
}

// MARK: - NOVA processing (4 tests)

@Test func nova4ItemSkippedEntirely() {
    let item = PlantPointsService.FoodItem(name: "spinach", ingredients: nil, novaGroup: 4)
    let result = PlantPointsService.calculate(from: [item])
    #expect(result.total == 0)
}

@Test func nova3UsesIngredientsNotName() {
    // name is a non-plant word, ingredients have a plant — NOVA 3 should count ingredients
    let item = PlantPointsService.FoodItem(
        name: "sauce", ingredients: ["tomato", "onion"], novaGroup: 3
    )
    let result = PlantPointsService.calculate(from: [item])
    #expect(result.fullPoints >= 1)
}

@Test func nova1CountsDirectly() {
    let item = PlantPointsService.FoodItem(name: "banana", ingredients: nil, novaGroup: 1)
    let result = PlantPointsService.calculate(from: [item])
    #expect(result.fullPoints == 1)
}

@Test func multiIngredientFoodUsesIngredients() {
    // No NOVA, but has multiple ingredients → use ingredient list
    let item = PlantPointsService.FoodItem(
        name: "dal tadka", ingredients: ["lentils", "tomato", "garlic", "cumin"], novaGroup: nil
    )
    let result = PlantPointsService.calculate(from: [item])
    #expect(result.fullPoints >= 2) // lentils/dal + tomato + garlic at minimum
}

// MARK: - Spice blend expansion (3 tests)

@Test func garamMasalaExpandsToFiveSpices() {
    let expanded = PlantPointsService.expandSpiceBlends(["garam masala"])
    #expect(expanded.count == 5)
    #expect(expanded.contains("cumin"))
    #expect(expanded.contains("cardamom"))
}

@Test func unknownNamePassesThrough() {
    let expanded = PlantPointsService.expandSpiceBlends(["chicken tikka"])
    #expect(expanded == ["chicken tikka"])
}

@Test func mixedBlendsAndNonBlends() {
    let expanded = PlantPointsService.expandSpiceBlends(["spinach", "curry powder"])
    #expect(expanded.contains("spinach"))
    #expect(expanded.contains("turmeric")) // curry powder contains turmeric
    #expect(!expanded.contains("curry powder")) // blend replaced
}
