import Foundation

/// User preferences persisted in `UserDefaults`. Cross-platform — UserDefaults
/// works on macOS too. Photo Log preferences (which depend on the iOS-only
/// `CloudVisionProvider` enum) live in a Drift-side extension.
public enum Preferences {

    // MARK: - Weight Unit

    private static let weightUnitKey = "weight_unit"

    public static var weightUnit: WeightUnit {
        get {
            guard let raw = UserDefaults.standard.string(forKey: weightUnitKey),
                  let unit = WeightUnit(rawValue: raw) else {
                return .lbs
            }
            return unit
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: weightUnitKey) }
    }

    // MARK: - Cycle

    private static let cycleFertileWindowKey = "drift_cycle_fertile_window"

    public static var cycleFertileWindow: Bool {
        get { UserDefaults.standard.bool(forKey: cycleFertileWindowKey) }
        set { UserDefaults.standard.set(newValue, forKey: cycleFertileWindowKey) }
    }

    // MARK: - AI

    private static let aiEnabledKey = "drift_ai_enabled"

    public static var aiEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: aiEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: aiEnabledKey) }
    }

    // MARK: - Online Food Search

    private static let onlineFoodSearchKey = "drift_online_food_search"

    /// When enabled, food search queries are sent to USDA and Open Food Facts APIs
    /// when local results are insufficient. Default: ON.
    public static var onlineFoodSearchEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: onlineFoodSearchKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: onlineFoodSearchKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: onlineFoodSearchKey) }
    }

    // MARK: - Health Nudges

    private static let healthNudgesKey = "drift_health_nudges"

    public static var healthNudgesEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: healthNudgesKey) }
        set { UserDefaults.standard.set(newValue, forKey: healthNudgesKey) }
    }

    // MARK: - Hydration

    private static let waterGoalMlKey = "drift_water_goal_ml"

    /// Daily water intake goal in millilitres. Default: 2000ml.
    public static var waterGoalMl: Double {
        get {
            let v = UserDefaults.standard.double(forKey: waterGoalMlKey)
            return v > 0 ? v : 2000
        }
        set { UserDefaults.standard.set(newValue, forKey: waterGoalMlKey) }
    }

    // MARK: - Smart Meal Reminders

    private static let mealRemindersKey = "drift_meal_reminders"

    /// Smart meal reminders: contextual "Time to log breakfast" notifications
    /// fired ~30min after the user's typical meal time, only when their
    /// timing is consistent (std dev < 45min) AND they haven't logged that
    /// meal yet today. Default OFF — opt-in like Photo Log Beta. #385.
    public static var mealRemindersEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: mealRemindersKey) }
        set { UserDefaults.standard.set(newValue, forKey: mealRemindersKey) }
    }

    // MARK: - Medication Reminders

    private static let medicationRemindersKey = "drift_medication_reminders"

    /// Smart medication reminders: contextual dose nudge fired ~2h after the
    /// user's typical log time, only when they've logged a medication 3+ times
    /// (consistent pattern) and haven't logged it yet today. Default OFF. #592.
    public static var medicationRemindersEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: medicationRemindersKey) }
        set { UserDefaults.standard.set(newValue, forKey: medicationRemindersKey) }
    }

    // MARK: - Conversation History

    private static let conversationHistoryEnabledKey = "drift_conversation_history_enabled"

    public static var conversationHistoryEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: conversationHistoryEnabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: conversationHistoryEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: conversationHistoryEnabledKey) }
    }

    // MARK: - Chat Telemetry

    private static let chatTelemetryEnabledKey = "drift_chat_telemetry_enabled"

    public static var chatTelemetryEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: chatTelemetryEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: chatTelemetryEnabledKey) }
    }

    // MARK: - Remote Model

    private static let useRemoteModelOnWiFiKey = "drift_use_remote_model_on_wifi"

    /// When enabled, AI chat routes through a remote model (Anthropic/OpenAI) on Wi-Fi.
    /// Default: OFF. Not exposed in production UI — architectural prep only.
    public static var useRemoteModelOnWiFi: Bool {
        get { UserDefaults.standard.bool(forKey: useRemoteModelOnWiFiKey) }
        set { UserDefaults.standard.set(newValue, forKey: useRemoteModelOnWiFiKey) }
    }

    // MARK: - Preferred AI Backend (chat routing)

    private static let preferredAIBackendKey = "drift_preferred_ai_backend"

    /// User-selected AI backend for chat. Default: `.llamaCpp` (privacy-first).
    /// Persisted across launches; flipped by the in-chat cpu/cloud toggle when
    /// both local and remote backends are available. Mid-thread changes don't
    /// reset history — `LocalAIService` swaps the underlying backend in place.
    public static var preferredAIBackend: AIBackendType {
        get {
            let raw = UserDefaults.standard.string(forKey: preferredAIBackendKey) ?? ""
            return AIBackendType(rawValue: raw) ?? .llamaCpp
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferredAIBackendKey) }
    }

    // MARK: - USDA API Key

    private static let usdaApiKeyKey = "drift_usda_api_key"

    /// USDA FoodData Central API key. Register a free key at https://fdc.nal.usda.gov/api-guide.html
    /// to raise the rate limit from 1,000 req/day (DEMO_KEY) to 3,600 req/hour.
    /// When empty, USDAFoodService falls back to DEMO_KEY.
    public static var usdaApiKey: String {
        get { UserDefaults.standard.string(forKey: usdaApiKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: usdaApiKeyKey) }
    }

    // MARK: - Photo Log Beta opt-in

    private static let photoLogEnabledKey = "drift_photo_log_enabled"

    /// Photo Log Beta opt-in. When OFF (default), camera entry points are hidden.
    public static var photoLogEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: photoLogEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: photoLogEnabledKey) }
    }
}
