import Foundation

/// Pure logic for the smart-meal-reminder feature: examines the user's recent
/// food log, decides which meal periods (breakfast/lunch/dinner) have a
/// consistent-enough timing to nudge about, and returns the trigger times.
///
/// "Consistent enough" = std dev under 45 min over the lookback window. We
/// don't want a reminder at 1:30pm if some days the user eats lunch at 11am
/// and others at 3pm — that's just an annoyance, not a useful nudge.
///
/// Lives in DriftCore so the iOS notification layer can consume it from
/// `NotificationService`, but the math itself stays unit-testable without
/// `UNUserNotificationCenter`. #385.
public enum MealReminderScheduler {

    /// One scheduled reminder slot. `triggerHour` / `triggerMinute` are local
    /// time components — the iOS layer wraps them in a
    /// `UNCalendarNotificationTrigger` for daily firing.
    public struct ReminderSlot: Sendable, Equatable {
        public let mealPeriod: MealType
        public let triggerHour: Int     // 0..23 local time
        public let triggerMinute: Int   // 0..59
        public let avgHour: Double      // raw average for telemetry / copy
        public let stdDevMinutes: Double

        public init(mealPeriod: MealType, triggerHour: Int, triggerMinute: Int, avgHour: Double, stdDevMinutes: Double) {
            self.mealPeriod = mealPeriod
            self.triggerHour = triggerHour
            self.triggerMinute = triggerMinute
            self.avgHour = avgHour
            self.stdDevMinutes = stdDevMinutes
        }

        /// Notification body — pairs a friendly reminder with the typical
        /// time so the user understands *why* this fired now and not
        /// arbitrarily ("you usually eat around 1pm" beats "log lunch").
        public var notificationBody: String {
            let timeStr = formatHour(avgHour)
            return "Time to log \(mealPeriod.displayName.lowercased()) — you usually eat around \(timeStr)."
        }

        /// Used by the iOS layer to set a stable, period-scoped notification
        /// identifier so refresh runs cancel + reschedule cleanly without
        /// touching the unrelated `drift_daily_nudge` request.
        public var notificationIdentifier: String {
            "drift_meal_reminder_\(mealPeriod.rawValue)"
        }
    }

    // MARK: - Tuning

    /// Reminder fires this many minutes after the typical meal time. Gives
    /// the user a window to log naturally before we nudge.
    public static let nudgeOffsetMinutes: Int = 30

    /// Skip meals where timing is too variable to draw a useful pattern.
    /// 45 minutes ≈ "I sometimes eat at 1pm, sometimes 1:45pm" — still a
    /// pattern. 60+ minutes is closer to "I eat lunch whenever" — noise.
    public static let maxStdDevMinutes: Double = 45.0

    /// Need at least this many sample meals in the period to consider it a
    /// pattern. With <3 samples one outlier dominates the average.
    public static let minSamplesPerPeriod: Int = 3

    // MARK: - Entry Point

    /// Compute reminder slots from a list of food entries (typically the
    /// last 14 days). Returns one slot per meal period whose timing is
    /// consistent enough to nudge about. Snacks are excluded by design —
    /// snack timing is naturally scattered.
    public static func computeSlots(
        from entries: [FoodEntry],
        nudgeOffsetMinutes offsetMin: Int = nudgeOffsetMinutes,
        maxStdDevMinutes: Double = maxStdDevMinutes,
        minSamplesPerPeriod: Int = minSamplesPerPeriod
    ) -> [ReminderSlot] {
        var hoursByPeriod: [MealType: [Double]] = [:]
        for entry in entries {
            guard let hour = parseLocalHour(entry.loggedAt) else { continue }
            guard let period = MealType(rawValue: (entry.mealType ?? "").lowercased()) else { continue }
            // Skip snacks — they're scattered by definition; reminders would
            // misfire all day.
            guard period != .snack else { continue }
            hoursByPeriod[period, default: []].append(hour)
        }

        var slots: [ReminderSlot] = []
        for (period, hours) in hoursByPeriod {
            guard hours.count >= minSamplesPerPeriod else { continue }
            let mean = hours.reduce(0, +) / Double(hours.count)
            let std = standardDeviation(hours, mean: mean)
            let stdMin = std * 60.0
            guard stdMin <= maxStdDevMinutes else { continue }

            let totalMinutes = Int((mean * 60.0).rounded()) + offsetMin
            let triggerHour = (totalMinutes / 60) % 24
            let triggerMin = totalMinutes % 60
            slots.append(ReminderSlot(
                mealPeriod: period,
                triggerHour: triggerHour,
                triggerMinute: triggerMin,
                avgHour: mean,
                stdDevMinutes: stdMin
            ))
        }
        // Stable order so test assertions and notification layouts don't flap.
        return slots.sorted { $0.triggerHour * 60 + $0.triggerMinute < $1.triggerHour * 60 + $1.triggerMinute }
    }

    /// Filter out periods the user has already logged today — the nudge for
    /// breakfast at 9am isn't useful if breakfast is already in the log.
    /// `loggedPeriodsToday` is typically derived from
    /// `AppDatabase.fetchFoodEntries(for: today)`.
    public static func slotsToFire(
        candidates: [ReminderSlot],
        loggedPeriodsToday: Set<MealType>
    ) -> [ReminderSlot] {
        candidates.filter { !loggedPeriodsToday.contains($0.mealPeriod) }
    }

    // MARK: - Stats

    /// Population standard deviation. With only 3-N samples per meal period
    /// a sample-vs-population correction is in the noise; population is
    /// simpler to reason about. Returns 0 for an empty array.
    private static func standardDeviation(_ values: [Double], mean: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let squaredDiffs = values.map { ($0 - mean) * ($0 - mean) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count)
        return variance.squareRoot()
    }

    /// Parse the local-time hour from an ISO 8601 timestamp stored in the
    /// DB. Mirrors `FoodTimingInsightTool.parseLocalHour` — kept colocated
    /// so the test suite covers it without crossing module boundaries.
    public static func parseLocalHour(_ loggedAt: String) -> Double? {
        guard let date = DateFormatters.iso8601.date(from: loggedAt) else { return nil }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = comps.hour, let minute = comps.minute else { return nil }
        return Double(hour) + Double(minute) / 60.0
    }
}

// MARK: - Hour formatting

/// Format a fractional hour (e.g. 13.25) as "1:15 PM". Free-floating helper
/// since `ReminderSlot.notificationBody` needs it but it's also useful from
/// tests independently.
private func formatHour(_ h: Double) -> String {
    let totalMinutes = Int((h * 60).rounded())
    let hr = (totalMinutes / 60) % 24
    let min = totalMinutes % 60
    let suffix = hr >= 12 ? "PM" : "AM"
    let displayHr = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr)
    return String(format: "%d:%02d %@", displayHr, min, suffix)
}
