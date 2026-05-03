import UserNotifications
import DriftCore

/// Schedules local push notifications for health nudges (protein, supplements, workouts),
/// smart meal reminders, and medication dose reminders. All logic is on-device — no cloud,
/// no tracking. Reuses BehaviorInsightService detection + MealReminderScheduler. #385 #592.
@MainActor
enum NotificationService {

    private static let categoryID = "drift_health_nudge"
    private static let mealReminderCategoryID = "drift_meal_reminder"
    private static let medicationReminderCategoryID = "drift_medication_reminder"
    private static let dailyNudgeIdentifier = "drift_daily_nudge"

    /// Lookback window for "what time does the user typically eat?" stats.
    private static let mealLookbackDays = 14
    /// Lookback window for medication dose-time stats. 60 days covers weekly GLP-1 injections.
    private static let medicationLookbackDays = 60
    /// Nudge fires this many minutes after the typical dose time.
    private static let medicationNudgeOffsetMinutes = 120

    /// Call on app launch and after relevant data changes (food log, medication log, settings).
    /// Checks conditions, requests permission if needed, schedules/cancels notifications.
    /// Feature toggles (`healthNudgesEnabled`, `mealRemindersEnabled`, `medicationRemindersEnabled`)
    /// are honored independently.
    static func refreshScheduledAlerts() async {
        let center = UNUserNotificationCenter.current()

        let nudgesOn = Preferences.healthNudgesEnabled
        let mealsOn = Preferences.mealRemindersEnabled
        let medsOn = Preferences.medicationRemindersEnabled

        guard nudgesOn || mealsOn || medsOn else {
            center.removeAllPendingNotificationRequests()
            return
        }

        // Remove all pending — we reschedule fresh
        center.removeAllPendingNotificationRequests()

        let alerts = nudgesOn ? BehaviorInsightService.computeProactiveAlerts() : []
        let mealSlots = mealsOn ? computeMealReminderSlots() : []
        let medSlots = medsOn ? computeMedicationReminderSlots() : []

        // No work? Don't pester for permission.
        guard !alerts.isEmpty || !mealSlots.isEmpty || !medSlots.isEmpty else { return }

        // Request permission if not yet determined (only when we have something to send)
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            guard let granted = try? await center.requestAuthorization(options: [.alert, .sound]),
                  granted else { return }
        case .denied:
            return // User said no — respect it
        case .authorized, .provisional, .ephemeral:
            break // Good to go
        @unknown default:
            break
        }

        // Health-nudge daily summary at 6pm
        if !alerts.isEmpty {
            let (title, body) = composeNotification(from: alerts)
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = categoryID

            let trigger = nextEveningTrigger()
            let request = UNNotificationRequest(
                identifier: dailyNudgeIdentifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }

        // Per-meal-period reminders — fired daily at avg + 30min
        for slot in mealSlots {
            let content = UNMutableNotificationContent()
            content.title = "Did you log \(slot.mealPeriod.displayName.lowercased())?"
            content.body = slot.notificationBody
            content.sound = .default
            content.categoryIdentifier = mealReminderCategoryID

            let request = UNNotificationRequest(
                identifier: slot.notificationIdentifier,
                content: content,
                trigger: dailyTrigger(hour: slot.triggerHour, minute: slot.triggerMinute)
            )
            try? await center.add(request)
        }

        // Per-medication reminders — fired daily at typical dose time + 2h
        for slot in medSlots {
            let content = UNMutableNotificationContent()
            content.title = "Time to log \(slot.medicationName)?"
            content.body = slot.notificationBody
            content.sound = .default
            content.categoryIdentifier = medicationReminderCategoryID

            let request = UNNotificationRequest(
                identifier: slot.notificationIdentifier,
                content: content,
                trigger: dailyTrigger(hour: slot.triggerHour, minute: slot.triggerMinute)
            )
            try? await center.add(request)
        }
    }

    // MARK: - Meal Reminder Pipeline (testable seam)

    /// Pull the last 14 days of food entries, compute the user's typical
    /// meal times, then drop any periods already logged today (no point
    /// nudging at 1pm if lunch is already in the log). Returns the slots
    /// that should fire as repeating daily reminders.
    static func computeMealReminderSlots(now: Date = Date()) -> [MealReminderScheduler.ReminderSlot] {
        let entries = recentFoodEntries(now: now, days: mealLookbackDays)
        let candidates = MealReminderScheduler.computeSlots(from: entries)

        let loggedToday = loggedMealPeriods(now: now)
        return MealReminderScheduler.slotsToFire(
            candidates: candidates,
            loggedPeriodsToday: loggedToday
        )
    }

    // MARK: - Medication Reminder Pipeline (testable seam)

