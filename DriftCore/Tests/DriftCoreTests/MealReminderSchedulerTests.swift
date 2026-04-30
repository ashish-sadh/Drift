import Foundation
@testable import DriftCore
import Testing

/// Tier-0 tests for `MealReminderScheduler` — pure-logic stats & filtering.
/// No notifications, no UNUserNotificationCenter, no app sandbox. The iOS
/// integration (cancel-on-log, daily trigger building) lives in
/// `DriftTests/NotificationServiceTests.swift`. #385.

/// Build a fixture entry for a given local-time hour & minute on a given
/// day-of-month in 2026-04. Important: the scheduler reads
/// `Calendar.current` to extract the local hour, so tests have to emit ISO
/// strings that map to the *intended* local hour. Composing via `Calendar`
/// guarantees the assertion is timezone-stable.
private func entry(month: Int = 4, day: Int, hour: Int, minute: Int = 0, mealType: String) -> FoodEntry {
    var comps = DateComponents()
    comps.year = 2026; comps.month = month; comps.day = day
    comps.hour = hour; comps.minute = minute
    let date = Calendar.current.date(from: comps) ?? Date()
    let iso = DateFormatters.iso8601.string(from: date)
    return FoodEntry(
        foodName: "test",
        servingSizeG: 100,
        calories: 100,
        loggedAt: iso,
        mealType: mealType
    )
}

// MARK: - Empty / Edge Cases

@Test func emptyEntriesYieldsNoSlots() {
    let slots = MealReminderScheduler.computeSlots(from: [])
    #expect(slots.isEmpty)
}

@Test func snacksAreIgnored() {
    // 5 snacks at consistent 3pm — should NOT produce a snack reminder.
    // Snack timing is scattered by definition; reminders would misfire.
    let entries = (1...5).map { day in
        entry(day: day, hour: 15, mealType: "snack")
    }
    let slots = MealReminderScheduler.computeSlots(from: entries)
    #expect(slots.isEmpty)
}

@Test func unknownMealTypeIsSkipped() {
    // Garbage mealType strings shouldn't crash or produce phantom slots.
    let entries = (1...5).map { day in
        entry(day: day, hour: 8, mealType: "secondbreakfast")
    }
    let slots = MealReminderScheduler.computeSlots(from: entries)
    #expect(slots.isEmpty)
}

// MARK: - Sample Threshold

@Test func belowMinSamplesYieldsNoSlot() {
    // Only 2 lunch entries — below the 3-sample threshold.
    let entries = [
        entry(day: 1, hour: 13, mealType: "lunch"),
        entry(day: 2, hour: 13, mealType: "lunch"),
    ]
    let slots = MealReminderScheduler.computeSlots(from: entries)
    #expect(slots.isEmpty)
}

// MARK: - Std Dev Filter

@Test func highVarianceYieldsNoSlot() {
    // Lunch at wildly different times — std dev far above 45-min threshold.
    let entries = [
        entry(day: 1, hour: 11, mealType: "lunch"),
        entry(day: 2, hour: 15, minute: 30, mealType: "lunch"),
        entry(day: 3, hour: 13, mealType: "lunch"),
        entry(day: 4, hour: 12, mealType: "lunch"),
        entry(day: 5, hour: 16, mealType: "lunch"),
    ]
    let slots = MealReminderScheduler.computeSlots(from: entries)
    #expect(slots.isEmpty, "high-variance lunch should not produce a reminder")
}

@Test func consistentTimingYieldsSlot() {
    // Lunch at 1:00pm ± a few minutes — well under 45-min threshold.
    let entries = [
        entry(day: 1, hour: 13, minute: 0, mealType: "lunch"),
        entry(day: 2, hour: 13, minute: 5, mealType: "lunch"),
        entry(day: 3, hour: 12, minute: 55, mealType: "lunch"),
        entry(day: 4, hour: 13, minute: 10, mealType: "lunch"),
        entry(day: 5, hour: 12, minute: 50, mealType: "lunch"),
    ]
    let slots = MealReminderScheduler.computeSlots(from: entries)
    #expect(slots.count == 1)
    let slot = try? #require(slots.first)
    #expect(slot?.mealPeriod == .lunch)
    // 1pm + 30min nudge offset = 1:30pm
    #expect(slot?.triggerHour == 13)
    #expect(slot?.triggerMinute == 30)
}

