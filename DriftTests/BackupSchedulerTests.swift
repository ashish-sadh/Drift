import XCTest
import BackgroundTasks
@testable import DriftCore
@testable import Drift

final class BackupSchedulerTests: XCTestCase {

    // MARK: - registerBackgroundTask

    func testRegisterBackgroundTaskRecordsIdentifier() {
        // DriftApp.init() runs at test-host launch and already calls
        // registerBackgroundTask(); calling again is a no-op (BGTaskScheduler
        // asserts on duplicate registration, so the scheduler must
        // short-circuit). The ledger should reflect the wiring either way.
        BackupScheduler.registerBackgroundTask()
        XCTAssertTrue(
            BackupScheduler.registeredTaskIdentifiers.contains(
                BackupScheduler.taskIdentifier
            ),
            "registerBackgroundTask must record the daily-backup identifier so the rest of the app can verify the launch handler was wired"
        )
    }

    func testTaskIdentifierMatchesDesignContract() {
        // Exactly the string in Docs/designs/561-icloud-backup.md and the
        // BGTaskSchedulerPermittedIdentifiers array in Info.plist. If this
        // diverges from the plist Apple asserts at registration time.
        XCTAssertEqual(
            BackupScheduler.taskIdentifier,
            "com.ashish-sadh.Drift.dailyBackup"
        )
    }

    // MARK: - scheduleNextBackup

    func testScheduleNextBackupSubmitsRequestWithinNext24Hours() {
        let fixedNow = Date(timeIntervalSince1970: 1_762_412_412)
        let captured = CapturingSubmitter()
        let scheduler = makeScheduler(now: { fixedNow }, submitter: captured)

        scheduler.scheduleNextBackup()

        let request = try? XCTUnwrap(captured.requests.first)
        XCTAssertEqual(request?.identifier, BackupScheduler.taskIdentifier)
        guard let earliest = request?.earliestBeginDate else {
            XCTFail("expected an earliestBeginDate")
            return
        }
        XCTAssertGreaterThan(earliest, fixedNow)
        XCTAssertLessThanOrEqual(
            earliest.timeIntervalSince(fixedNow),
            24 * 60 * 60,
            "earliestBeginDate must be within the next 24h so iOS schedules the next nightly run, not several days out"
        )
    }

    func testScheduleNextBackupTargetsThreeAMDeviceLocal() throws {
        let fixedNow = Date(timeIntervalSince1970: 1_762_412_412)
        let captured = CapturingSubmitter()
        let scheduler = makeScheduler(now: { fixedNow }, submitter: captured)

        scheduler.scheduleNextBackup()

        let earliest = try XCTUnwrap(captured.requests.first?.earliestBeginDate)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: earliest)
        XCTAssertEqual(hour, 3, "Nightly backup must fire at 3 AM device-local")
    }

    func testScheduleNextBackupRequiresNetworkButNotPower() throws {
        let captured = CapturingSubmitter()
        let scheduler = makeScheduler(submitter: captured)

        scheduler.scheduleNextBackup()

        let request = try XCTUnwrap(
            captured.requests.first as? BGProcessingTaskRequest
        )
        XCTAssertTrue(request.requiresNetworkConnectivity)
        XCTAssertFalse(request.requiresExternalPower)
    }

    func testScheduleNextBackupSwallowsSubmitterErrors() {
        // BGTaskScheduler.submit can throw if the request is invalid (e.g.
        // too many pending requests, identifier not in Info.plist). The
        // scheduler must swallow rather than crash — the OS surfaces the
        // failure in console logs and there's no recovery at the app layer.
        let scheduler = makeScheduler(submitter: ThrowingSubmitter())
        XCTAssertNoThrow(scheduler.scheduleNextBackup())
    }

    // MARK: - handle(_:) — testable seam over handleBackgroundTask

    func testHandleSuccessfulBackupCompletesAndReschedules() async {
        let captured = CapturingSubmitter()
        let scheduler = makeScheduler(
            backupRunner: { URL(fileURLWithPath: "/tmp/fake.driftbackup") },
            submitter: captured
        )
        let fakeTask = FakeTaskHandle()

        await scheduler.handle(fakeTask)

        XCTAssertEqual(fakeTask.completionCalls, [true])
        XCTAssertEqual(captured.requests.count, 1, "Successful backup must reschedule")
        XCTAssertNotNil(
            fakeTask.expirationHandler,
            "expirationHandler must be wired so iOS can cancel cleanly on overrun"
        )
    }

    func testHandleFailedBackupCompletesWithFalseAndStillReschedules() async {
        let captured = CapturingSubmitter()
        let scheduler = makeScheduler(
            backupRunner: { throw BackupError.iCloudUnavailable },
            submitter: captured
        )
        let fakeTask = FakeTaskHandle()

        await scheduler.handle(fakeTask)

        XCTAssertEqual(fakeTask.completionCalls, [false])
        XCTAssertEqual(
            captured.requests.count, 1,
            "Failure must still reschedule — backoff is iOS's job, not ours; we must not let one bad night silence future attempts"
        )
    }

    // MARK: - Helpers

    private func makeScheduler(
        now: @escaping () -> Date = { Date() },
        calendar: Calendar = .current,
        backupRunner: @escaping () async throws -> URL = {
            URL(fileURLWithPath: "/tmp/fake.driftbackup")
        },
        submitter: TestSubmitter = CapturingSubmitter()
    ) -> BackupScheduler {
        return BackupScheduler(
            now: now,
            calendar: calendar,
            backupRunner: backupRunner,
            submitter: { try submitter.submit($0) }
        )
    }
}

// MARK: - Test doubles

private protocol TestSubmitter {
    func submit(_ request: BGProcessingTaskRequest) throws
}

private final class CapturingSubmitter: TestSubmitter {
    private(set) var requests: [BGProcessingTaskRequest] = []
    func submit(_ request: BGProcessingTaskRequest) throws {
        requests.append(request)
    }
}

private final class ThrowingSubmitter: TestSubmitter {
    struct Boom: Error {}
    func submit(_ request: BGProcessingTaskRequest) throws {
        throw Boom()
    }
}

private final class FakeTaskHandle: BackgroundTaskHandle {
    var expirationHandler: (() -> Void)?
    private(set) var completionCalls: [Bool] = []
    func setTaskCompleted(success: Bool) {
        completionCalls.append(success)
    }
}
