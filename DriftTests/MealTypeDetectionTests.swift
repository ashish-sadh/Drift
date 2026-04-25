import Foundation
@testable import DriftCore
import Testing
@testable import Drift

// MARK: - MealType.fromHour — time-based detection (8 boundary cases)

@Test func mealTypeFromHour_4_isSnack()     { #expect(MealType.fromHour(4)  == .snack)     }
@Test func mealTypeFromHour_5_isBreakfast() { #expect(MealType.fromHour(5)  == .breakfast) }
@Test func mealTypeFromHour_9_isBreakfast() { #expect(MealType.fromHour(9)  == .breakfast) }
@Test func mealTypeFromHour_10_isLunch()    { #expect(MealType.fromHour(10) == .lunch)     }
@Test func mealTypeFromHour_14_isLunch()    { #expect(MealType.fromHour(14) == .lunch)     }
@Test func mealTypeFromHour_15_isSnack()    { #expect(MealType.fromHour(15) == .snack)     }
@Test func mealTypeFromHour_18_isDinner()   { #expect(MealType.fromHour(18) == .dinner)    }
@Test func mealTypeFromHour_22_isSnack()    { #expect(MealType.fromHour(22) == .snack)     }

// MARK: - Keyword override paths

@Test func mealTypeFromParser_explicitBreakfast_setsHint() {
    let intent = AIActionExecutor.parseFoodIntent("log eggs for breakfast")
    #expect(intent?.mealHint == "breakfast")
}

@Test func mealTypeFromParser_explicitDinner_setsHint() {
    let intent = AIActionExecutor.parseFoodIntent("log chicken for dinner")
    #expect(intent?.mealHint == "dinner")
}

@Test func mealTypeFromParser_noKeyword_hintIsNil() {
    let intent = AIActionExecutor.parseFoodIntent("log eggs")
    #expect(intent?.mealHint == nil, "No keyword → nil hint; caller applies fromHour()")
}

@Test func mealTypeFromParser_explicitLunch_setsHint() {
    let intent = AIActionExecutor.parseFoodIntent("had salad for lunch")
    #expect(intent?.mealHint == "lunch")
}
