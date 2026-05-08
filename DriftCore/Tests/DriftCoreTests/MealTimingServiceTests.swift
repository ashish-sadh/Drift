import XCTest
@testable import DriftCore

final class MealTimingServiceTests: XCTestCase {

    // MARK: - Median

    /// 10 lunch entries with known times → median should be the middle value
    /// (or interpolation of the two middles for even counts). Uses ISO 8601
    /// timestamps via the same parser the production scheduler uses.
    func testMedianTimeReturnsMiddleValueWhenAtThreshold() throws {
        // 10 lunch entries at hours 11.0, 11.5, 12.0, 12.0, 12.5, 13.0, 13.0, 13.5, 14.0, 14.5
        // Sorted middle pair → (12.5 + 13.0) / 2 = 12.75 → 12:45
        let hours = [11.0, 11.5, 12.0, 12.0, 12.5, 13.0, 13.0, 13.5, 14.0, 14.5]
        let entries = hours.map { lunchEntry(atHour: $0) }

        let median = try XCTUnwrap(MealTimingService.medianTime(for: .lunch, entries: entries))
        let comps = Calendar.current.dateComponents([.hour, .minute], from: median)
        XCTAssertEqual(comps.hour, 12)
        XCTAssertEqual(comps.minute, 45)
    }

    func testMedianTimeReturnsNilBelowThreshold() {
        // 9 entries — one short of the 10-sample minimum.
        let entries = (0..<9).map { lunchEntry(atHour: 12.0 + Double($0) * 0.1) }
        XCTAssertNil(MealTimingService.medianTime(for: .lunch, entries: entries))
    }

    func testMedianTimeIsImmuneToOutliers() throws {
        // 9 lunches at noon + 1 outlier at 5pm → median stays at noon
        // (mean would shift up to ~12:30 — that's the bug we're fixing).
        var entries = (0..<9).map { _ in lunchEntry(atHour: 12.0) }
        entries.append(lunchEntry(atHour: 17.0))
        let median = try XCTUnwrap(MealTimingService.medianTime(for: .lunch, entries: entries))
        let comps = Calendar.current.dateComponents([.hour, .minute], from: median)
        XCTAssertEqual(comps.hour, 12)
        XCTAssertEqual(comps.minute, 0)
    }

    func testMedianTimeIgnoresOtherMealPeriods() {
        // 5 lunches, 5 breakfasts at noon → for .breakfast we have 5 (below
        // threshold) so the breakfast computation must NOT pick up the lunches.
        var entries = (0..<5).map { _ in lunchEntry(atHour: 13.0) }
        entries.append(contentsOf: (0..<5).map { _ in entry(meal: "breakfast", hour: 12.0) })
        XCTAssertNil(MealTimingService.medianTime(for: .breakfast, entries: entries))
    }

    func testMedianTimeRejectsSnacks() {
        let entries = (0..<20).map { _ in entry(meal: "snack", hour: 15.0) }
        XCTAssertNil(MealTimingService.medianTime(for: .snack, entries: entries))
    }

    // MARK: - IQR

    /// 11 evenly-spaced values 11.0…16.0 (step 0.5). R-7 percentiles:
    /// p25 = interp(idx 2.5) = 12.25, p75 = interp(idx 7.5) = 14.75 → IQR = 2.5
    func testInterquartileRangeAt11SortedValues() throws {
        let hours = [11.0, 11.5, 12.0, 12.5, 13.0, 13.5, 14.0, 14.5, 15.0, 15.5, 16.0]
        let entries = hours.map { lunchEntry(atHour: $0) }
        let iqr = try XCTUnwrap(
            MealTimingService.interquartileRangeHours(for: .lunch, entries: entries)
        )
        XCTAssertEqual(iqr, 2.5, accuracy: 0.0001)
    }

    func testIQRReturnsNilBelowThreshold() {
        let entries = (0..<5).map { lunchEntry(atHour: 12.0 + Double($0) * 0.5) }
        XCTAssertNil(MealTimingService.interquartileRangeHours(for: .lunch, entries: entries))
    }

    // MARK: - reminderSlots — patterns path

    func testReminderSlotsUsesMedianPlusOffsetWhenPatternsOnAndThresholdMet() throws {
        // 10 lunches at 12:30 → median 12:30 → +30 min = 13:00
        let entries = (0..<10).map { _ in lunchEntry(atHour: 12.5) }

        let slots = MealTimingService.reminderSlots(
            entries: entries,
            usePatterns: true
        )
        let lunch = try XCTUnwrap(slots.first { $0.mealPeriod == .lunch })
        XCTAssertTrue(lunch.usedPattern)
        XCTAssertEqual(lunch.triggerHour, 13)
        XCTAssertEqual(lunch.triggerMinute, 0)
    }