    /// For each medication logged 3+ times in the last 60 days, compute the
    /// typical dose time and return a reminder slot — unless the medication
    /// has already been logged today. Returns slots for repeating daily reminders.
    static func computeMedicationReminderSlots(now: Date = Date()) -> [MedicationReminderSlot] {
        let todayStr = DateFormatters.dateOnly.string(from: now)
        let todayLogged = Set(
            (try? AppDatabase.shared.fetchTodayMedications(datePrefix: todayStr))?.map { $0.name.lowercased() } ?? []
        )

        let names = MedicationService.consistentMedicationNames(days: medicationLookbackDays)
        var slots: [MedicationReminderSlot] = []

        for name in names {
            guard !todayLogged.contains(name.lowercased()) else { continue }
            let hours = MedicationService.recentDoseHours(for: name, days: medicationLookbackDays)
            guard hours.count >= 3 else { continue }
            let mean = hours.reduce(0, +) / Double(hours.count)
            let totalMinutes = Int((mean * 60.0).rounded()) + medicationNudgeOffsetMinutes
            slots.append(MedicationReminderSlot(
                medicationName: name,
                triggerHour: (totalMinutes / 60) % 24,
                triggerMinute: totalMinutes % 60,
                avgHour: mean
            ))
        }
        return slots.sorted { $0.triggerHour * 60 + $0.triggerMinute < $1.triggerHour * 60 + $1.triggerMinute }
    }

    // MARK: - Shared Helpers

    /// Repeating daily calendar trigger at the given local time. `repeats:
    /// true` is critical for reminders — we want a single registration
    /// to keep firing daily without re-scheduling on each app launch.
    static func dailyTrigger(hour: Int, minute: Int) -> UNCalendarNotificationTrigger {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    }

    /// Fetch food entries across the last `days` days. Hits AppDatabase per
    /// day (matches `FoodTimingInsightTool.run`) — no batched range API
    /// exists. With days=14 this is 14 lightweight queries.
    private static func recentFoodEntries(now: Date, days: Int) -> [FoodEntry] {
        let cal = Calendar.current
        let fmt = DateFormatters.dateOnly
        var entries: [FoodEntry] = []
        for delta in 0..<days {
            guard let day = cal.date(byAdding: .day, value: -delta, to: now) else { continue }
            let dateStr = fmt.string(from: day)
            entries.append(contentsOf: (try? AppDatabase.shared.fetchFoodEntries(for: dateStr)) ?? [])
        }
        return entries
    }

    /// Which meal periods has the user already logged today? Drives the
    /// "skip the reminder if it's redundant" filter. Snacks are excluded
    /// (they're not a meal period that gets reminded).
    private static func loggedMealPeriods(now: Date) -> Set<MealType> {
        let dateStr = DateFormatters.dateOnly.string(from: now)
        let todays = (try? AppDatabase.shared.fetchFoodEntries(for: dateStr)) ?? []
        var periods: Set<MealType> = []
        for entry in todays {
            guard let raw = entry.mealType,
                  let period = MealType(rawValue: raw.lowercased()),
                  period != .snack else { continue }
            periods.insert(period)
        }
        return periods
    }

    // MARK: - Composition (internal for testability)

    /// Compose a single notification from multiple alerts.
    static func composeNotification(from alerts: [BehaviorInsight]) -> (title: String, body: String) {
        if alerts.count == 1 {
            return (alerts[0].title, alerts[0].detail)
        }
        let title = "Health check-in"
        let body = alerts.map(\.title).joined(separator: " · ")
        return (title, body)
    }

    /// Returns a calendar trigger for 6pm today if before 6pm, otherwise 6pm tomorrow.
    static func nextEveningTrigger() -> UNCalendarNotificationTrigger {
        var components = DateComponents()
        components.hour = 18
        components.minute = 0
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}

// MARK: - MedicationReminderSlot

/// Mirrors MealReminderScheduler.ReminderSlot for medication dose reminders.
/// Lives in the iOS layer (NotificationService.swift) since it's notification-specific
/// and doesn't need to be tested independently of the notification pipeline.
struct MedicationReminderSlot: Sendable, Equatable {
    let medicationName: String
    let triggerHour: Int
    let triggerMinute: Int
    let avgHour: Double

    var notificationBody: String {
        let hr = Int(avgHour)
        let min = Int((avgHour - Double(hr)) * 60)
        let suffix = hr >= 12 ? "PM" : "AM"
        let displayHr = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr)
        let timeStr = min == 0
            ? String(format: "%d %@", displayHr, suffix)
            : String(format: "%d:%02d %@", displayHr, min, suffix)
        return "You usually take \(medicationName) around \(timeStr). Tap to log your dose."
    }

    var notificationIdentifier: String {
        let safeName = medicationName.lowercased().replacingOccurrences(of: " ", with: "_")
        return "drift_medication_reminder_\(safeName)"
    }
}
