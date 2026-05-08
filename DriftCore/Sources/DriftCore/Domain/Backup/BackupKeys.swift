import Foundation

public enum BackupKeys {
    /// UserDefaults keys included in `.driftbackup` archives.
    ///
    /// **Primitive-only.** The Packager / Restorer JSON pipeline currently
    /// supports Bool / Int / Double / String. Codable-Data preferences
    /// (`drift_weight_goal`, `drift_tdee_config`, `drift_algorithm_config`,
    /// `drift_custom_exercises`) and `[String]` arrays
    /// (`drift_exercise_favorites`) are NOT yet round-trippable and are
    /// excluded — see #701 for the follow-up to add Data/array support.
    /// Adding a non-primitive key here without first lifting that limit
    /// silently drops it on package via `BackupPackager.jsonSafeValue`.
    ///
    /// **Real keys only.** Each entry MUST match a key actually used by
    /// production code (grep `forKey: "..."` to verify). Adding a fictional
    /// dotted-camelCase key here leaks an illusion of breadth without
    /// backing up anything — see the closed root cause for #700.
    public static let userDefaultsAllowlist: [String] = [
        // Units / display
        "weight_unit",                                  // Preferences.weightUnit (String enum raw)
        "drift_weight_chart_calories",                  // Preferences.weightChartCaloriesEnabled (Bool, may be unset)
        "drift_cycle_fertile_window",                   // Preferences.cycleFertileWindow (Bool)

        // AI / chat
        "drift_ai_enabled",                             // Preferences.aiEnabled (Bool)
        "drift_conversation_history_enabled",           // Preferences.conversationHistoryEnabled (Bool)
        "drift_chat_telemetry_enabled",                 // Preferences.chatTelemetryEnabled (Bool)
        "drift_use_remote_model_on_wifi",               // Preferences.useRemoteModelOnWiFi (Bool)
        "drift_preferred_ai_backend",                   // Preferences.preferredAIBackend (String enum raw)
        "drift_photo_log_enabled",                      // Preferences.photoLogEnabled (Bool)

        // Reminders / nudges
        "drift_health_nudges",                          // Preferences.healthNudgesEnabled (Bool)
        "drift_meal_reminders",                         // Preferences.mealRemindersEnabled (Bool)
        "drift_medication_reminders",                   // Preferences.medicationRemindersEnabled (Bool)
        "drift_glp1_reminders",                         // Preferences.glp1RemindersEnabled (Bool)

        // Search / data sources
        "drift_online_food_search",                     // Preferences.onlineFoodSearchEnabled (Bool)
        "drift_usda_api_key",                           // Preferences.usdaApiKey (String)

        // Hydration
        "drift_water_goal_ml",                          // Preferences.waterGoalMl (Double)
    ]

    public static let manifestFileName = "manifest.json"
    public static let databaseFileName = "drift.sqlite"
    public static let preferencesFileName = "preferences.json"
    public static let backupFileExtension = "driftbackup"
}
