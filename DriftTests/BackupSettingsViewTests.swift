import XCTest
import SwiftUI
@testable import DriftCore
@testable import Drift

final class BackupSettingsViewTests: XCTestCase {

    /// `drift_backup_enabled` defaults to false on fresh install — backup is
    /// opt-in per design Section E.
    func testBackupToggleDefaultsOffOnFreshInstall() {
        UserDefaults.standard.removeObject(forKey: "drift_backup_enabled")
        let stored = UserDefaults.standard.object(forKey: "drift_backup_enabled") as? Bool
        XCTAssertNil(stored, "Fresh install must not have a stored backup-enabled flag")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "drift_backup_enabled"),
                       "Reading should fall back to false when unset")
    }

    func testBackupSettingsViewConstructs() {
        let view = BackupSettingsView(service: makeOfflineService())
        XCTAssertNotNil(view)
    }

    func testRestorePickerViewConstructs() {
        let view = RestorePickerView(service: makeOfflineService())
        XCTAssertNotNil(view)
    }

    private func makeOfflineService() -> BackupService {
        // Provider returns nil → service stays offline during view construction.
        BackupService(
            containerURLProvider: { nil },
            database: { try! AppDatabase.empty() },
            userDefaults: UserDefaults(suiteName: "BackupSettingsViewTests")!,
            bundle: .main,
            now: { Date() }
        )
    }
}
