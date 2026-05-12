import Foundation
import DriftCore

extension Notification.Name {
    /// Fired by `BackupMonitor` when the gap since the last successful iCloud
    /// backup exceeds `BackupMonitor.staleThresholdDays`. DashboardView listens
    /// and shows an inline "tap to fix" banner.
    public static let backupStaleBanner = Notification.Name("backupStaleBanner")
}

/// Posts `backupStaleBanner` whenever `BackupService.lastSuccessfulBackupDate`
/// is older than the threshold. Stateless — the only side effect is the
/// notification post. DashboardView decides whether to render a banner.
///
/// `checkOnForeground()` is the single entry point; call from `scenePhase`
/// transitions. Tests poke `evaluate(now:)` directly.
public final class BackupMonitor: @unchecked Sendable {
    public static let staleThresholdDays = 3

    public static let shared = BackupMonitor()

    private let userDefaults: UserDefaults
    private let notificationCenter: NotificationCenter

    public convenience init() {
        self.init(userDefaults: .standard, notificationCenter: .default)
    }

    public init(userDefaults: UserDefaults, notificationCenter: NotificationCenter) {
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
    }

    /// Hook this to `scenePhase == .active` transitions. Reads
    /// `lastSuccessfulBackupDate` from UserDefaults and posts the stale
    /// banner notification if the gap exceeds the threshold.
    public func checkOnForeground(now: Date = Date()) {
        evaluate(now: now)
    }

    func evaluate(now: Date) {
        // Backup off / never run → don't nag. The first-launch sheet and
        // Settings UI cover discoverability.
        guard let last = userDefaults.object(
            forKey: BackupService.lastSuccessfulBackupDateKey
        ) as? Date else { return }

        let gap = now.timeIntervalSince(last)
        let threshold = TimeInterval(Self.staleThresholdDays * 24 * 60 * 60)
        guard gap > threshold else { return }

        let days = Int(gap / 86_400)
        notificationCenter.post(
            name: .backupStaleBanner,
            object: nil,
            userInfo: ["daysSinceBackup": days]
        )
    }
}
