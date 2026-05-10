import Foundation

/// Pure ring-buffer pruning for `.driftbackup` files. Keeps **7 daily + 4
/// weekly = up to 11** snapshots; everything else is returned in `delete` for
/// the caller (e.g. `BackupService`) to remove from disk.
///
/// Policy:
/// * **Daily slots** — the most recent backup per UTC calendar day, up to 7
///   distinct days. The window is data-driven: if the user only has 5 days of
///   backups, all 5 fill daily slots and there is no weekly carry-over.
/// * **Weekly slots** — backups whose UTC day is *not* one of the daily slot
///   days. Group those by ISO 8601 week (UTC), and for the 4 most-recent
///   weeks keep the **oldest** backup in each. Choosing the oldest gives a
///   stable historical anchor: it doesn't shift as new backups land in the
///   same week.
///
/// `now` is reserved for future window-anchoring policies; the current
/// implementation is purely data-driven.
public enum BackupRingBuffer {
    public static func partition(
        _ all: [BackupInfo],
        now _: Date
    ) -> (keep: [BackupInfo], delete: [BackupInfo]) {
        guard !all.isEmpty else { return ([], []) }

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .gmt

        // Tie-break on URL so identical timestamps yield a deterministic order
        // — Swift's `Array.sorted` is not strictly stable on equal keys, and
        // two retries written within the same millisecond would otherwise let
        // `keep` flip across runs.
        let sortedDesc = all.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp { return lhs.timestamp > rhs.timestamp }
            return lhs.url.absoluteString < rhs.url.absoluteString
        }

        let (dailyKeep, dailyDays) = pickDailySlots(from: sortedDesc, calendar: calendar)
        let weeklyKeep = pickWeeklySlots(
            from: sortedDesc,
            excludingDays: dailyDays,
            calendar: calendar
        )

        let keepSet = dailyKeep.union(weeklyKeep)
        let keep = sortedDesc.filter { keepSet.contains($0.url) }
        let delete = sortedDesc.filter { !keepSet.contains($0.url) }
        return (keep, delete)
    }

    private static func pickDailySlots(
        from sortedDesc: [BackupInfo],
        calendar: Calendar
    ) -> (keep: Set<URL>, days: Set<Date>) {
        var keep: Set<URL> = []
        var days: Set<Date> = []
        for backup in sortedDesc {
            let day = calendar.startOfDay(for: backup.timestamp)
            if days.contains(day) { continue }
            if days.count >= 7 { break }
            days.insert(day)
            keep.insert(backup.url)
        }
        return (keep, days)
    }

    private static func pickWeeklySlots(
        from sortedDesc: [BackupInfo],
        excludingDays dailyDays: Set<Date>,
        calendar: Calendar
    ) -> Set<URL> {
        let eligible = sortedDesc.filter {
            !dailyDays.contains(calendar.startOfDay(for: $0.timestamp))
        }
        guard !eligible.isEmpty else { return [] }

        struct WeekKey: Hashable { let year: Int; let week: Int }
        var byWeek: [WeekKey: [BackupInfo]] = [:]
        for backup in eligible {
            let comps = calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: backup.timestamp
            )
            let key = WeekKey(
                year: comps.yearForWeekOfYear ?? 0,
                week: comps.weekOfYear ?? 0
            )
            byWeek[key, default: []].append(backup)
        }

        // `byWeek[k]` lists are already newest-first because `sortedDesc` was;
        // sorting weeks by their newest member yields a deterministic
        // newest-week-first order.
        let weeksNewestFirst = byWeek.keys.sorted { lhs, rhs in
            let l = byWeek[lhs]?.first?.timestamp ?? .distantPast
            let r = byWeek[rhs]?.first?.timestamp ?? .distantPast
            return l > r
        }

        var keep: Set<URL> = []
        for weekKey in weeksNewestFirst.prefix(4) {
            if let oldest = byWeek[weekKey]?.last {
                keep.insert(oldest.url)
            }
        }
        return keep
    }
}
