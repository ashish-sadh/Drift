import Foundation

/// Median-based meal-timing learner for smart reminders. Replaces the
/// mean+stddev MealReminderScheduler with a more robust statistic and
/// an explicit data-threshold gate.
///
/// Behavior (#690):
///   - 10+ entries for a meal in the lookback window → reminder fires
///     median local-time-of-day + 30 min ("you usually eat lunch at
///     12:50, so we nudge at 1:20 if you haven't logged").
///   - Below threshold OR `usePatterns == false` → reminder fires at the
///     fixed default for that meal (8:30 / 13:00 / 19:30, all already
///     including the +30 min offset).
///   - Snacks are excluded — snack timing is naturally scattered.
///   - Slots for periods already logged today are filtered out by passing
///     them in via `loggedToday`. Skipping at refresh time avoids the
///     UNUserNotificationCenterDelegate path entirely.
public enum MealTimingService {

    /// One scheduled reminder slot. `triggerHour` / `triggerMinute` are
    /// local time components — the iOS layer wraps them in a
    /// `UNCalendarNotificationTrigger`. `medianHour` is the user's
    /// pre-offset median (or nil for fixed-default slots) — kept
    /// separately so the notification body can say "you usually eat
    /// around 12:30" while the trigger fires at 13:00.
    public struct ReminderSlot: Sendable, Equatable {
        public let mealPeriod: MealType
        public let triggerHour: Int     // 0..23
        public let triggerMinute: Int   // 0..59
        public let medianHour: Double?

        public var usedPattern: Bool { medianHour != nil }

        public init(mealPeriod: MealType, triggerHour: Int, triggerMinute: Int, medianHour: Double?) {
            self.mealPeriod = mealPeriod
            self.triggerHour = triggerHour
            self.triggerMinute = triggerMinute
            self.medianHour = medianHour
        }

        public var notificationBody: String {
            let meal = mealPeriod.displayName.lowercased()
            if let medianHour {
                return "Time to log \(meal) — you usually eat around \(formatHour(medianHour))."
            }
            return "Did you log \(meal) yet?"
        }

        public var notificationIdentifier: String {
            "drift_meal_reminder_\(mealPeriod.rawValue)"
        }
    }

    // MARK: - Tuning

    public static let nudgeOffsetMinutes: Int = 30

    /// Minimum entries for a meal period before we trust the median over
    /// the fixed default. Raised from #385's 3 to 10 — at 10 samples the
    /// median is stable against weekend outliers.
    public static let minSamplesPerPeriod: Int = 10

    /// Fixed-default trigger times when no pattern is available. Times
    /// already include the +30 min offset (so 12:30 typical lunch → 13:00
    /// default). Snacks intentionally absent.
    public static let fixedDefaultsByPeriod: [MealType: (hour: Int, minute: Int)] = [
        .breakfast: (8, 30),
        .lunch: (13, 0),
        .dinner: (19, 30),
    ]

    // MARK: - Median / IQR

    /// Median local-time-of-day for the given meal type from the entries
    /// (typically the last 30 days). Returns `nil` when fewer than
    /// `minEntries` entries match. The returned `Date` is today's date
    /// with the median's hour:minute components — the date part is
    /// purely a transport for the time-of-day.
    public static func medianTime(
        for meal: MealType,
        entries: [FoodEntry],
        minEntries: Int = minSamplesPerPeriod
    ) -> Date? {
        guard let h = medianHour(for: meal, entries: entries, minEntries: minEntries) else { return nil }
        let totalMin = Int((h * 60.0).rounded())
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = (totalMin / 60) % 24
        components.minute = totalMin % 60
        return Calendar.current.date(from: components)
    }

    /// IQR (75th – 25th percentile) of the meal's logged hours, for
    /// telemetry and debugging. Returns nil when below threshold.
    public static func interquartileRangeHours(
        for meal: MealType,
        entries: [FoodEntry],
        minEntries: Int = minSamplesPerPeriod
    ) -> Double? {
        let hours = hoursForMeal(meal, entries: entries)
        guard hours.count >= minEntries else { return nil }
        let sorted = hours.sorted()
        return percentile(sorted, p: 0.75) - percentile(sorted, p: 0.25)
    }

