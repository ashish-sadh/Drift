import XCTest
@testable import DriftCore
@testable import Drift

final class BackupMonitorTests: XCTestCase {

    private var defaultsSuite: UserDefaults!
    private var center: NotificationCenter!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "BackupMonitorTests-\(UUID().uuidString)"
        defaultsSuite = UserDefaults(suiteName: suiteName)
        defaultsSuite.removePersistentDomain(forName: suiteName)
        center = NotificationCenter()
    }

    override func tearDown() {
        defaultsSuite.removePersistentDomain(forName: suiteName)
        defaultsSuite = nil
        center = nil
        super.tearDown()
    }

    func testPostsWhenLastBackupOlderThanThreshold() {
        let now = Date(timeIntervalSince1970: 1_762_000_000)
        let fourDaysAgo = now.addingTimeInterval(-4 * 86_400)
        defaultsSuite.set(fourDaysAgo, forKey: BackupService.lastSuccessfulBackupDateKey)

        let monitor = BackupMonitor(userDefaults: defaultsSuite, notificationCenter: center)
        let observed = expectation(description: "stale banner posted")
        var observedDays: Int?
        let token = center.addObserver(
            forName: .backupStaleBanner,
            object: nil,
            queue: nil
        ) { note in
            observedDays = note.userInfo?["daysSinceBackup"] as? Int
            observed.fulfill()
        }
        defer { center.removeObserver(token) }

        monitor.evaluate(now: now)
        wait(for: [observed], timeout: 1.0)
        XCTAssertEqual(observedDays, 4)
    }

    func testDoesNotPostWhenLastBackupRecent() {
        let now = Date(timeIntervalSince1970: 1_762_000_000)
        let oneDayAgo = now.addingTimeInterval(-1 * 86_400)
        defaultsSuite.set(oneDayAgo, forKey: BackupService.lastSuccessfulBackupDateKey)

        let monitor = BackupMonitor(userDefaults: defaultsSuite, notificationCenter: center)
        let notObserved = expectation(description: "stale banner NOT posted")
        notObserved.isInverted = true
        let token = center.addObserver(
            forName: .backupStaleBanner,
            object: nil,
            queue: nil
        ) { _ in
            notObserved.fulfill()
        }
        defer { center.removeObserver(token) }

        monitor.evaluate(now: now)
        wait(for: [notObserved], timeout: 0.3)
    }

    func testDoesNotPostWhenNoBackupRecorded() {
        // Backup off / never run — shouldn't nag.
        let monitor = BackupMonitor(userDefaults: defaultsSuite, notificationCenter: center)
        let notObserved = expectation(description: "no banner without recorded backup")
        notObserved.isInverted = true
        let token = center.addObserver(
            forName: .backupStaleBanner,
            object: nil,
            queue: nil
        ) { _ in notObserved.fulfill() }
        defer { center.removeObserver(token) }

        monitor.evaluate(now: Date())
        wait(for: [notObserved], timeout: 0.3)
    }
}
