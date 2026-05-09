import XCTest
@testable import DriftCore

final class BackupRingBufferTests: XCTestCase {

    // MARK: - Boundary cases

    func testEmptyInputReturnsEmpty() {
        let result = BackupRingBuffer.partition([], now: Date())
        XCTAssertTrue(result.keep.isEmpty)
        XCTAssertTrue(result.delete.isEmpty)
    }

    func testSingleBackupKeptNoneDeleted() {
        let only = makeBackup(daysAgo: 0)
        let result = BackupRingBuffer.partition([only], now: anchor)
        XCTAssertEqual(result.keep, [only])
        XCTAssertTrue(result.delete.isEmpty)
    }

    // MARK: - Same-day duplicates collapse to one daily slot

    func testThreeBackupsInOneDayKeepsNewestDeletesOthers() {
        let oldest = makeBackup(daysAgo: 0, hour: 1, suffix: "a")
        let middle = makeBackup(daysAgo: 0, hour: 12, suffix: "b")
        let newest = makeBackup(daysAgo: 0, hour: 23, suffix: "c")

        let result = BackupRingBuffer.partition([oldest, middle, newest], now: anchor)
        XCTAssertEqual(result.keep, [newest])
        XCTAssertEqual(Set(result.delete), [oldest, middle])
    }

    // MARK: - 12 distinct days → 7 daily + 4 weekly = 11 keep, 1 delete

    func testTwelveDistinctDaysAcrossFiveWeeksKeepsElevenDeletesOne() {
        // Days 0..6 fill all 7 daily slots. Days 8, 15, 22, 29, 36 are each
        // in a distinct ISO week → 5 weekly buckets, only 4 fit, oldest week
        // (days 36) is dropped. Expected: 11 keep, 1 delete.
        let dailyDays = (0..<7).map { makeBackup(daysAgo: $0) }
        let weeklyDays = [8, 15, 22, 29, 36].map { makeBackup(daysAgo: $0) }

        let result = BackupRingBuffer.partition(dailyDays + weeklyDays, now: anchor)

        XCTAssertEqual(result.keep.count, 11)
        XCTAssertEqual(result.delete.count, 1)
        XCTAssertEqual(result.delete.first, weeklyDays.last)  // days-ago-36 dropped
    }

    // MARK: - 30 distinct days → 11 keep, 19 delete

    func testThirtyDistinctDaysKeepsElevenDeletesNineteen() {
        let backups = (0..<30).map { makeBackup(daysAgo: $0) }
        let result = BackupRingBuffer.partition(backups, now: anchor)

        XCTAssertEqual(result.keep.count, 11)
        XCTAssertEqual(result.delete.count, 19)

        // The 7 most-recent days must always be kept.
        for i in 0..<7 {
            XCTAssertTrue(result.keep.contains(backups[i]))
        }
    }

    // MARK: - Fewer than 7 distinct days → all kept

    func testFiveDistinctDaysAllKept() {
        let backups = (0..<5).map { makeBackup(daysAgo: $0) }
        let result = BackupRingBuffer.partition(backups, now: anchor)
        XCTAssertEqual(Set(result.keep), Set(backups))
        XCTAssertTrue(result.delete.isEmpty)
    }

    // MARK: - Eight distinct days → 7 daily + 1 weekly

    func testEightDistinctDaysKeepsAllEight() {
        let backups = (0..<8).map { makeBackup(daysAgo: $0) }
        let result = BackupRingBuffer.partition(backups, now: anchor)
        XCTAssertEqual(result.keep.count, 8)
        XCTAssertTrue(result.delete.isEmpty)
    }

    // MARK: - Determinism

    func testPartitionIsDeterministicAcrossRuns() {
        let backups = (0..<30).map { makeBackup(daysAgo: $0) }
        let r1 = BackupRingBuffer.partition(backups, now: anchor)
        let r2 = BackupRingBuffer.partition(backups, now: anchor)
        XCTAssertEqual(r1.keep, r2.keep)
        XCTAssertEqual(r1.delete, r2.delete)
    }

    // MARK: - QA-driven lockdown tests

