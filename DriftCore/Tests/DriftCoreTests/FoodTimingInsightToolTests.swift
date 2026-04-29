import Foundation
@testable import DriftCore
import Testing

@Test func foodTiming_parseLocalHour_utcMidnight() {
    // "2026-04-27T00:00:00Z" in UTC = midnight UTC
    // parseLocalHour should return the local equivalent hour via Calendar
    let h = FoodTimingInsightTool.parseLocalHour("2026-04-27T12:30:00Z")
    #expect(h != nil, "valid ISO timestamp should parse")
}

@Test func foodTiming_parseLocalHour_invalidReturnsNil() {
    #expect(FoodTimingInsightTool.parseLocalHour("") == nil)
    #expect(FoodTimingInsightTool.parseLocalHour("not-a-date") == nil)
}

@Test func foodTiming_timingStats_lateNightDetection() {
    // Build entries with loggedAt using local time offsets so the test is timezone-agnostic.
    // We use a Date at 22:00 local time to guarantee it crosses the 21:00 threshold.
    var cal = Calendar.current
    var comps = DateComponents()
    comps.year = 2026; comps.month = 4; comps.day = 27
    comps.hour = 22; comps.minute = 0
    guard let lateDate = cal.date(from: comps) else { return }
    let lateISO = DateFormatters.iso8601.string(from: lateDate)

    let entry = FoodEntry(mealLogId: 1, foodName: "Chips", servingSizeG: 0, servings: 1, calories: 200,
                          loggedAt: lateISO, mealType: "snack")
    let stats = FoodTimingInsightTool.timingStats(entries: [entry])
    #expect(stats.lateNightDays == 1)
    #expect(stats.lateNightPct == 100)
}

@Test func foodTiming_timingStats_noLateNight() {
    var cal = Calendar.current
    var comps = DateComponents()
    comps.year = 2026; comps.month = 4; comps.day = 27
    comps.hour = 12; comps.minute = 0
    guard let noonDate = cal.date(from: comps) else { return }
    let noonISO = DateFormatters.iso8601.string(from: noonDate)

    let entry = FoodEntry(mealLogId: 1, foodName: "Lunch", servingSizeG: 0, servings: 1, calories: 500,
                          loggedAt: noonISO, mealType: "lunch")
    let stats = FoodTimingInsightTool.timingStats(entries: [entry])
    #expect(stats.lateNightDays == 0)
    #expect(stats.avgLunchHour != nil)
}

@Test func foodTiming_timingStats_emptyEntries() {
    let stats = FoodTimingInsightTool.timingStats(entries: [])
    #expect(stats.totalLoggedDays == 0)
    #expect(stats.lateNightDays == 0)
    #expect(stats.avgBreakfastHour == nil)
}

@Test func foodTiming_formatHour_noon() {
    let formatted = FoodTimingInsightTool.formatHour(12.0)
    #expect(formatted == "12:00 PM")
}

@Test func foodTiming_formatHour_midnight() {
    let formatted = FoodTimingInsightTool.formatHour(0.0)
    #expect(formatted == "12:00 AM")
}

@Test func foodTiming_formatHour_1am() {
    #expect(FoodTimingInsightTool.formatHour(1.0) == "1:00 AM")
}

@Test func foodTiming_formatHour_9_30pm() {
    #expect(FoodTimingInsightTool.formatHour(21.5) == "9:30 PM")
}

// MARK: - Routing gold set (parseResponse — no LLM, deterministic)

@Test func foodTiming_routing_whenDoIEat() {
    let intent = IntentClassifier.parseResponse(#"{"tool":"food_timing_insight"}"#)
    #expect(intent?.tool == "food_timing_insight")
}

@Test func foodTiming_routing_lateNightQuery() {
    let intent = IntentClassifier.parseResponse(#"{"tool":"food_timing_insight","window_days":"14"}"#)
    #expect(intent?.tool == "food_timing_insight")
    #expect(intent?.params["window_days"] == "14")
}

@Test func foodTiming_routing_weekWindow() {
    let intent = IntentClassifier.parseResponse(#"{"tool":"food_timing_insight","window_days":"7"}"#)
    #expect(intent?.tool == "food_timing_insight")
    #expect(intent?.params["window_days"] == "7")
}

@Test func foodTiming_routing_monthWindow() {
    let intent = IntentClassifier.parseResponse(#"{"tool":"food_timing_insight","window_days":"30"}"#)
    #expect(intent?.tool == "food_timing_insight")
    #expect(intent?.params["window_days"] == "30")
}

@Test func foodTiming_routing_noParamsDefaultsToTool() {
    // Minimal JSON — no window_days — still routes correctly
    let intent = IntentClassifier.parseResponse(#"{"tool":"food_timing_insight","window_days":"0"}"#)
    #expect(intent?.tool == "food_timing_insight")
    #expect(intent?.params["window_days"] == "0")
}

// MARK: - timingStats multi-day

@Test func foodTiming_timingStats_eatingWindowTracksEarliestAndLatest() {
    let cal = Calendar.current
    func localISO(hour: Int, minute: Int = 0) -> String {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 27
        comps.hour = hour; comps.minute = minute
        let date = cal.date(from: comps)!
        return DateFormatters.iso8601.string(from: date)
    }

    let entries = [
        FoodEntry(mealLogId: 1, foodName: "Oats", servingSizeG: 0, servings: 1, calories: 300,
                  loggedAt: localISO(hour: 8), mealType: "breakfast"),
        FoodEntry(mealLogId: 2, foodName: "Rice", servingSizeG: 0, servings: 1, calories: 500,
                  loggedAt: localISO(hour: 13), mealType: "lunch"),
        FoodEntry(mealLogId: 3, foodName: "Dal", servingSizeG: 0, servings: 1, calories: 400,
                  loggedAt: localISO(hour: 20), mealType: "dinner"),
    ]
    let stats = FoodTimingInsightTool.timingStats(entries: entries)
    #expect(stats.earliestMealHour != nil)
    #expect(stats.latestMealHour != nil)
    #expect(stats.earliestMealHour! < stats.latestMealHour!)
    #expect(stats.avgBreakfastHour != nil)
    #expect(stats.avgLunchHour != nil)
    #expect(stats.avgDinnerHour != nil)
    #expect(stats.lateNightDays == 0)
}

@Test func foodTiming_timingStats_multipleDaysCountedOnce() {
    let cal = Calendar.current
    func localISO(day: Int, hour: Int) -> String {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = day; comps.hour = hour; comps.minute = 0
        return DateFormatters.iso8601.string(from: cal.date(from: comps)!)
    }

    let entries = [
        FoodEntry(mealLogId: 1, foodName: "A", servingSizeG: 0, servings: 1, calories: 100,
                  loggedAt: localISO(day: 27, hour: 22), mealType: "snack"),
        FoodEntry(mealLogId: 2, foodName: "B", servingSizeG: 0, servings: 1, calories: 100,
                  loggedAt: localISO(day: 28, hour: 22), mealType: "snack"),
    ]
    let stats = FoodTimingInsightTool.timingStats(entries: entries)
    #expect(stats.lateNightDays == 2)
    #expect(stats.totalLoggedDays == 2)
    #expect(stats.lateNightPct == 100)
}
