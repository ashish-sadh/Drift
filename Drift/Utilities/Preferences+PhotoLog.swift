import Foundation
import DriftCore

/// iOS-only Photo Log preferences — depend on `CloudVisionProvider` which
/// uses iOS Keychain. Lives in Drift app rather than DriftCore.
extension Preferences {

    private static let photoLogProviderKey = "drift_photo_log_provider"
    private static let photoLogTipDismissedKey = "drift_photo_log_tip_dismissed"

    /// True once the user has dismissed the BYOK onboarding tip. Persisted so
    /// the tip stays hidden across app restarts.
    static var hasSeenPhotoLogTip: Bool {
        get { UserDefaults.standard.bool(forKey: photoLogTipDismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: photoLogTipDismissedKey) }
    }

    /// Currently active cloud provider for Photo Log. Default is Gemini (free tier).
    static var photoLogProvider: CloudVisionProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: photoLogProviderKey) ?? ""
            return CloudVisionProvider(rawValue: raw) ?? .gemini
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: photoLogProviderKey) }
    }

    /// Model override per provider. Falls back to provider's default when no value
    /// stored OR stored value is no longer available.
    static func photoLogModel(for provider: CloudVisionProvider) -> String {
        let key = photoLogModelKey(for: provider)
        let raw = UserDefaults.standard.string(forKey: key) ?? ""
        if !raw.isEmpty, provider.availableModels.contains(raw) {
            return raw
        }
        return provider.defaultModel
    }

    static func setPhotoLogModel(_ model: String, for provider: CloudVisionProvider) {
        UserDefaults.standard.set(model, forKey: photoLogModelKey(for: provider))
    }

    private static func photoLogModelKey(for provider: CloudVisionProvider) -> String {
        "drift_photo_log_model_\(provider.rawValue)"
    }
}