    /// Identical timestamps must tie-break deterministically so the same URL
    /// always wins the daily slot across runs.
    func testIdenticalTimestampsTieBreakDeterministically() {
        let ts = anchor
        let a = BackupInfo(
            url: URL(fileURLWithPath: "/tmp/drift-backup-a.driftbackup"),
            timestamp: ts, appVersion: "2.1.0", appBuild: "1042",
            backupFormatVersion: 1, schemaVersion: 14
        )
        let b = BackupInfo(
            url: URL(fileURLWithPath: "/tmp/drift-backup-b.driftbackup"),
            timestamp: ts, appVersion: "2.1.0", appBuild: "1042",
            backupFormatVersion: 1, schemaVersion: 14
        )
        let firstWinner: BackupInfo? = BackupRingBuffer.partition([a, b], now: anchor).keep.first
        for _ in 0..<25 {
            let result = BackupRingBuffer.partition([b, a], now: anchor)
            XCTAssertEqual(result.keep.count, 1)
            XCTAssertEqual(result.keep.first, firstWinner)
        }
    }

    /// Multiple backups within one weekly bucket: oldest is kept; adding a
    /// fresh backup mid-week must NOT shift the kept anchor (stability).
    func testMultipleBackupsInSameWeeklyBucketKeepsOldestAndIsStable() {
        let dailyDays = (0..<7).map { makeBackup(daysAgo: $0) }
        let day8 = makeBackup(daysAgo: 8)   // newest of weekly bucket
        let day9 = makeBackup(daysAgo: 9)
        let day10 = makeBackup(daysAgo: 10) // oldest of weekly bucket
        let week2 = makeBackup(daysAgo: 15)
        let week3 = makeBackup(daysAgo: 22)
        let week4 = makeBackup(daysAgo: 29)
        let weekDropped = makeBackup(daysAgo: 36)

        let backups = dailyDays + [day8, day9, day10, week2, week3, week4, weekDropped]
        let result = BackupRingBuffer.partition(backups, now: anchor)

        XCTAssertEqual(result.keep.count, 11)
        XCTAssertTrue(result.keep.contains(day10), "oldest in week (day 10) should be the weekly anchor")
        XCTAssertFalse(result.keep.contains(day8), "newer backups in same week should not be kept")
        XCTAssertFalse(result.keep.contains(day9))
        XCTAssertFalse(result.keep.contains(weekDropped), "5th-oldest week must drop")

        // Anchor stability: insert a new backup at day 8.5 (between 8 and 10).
        let dayBetween = makeBackup(daysAgo: 9, hour: 18, suffix: "between")
        let stable = BackupRingBuffer.partition(backups + [dayBetween], now: anchor).keep
        XCTAssertTrue(stable.contains(day10), "weekly anchor must not shift when a fresh backup lands mid-week")
    }