    // MARK: - Slot composition

    /// Compute reminder slots for breakfast / lunch / dinner. When
    /// `usePatterns` is true and the meal has 10+ entries, the slot uses
    /// median + offset; otherwise it uses the fixed default. Periods
    /// present in `loggedToday` are excluded entirely (no point nudging
    /// for an already-logged meal).
    public static func reminderSlots(
        entries: [FoodEntry],
        usePatterns: Bool,
        offsetMinutes: Int = nudgeOffsetMinutes,
        loggedToday: Set<MealType> = []
    ) -> [ReminderSlot] {
        let periods: [MealType] = [.breakfast, .lunch, .dinner]
        var slots: [ReminderSlot] = []
        for period in periods where !loggedToday.contains(period) {
            if usePatterns,
               let medianHour = medianHour(for: period, entries: entries) {
                let totalMin = Int((medianHour * 60.0).rounded()) + offsetMinutes
                slots.append(ReminderSlot(
                    mealPeriod: period,
                    triggerHour: (totalMin / 60) % 24,
                    triggerMinute: totalMin % 60,
                    medianHour: medianHour
                ))
            } else if let fixed = fixedDefaultsByPeriod[period] {
                slots.append(ReminderSlot(
                    mealPeriod: period,
                    triggerHour: fixed.hour,
                    triggerMinute: fixed.minute,
                    medianHour: nil
                ))
            }
        }
        return slots.sorted { $0.triggerHour * 60 + $0.triggerMinute < $1.triggerHour * 60 + $1.triggerMinute }
    }

    // MARK: - Local-hour parsing (shared with FoodTimingInsightTool's logic)

    public static func parseLocalHour(_ loggedAt: String) -> Double? {
        guard let date = DateFormatters.iso8601.date(from: loggedAt) else { return nil }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = comps.hour, let minute = comps.minute else { return nil }
        return Double(hour) + Double(minute) / 60.0
    }

    // MARK: - Internals

    private static func medianHour(
        for meal: MealType,
        entries: [FoodEntry],
        minEntries: Int = minSamplesPerPeriod
    ) -> Double? {
        guard meal != .snack else { return nil }
        let hours = hoursForMeal(meal, entries: entries)
        guard hours.count >= minEntries else { return nil }
        return median(hours)
    }

    private static func hoursForMeal(_ meal: MealType, entries: [FoodEntry]) -> [Double] {
        var hours: [Double] = []
        for entry in entries {
            guard let raw = entry.mealType,
                  let period = MealType(rawValue: raw.lowercased()),
                  period == meal,
                  let h = parseLocalHour(entry.loggedAt) else { continue }
            hours.append(h)
        }
        return hours
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let n = sorted.count
        if n.isMultiple(of: 2) {
            return (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
        }
        return sorted[n / 2]
    }

    /// Linear-interpolated percentile (R-7 / Excel's `PERCENTILE`).
    /// `sortedValues` must be sorted ascending.
    private static func percentile(_ sortedValues: [Double], p: Double) -> Double {
        let idx = Double(sortedValues.count - 1) * p
        let lo = Int(floor(idx))
        let hi = Int(ceil(idx))
        if lo == hi { return sortedValues[lo] }
        let weight = idx - Double(lo)
        return sortedValues[lo] + weight * (sortedValues[hi] - sortedValues[lo])
    }
}

private func formatHour(_ h: Double) -> String {
    let totalMinutes = Int((h * 60).rounded())
    let hr = (totalMinutes / 60) % 24
    let min = totalMinutes % 60
    let suffix = hr >= 12 ? "PM" : "AM"
    let displayHr = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr)
    return String(format: "%d:%02d %@", displayHr, min, suffix)
}
