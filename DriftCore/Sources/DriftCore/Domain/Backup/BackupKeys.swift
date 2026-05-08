import Foundation

public enum BackupKeys {
    public static let userDefaultsAllowlist: [String] = [
        "drift.weightGoal",
        "drift.tdeeConfig",
        "drift.dailyCalorieTarget",
        "drift.userBirthYear",
        "drift.userHeightCm",
        "drift.userSex",
        "drift.activityLevel",
        "drift.onboardingComplete",
        "drift.backupEnabled",
        "drift.preferredUnits",
        "drift.foodSortOrder",
    ]

    public static let manifestFileName = "manifest.json"
    public static let databaseFileName = "drift.sqlite"
    public static let preferencesFileName = "preferences.json"
    public static let backupFileExtension = "driftbackup"
}