    /// A backup falling in ISO week-53 (year-boundary week) must group by
    /// `yearForWeekOfYear`, not `year`, so backups straddling Dec/Jan stay
    /// in the same weekly bucket.
    func testIsoWeekYearBoundaryGroupsByYearForWeekOfYear() {
        // 2025-12-30 (Tue), 2025-12-31 (Wed), 2026-01-01 (Thu) all live in
        // ISO 2026-W01 because the week containing the year's first Thursday
        // belongs to that year.
        let cal = utcIsoCalendar
        let dec30 = cal.date(from: DateComponents(year: 2025, month: 12, day: 30, hour: 3))!
        let dec31 = cal.date(from: DateComponents(year: 2025, month: 12, day: 31, hour: 3))!
        let jan01 = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 3))!
        let testAnchor = cal.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!

        // 7 daily fillers anchored mid-Jan, plus the 3 boundary backups in the
        // weekly window, plus a far-back backup to confirm 5+ weekly weeks.
        let dailyDays = (0..<7).map { offset in
            backup(at: cal.date(byAdding: .day, value: -offset, to: testAnchor)!)
        }
        let dec23 = cal.date(from: DateComponents(year: 2025, month: 12, day: 23, hour: 3))!
        let dec16 = cal.date(from: DateComponents(year: 2025, month: 12, day: 16, hour: 3))!

        let weekly = [dec30, dec31, jan01, dec23, dec16].map(backup(at:))
        let backups = dailyDays + weekly

        let result = BackupRingBuffer.partition(backups, now: testAnchor)

        // ISO 2026-W01 contains dec30, dec31, jan01 (a UTC year boundary
        // straddler). yearForWeekOfYear → all three group together; oldest
        // member dec30 wins the weekly slot. Plus 2025-W52 (dec23) and
        // 2025-W51 (dec16) → 3 weekly slots, 7 daily = 10 total kept.
        let keptUrls = Set(result.keep.map { $0.url })
        let url = { (d: Date) in URL(fileURLWithPath: "/tmp/b-\(d.timeIntervalSince1970).driftbackup") }
        XCTAssertTrue(keptUrls.contains(url(dec30)),
                      "dec30 (oldest in ISO 2026-W01) should be the weekly anchor")
        XCTAssertFalse(keptUrls.contains(url(dec31)),
                       "dec31 is in the same ISO week as dec30 — only oldest kept")
        XCTAssertFalse(keptUrls.contains(url(jan01)),
                       "jan01 groups by yearForWeekOfYear into the same bucket as dec30")
        XCTAssertTrue(keptUrls.contains(url(dec23)))
        XCTAssertTrue(keptUrls.contains(url(dec16)))
        XCTAssertEqual(result.keep.count, 10)
    }

    /// Pathological: 50 backups all on the same UTC day. Exactly one daily
    /// slot, no weekly slot, 49 deletions.
    func testManyBackupsOnSameDayKeepsOnlyNewest() {
        let cal = utcIsoCalendar
        let dayStart = cal.startOfDay(for: anchor)
        let backups = (0..<50).map { i in
            BackupInfo(
                url: URL(fileURLWithPath: "/tmp/drift-backup-same-day-\(i).driftbackup"),
                timestamp: dayStart.addingTimeInterval(TimeInterval(i * 600)), // every 10 min
                appVersion: "2.1.0", appBuild: "1042",
                backupFormatVersion: 1, schemaVersion: 14
            )
        }
        let result = BackupRingBuffer.partition(backups, now: anchor)
        XCTAssertEqual(result.keep.count, 1)
        XCTAssertEqual(result.delete.count, 49)
        let maxTs = backups.map { $0.timestamp }.max()
        XCTAssertEqual(result.keep.first?.timestamp, maxTs)
    }

    // MARK: - Helpers

    /// 2026-05-17 12:00 UTC — chosen so day 0 is a **Sunday**: the daily
    /// window then covers exactly one ISO week (W20: May 11 Mon – May 17 Sun),
    /// and `daysAgo` 8/9/10 land in the previous ISO week (W19) together,
    /// which the multi-backup-per-weekly-bucket test relies on.
    private var anchor: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 17
        components.hour = 12
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return utcIsoCalendar.date(from: components)!
    }

    private var utcIsoCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeBackup(
        daysAgo: Int,
        hour: Int = 3,
        suffix: String = ""
    ) -> BackupInfo {
        let dayStart = utcIsoCalendar
            .startOfDay(for: anchor.addingTimeInterval(TimeInterval(-daysAgo * 86_400)))
        let timestamp = dayStart.addingTimeInterval(TimeInterval(hour * 3600))
        let urlSuffix = suffix.isEmpty ? "" : "-\(suffix)"
        return BackupInfo(
            url: URL(fileURLWithPath: "/tmp/drift-backup-d\(daysAgo)\(urlSuffix).driftbackup"),
            timestamp: timestamp,
            appVersion: "2.1.0",
            appBuild: "1042",
            backupFormatVersion: 1,
            schemaVersion: 14
        )
    }

    private func backup(at timestamp: Date) -> BackupInfo {
        BackupInfo(
            url: URL(fileURLWithPath: "/tmp/b-\(timestamp.timeIntervalSince1970).driftbackup"),
            timestamp: timestamp,
            appVersion: "2.1.0",
            appBuild: "1042",
            backupFormatVersion: 1,
            schemaVersion: 14
        )
    }
}