// MARK: - Multi-Period Output

@Test func multiplePeriodsProduceMultipleSlots() {
    // Consistent breakfast at 8am AND consistent dinner at 7pm.
    var entries: [FoodEntry] = []
    for day in 1...5 {
        entries.append(entry(day: day, hour: 8, mealType: "breakfast"))
        entries.append(entry(day: day, hour: 19, mealType: "dinner"))
    }
    let slots = MealReminderScheduler.computeSlots(from: entries)
    #expect(slots.count == 2)
    // Sorted by trigger time — breakfast first
    #expect(slots[0].mealPeriod == .breakfast)
    #expect(slots[0].triggerHour == 8)
    #expect(slots[0].triggerMinute == 30)
    #expect(slots[1].mealPeriod == .dinner)
    #expect(slots[1].triggerHour == 19)
    #expect(slots[1].triggerMinute == 30)
}

// MARK: - slotsToFire (today-already-logged filter)

@Test func slotsToFireDropsAlreadyLoggedPeriods() {
    let breakfast = MealReminderScheduler.ReminderSlot(
        mealPeriod: .breakfast, triggerHour: 8, triggerMinute: 30,
        avgHour: 8.0, stdDevMinutes: 10
    )
    let lunch = MealReminderScheduler.ReminderSlot(
        mealPeriod: .lunch, triggerHour: 13, triggerMinute: 30,
        avgHour: 13.0, stdDevMinutes: 10
    )
    let candidates = [breakfast, lunch]

    // User already logged breakfast today → only lunch slot remains.
    let toFire = MealReminderScheduler.slotsToFire(
        candidates: candidates,
        loggedPeriodsToday: [.breakfast]
    )
    #expect(toFire.count == 1)
    #expect(toFire.first?.mealPeriod == .lunch)
}

@Test func slotsToFirePassesAllWhenNothingLogged() {
    let breakfast = MealReminderScheduler.ReminderSlot(
        mealPeriod: .breakfast, triggerHour: 8, triggerMinute: 30,
        avgHour: 8.0, stdDevMinutes: 10
    )
    let toFire = MealReminderScheduler.slotsToFire(
        candidates: [breakfast],
        loggedPeriodsToday: []
    )
    #expect(toFire.count == 1)
}

// MARK: - Notification Body

@Test func notificationBodyIncludesTypicalTime() {
    let slot = MealReminderScheduler.ReminderSlot(
        mealPeriod: .lunch, triggerHour: 13, triggerMinute: 30,
        avgHour: 13.0, stdDevMinutes: 10
    )
    let body = slot.notificationBody
    #expect(body.contains("lunch"))
    #expect(body.contains("1:00 PM"), "body should include typical time, got: \(body)")
}

@Test func notificationIdentifierIsPeriodScoped() {
    // Identifiers must be per-period so `removeAllPendingNotificationRequests`
    // and reschedule can swap them cleanly without clobbering the daily
    // health-nudge request.
    let breakfastSlot = MealReminderScheduler.ReminderSlot(
        mealPeriod: .breakfast, triggerHour: 8, triggerMinute: 30,
        avgHour: 8.0, stdDevMinutes: 10
    )
    let dinnerSlot = MealReminderScheduler.ReminderSlot(
        mealPeriod: .dinner, triggerHour: 19, triggerMinute: 30,
        avgHour: 19.0, stdDevMinutes: 10
    )
    #expect(breakfastSlot.notificationIdentifier == "drift_meal_reminder_breakfast")
    #expect(dinnerSlot.notificationIdentifier == "drift_meal_reminder_dinner")
    #expect(breakfastSlot.notificationIdentifier != dinnerSlot.notificationIdentifier)
}

// MARK: - Preferences

@Test func mealRemindersEnabledRoundTripsAndDefaultsOff() {
    let original = Preferences.mealRemindersEnabled
    defer { Preferences.mealRemindersEnabled = original }

    UserDefaults.standard.removeObject(forKey: "drift_meal_reminders")
    // Default OFF — opt-in like Photo Log Beta.
    #expect(Preferences.mealRemindersEnabled == false)

    Preferences.mealRemindersEnabled = true
    #expect(Preferences.mealRemindersEnabled == true)
    Preferences.mealRemindersEnabled = false
    #expect(Preferences.mealRemindersEnabled == false)
}
