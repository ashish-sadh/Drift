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
