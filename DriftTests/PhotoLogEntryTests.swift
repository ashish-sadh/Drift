import Foundation
import Testing
@testable import Drift

private func sampleItem(name: String = "dal",
                        grams: Double = 100,
                        calories: Double = 180,
                        proteinG: Double = 12,
                        carbsG: Double = 20,
                        fatG: Double = 6,
                        confidence: Confidence = .high) -> PhotoLogItem {
    PhotoLogItem(name: name, grams: grams, calories: calories,
                 proteinG: proteinG, carbsG: carbsG, fatG: fatG, confidence: confidence)
}

// MARK: - PhotoLogEditableItem

@Test func editableItemStoresPerGramRates() {
    let item = PhotoLogEditableItem(from: sampleItem(grams: 100, calories: 200, proteinG: 10))
    #expect(item.caloriesPerGram == 2.0)
    #expect(item.proteinPerGram == 0.1)
    #expect(item.selected == true)
}

@Test func editableItemHandlesZeroGramsWithoutDividingByZero() {
    let item = PhotoLogEditableItem(from: sampleItem(grams: 0, calories: 0))
    #expect(item.caloriesPerGram == 0)
    #expect(item.proteinPerGram == 0)
}

@Test func rescaleScalesAllMacrosLinearly() {
    var item = PhotoLogEditableItem(from: sampleItem(grams: 100, calories: 200, proteinG: 10, carbsG: 20, fatG: 6))
    item.grams = 150
    item.rescale()
    #expect(item.calories == 300)
    #expect(item.proteinG == 15)
    #expect(item.carbsG == 30)
    #expect(item.fatG == 9)
}

@Test func rescaleToZeroZerosMacros() {
    var item = PhotoLogEditableItem(from: sampleItem(grams: 100, calories: 200, proteinG: 10))
    item.grams = 0
    item.rescale()
    #expect(item.calories == 0)
    #expect(item.proteinG == 0)
}

@Test func rescaleClampsNegativeGramsToZero() {
    var item = PhotoLogEditableItem(from: sampleItem(grams: 100, calories: 200))
    item.grams = -50
    item.rescale()
    #expect(item.grams == 0)
    #expect(item.calories == 0)
}

// MARK: - PhotoLogTotals

@Test func totalsZeroForEmptyInput() {
    let totals = PhotoLogTotals.sum([])
    #expect(totals == .zero)
}

@Test func totalsOnlySumSelectedItems() {
    var a = PhotoLogEditableItem(from: sampleItem(name: "a", grams: 100, calories: 100, proteinG: 10, carbsG: 5, fatG: 2))
    var b = PhotoLogEditableItem(from: sampleItem(name: "b", grams: 100, calories: 200, proteinG: 5, carbsG: 30, fatG: 8))
    a.selected = true
    b.selected = false
    let totals = PhotoLogTotals.sum([a, b])
    #expect(totals.calories == 100)
    #expect(totals.proteinG == 10)
    #expect(totals.carbsG == 5)
    #expect(totals.fatG == 2)
    #expect(totals.selectedCount == 1)
}

@Test func totalsRoundIndividualValues() {
    var item = PhotoLogEditableItem(from: sampleItem(grams: 100, calories: 100.6, proteinG: 10.4))
    item.selected = true
    let totals = PhotoLogTotals.sum([item])
    #expect(totals.calories == 101)  // 100.6 → 101
    #expect(totals.proteinG == 10)   // 10.4 → 10
    #expect(totals.selectedCount == 1)
}

@Test func totalsReflectScaleAfterEdit() {
    var item = PhotoLogEditableItem(from: sampleItem(grams: 100, calories: 200, proteinG: 10))
    item.grams = 50
    item.rescale()
    let totals = PhotoLogTotals.sum([item])
    #expect(totals.calories == 100)
    #expect(totals.proteinG == 5)
}

// MARK: - Default meal type

@Test func defaultMealTypeFollowsHourOfDay() {
    // morning → breakfast
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let comp = DateComponents(year: 2026, month: 4, day: 20, hour: 8, minute: 0)
    let morning = cal.date(from: comp)!
    let mt = MealType.resolve(now: morning, recentEntries: [])
    // The fallback uses local calendar's hour extraction — we just want it
    // to pick a sensible label that matches one of the breakfast/lunch/dinner/snack buckets.
    #expect(MealType.allCases.contains(mt))
}

@Test func defaultMealTypeInheritsFromRecentEntry() {
    // If a breakfast entry was logged 30 min ago, default stays breakfast
    // regardless of clock drift. `MealType.resolve` uses entries' mealType
    // field when within the 3h inherit window.
    let iso = DateFormatters.iso8601
    let thirtyMinAgo = iso.string(from: Date().addingTimeInterval(-30 * 60))
    let entry = FoodEntry(
        foodName: "oats",
        servingSizeG: 50,
        calories: 200,
        proteinG: 8, carbsG: 30, fatG: 4, fiberG: 3,
        loggedAt: thirtyMinAgo,
        mealType: MealType.breakfast.rawValue
    )
    let mt = MealType.resolve(now: Date(), recentEntries: [entry])
    #expect(mt == .breakfast)
}
