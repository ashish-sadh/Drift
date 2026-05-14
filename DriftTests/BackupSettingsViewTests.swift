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

    // MARK: - BackupOnboardingDecision

    /// Default fresh install: never seen, not enabled, iCloud available → show.
    func testOnboardingDecision_FreshInstallWithICloud_Shows() {
        let defaults = freshDefaults("OnboardingFresh")
        XCTAssertTrue(BackupOnboardingDecision.shouldShow(userDefaults: defaults, iCloudAvailable: true))
    }

    /// User already saw the prompt — do not re-prompt even if backup is still off.
    func testOnboardingDecision_AlreadySeen_DoesNotShow() {
        let defaults = freshDefaults("OnboardingSeen")
        defaults.set(true, forKey: "drift.hasSeenBackupOnboarding")
        XCTAssertFalse(BackupOnboardingDecision.shouldShow(userDefaults: defaults, iCloudAvailable: true))
    }

    /// Backup already on (e.g. user enabled it from Settings) — don't prompt.
    func testOnboardingDecision_BackupAlreadyEnabled_DoesNotShow() {
        let defaults = freshDefaults("OnboardingEnabled")
        defaults.set(true, forKey: "drift_backup_enabled")
        XCTAssertFalse(BackupOnboardingDecision.shouldShow(userDefaults: defaults, iCloudAvailable: true))
    }

    /// iCloud Drive off / no Apple ID — don't prompt (toggle would fail).
    func testOnboardingDecision_ICloudUnavailable_DoesNotShow() {
        let defaults = freshDefaults("OnboardingNoICloud")
        XCTAssertFalse(BackupOnboardingDecision.shouldShow(userDefaults: defaults, iCloudAvailable: false))
    }

    private func freshDefaults(_ name: String) -> UserDefaults {
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
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