    /// Below threshold falls back to the fixed default for that meal.
    /// Other meals with no data also fall back. Both share `usedPattern == false`.
    func testReminderSlotsFallsBackToFixedDefaultsBelowThreshold() throws {
        // 5 lunches (below 10-entry threshold) and no other meals.
        let entries = (0..<5).map { _ in lunchEntry(atHour: 12.5) }

        let slots = MealTimingService.reminderSlots(
            entries: entries,
            usePatterns: true
        )
        XCTAssertEqual(slots.count, 3, "All three meals should produce a slot — pattern or default")
        for slot in slots {
            XCTAssertFalse(slot.usedPattern, "All slots should be fixed defaults — none meet threshold")
        }
        let lunch = try XCTUnwrap(slots.first { $0.mealPeriod == .lunch })
        XCTAssertEqual(lunch.triggerHour, 13)
        XCTAssertEqual(lunch.triggerMinute, 0)
    }

    /// usePatterns == false → ignore data entirely, use fixed defaults
    /// even when the user has plenty of history.
    func testReminderSlotsUsesFixedDefaultsWhenPatternsOff() throws {
        let entries = (0..<30).map { _ in lunchEntry(atHour: 12.5) }
        let slots = MealTimingService.reminderSlots(entries: entries, usePatterns: false)
        for slot in slots {
            XCTAssertFalse(slot.usedPattern)
        }
        let dinner = try XCTUnwrap(slots.first { $0.mealPeriod == .dinner })
        XCTAssertEqual(dinner.triggerHour, 19)
        XCTAssertEqual(dinner.triggerMinute, 30)
    }

    // MARK: - reminderSlots — skip-if-logged

    /// Periods present in `loggedToday` are excluded entirely. This is the
    /// production "no point nudging at 1pm if lunch is already in the log"
    /// path — moved from MealReminderScheduler.slotsToFire.
    func testReminderSlotsExcludesAlreadyLoggedPeriods() {
        let entries = (0..<10).map { _ in lunchEntry(atHour: 12.5) }

        let slots = MealTimingService.reminderSlots(
            entries: entries,
            usePatterns: true,
            loggedToday: [.lunch]
        )
        XCTAssertNil(slots.first(where: { $0.mealPeriod == .lunch }))
        XCTAssertNotNil(slots.first(where: { $0.mealPeriod == .breakfast }))
        XCTAssertNotNil(slots.first(where: { $0.mealPeriod == .dinner }))
    }

    /// Snacks are never scheduled regardless of how many snack entries
    /// exist or what flags are set.
    func testReminderSlotsNeverIncludesSnacks() {
        let entries = (0..<30).map { _ in entry(meal: "snack", hour: 15.0) }
        let slots = MealTimingService.reminderSlots(entries: entries, usePatterns: true)
        XCTAssertNil(slots.first(where: { $0.mealPeriod == .snack }))
    }

    // MARK: - Notification body / identifier

    func testNotificationBodyDifferentiatesPatternVsDefault() {
        let pattern = MealTimingService.ReminderSlot(
            mealPeriod: .lunch, triggerHour: 13, triggerMinute: 0, usedPattern: true
        )
        let fallback = MealTimingService.ReminderSlot(
            mealPeriod: .lunch, triggerHour: 13, triggerMinute: 0, usedPattern: false
        )
        XCTAssertTrue(pattern.notificationBody.contains("you usually eat"))
        XCTAssertFalse(fallback.notificationBody.contains("you usually eat"))
    }

    func testNotificationIdentifierIsStablePerMealPeriod() {
        let lunchSlot = MealTimingService.ReminderSlot(
            mealPeriod: .lunch, triggerHour: 12, triggerMinute: 0, usedPattern: true
        )
        XCTAssertEqual(lunchSlot.notificationIdentifier, "drift_meal_reminder_lunch")
    }

    // MARK: - Helpers

    private func lunchEntry(atHour hour: Double) -> FoodEntry {
        entry(meal: "lunch", hour: hour)
    }

    /// Build a FoodEntry whose `loggedAt` is today at `hour` (UTC ISO 8601 —
    /// the parser uses Calendar.current to extract local components, so for
    /// the local time-of-day to match `hour`, we set the date components in
    /// the local calendar.)
    private func entry(meal: String, hour: Double) -> FoodEntry {
        let totalMin = Int((hour * 60.0).rounded())
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = (totalMin / 60) % 24
        comps.minute = totalMin % 60
        let date = Calendar.current.date(from: comps)!
        let iso = DateFormatters.iso8601.string(from: date)
        return FoodEntry(
            foodName: "test",
            servingSizeG: 100,
            calories: 200,
            loggedAt: iso,
            mealType: meal
        )
    }
}
