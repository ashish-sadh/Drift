import Foundation

/// Tracks which screen the user is currently viewing for context-aware AI responses.
@MainActor @Observable
public final class AIScreenTracker {
    public static let shared = AIScreenTracker()
    public var currentScreen: AIScreen = .dashboard

    private init() {}
}
