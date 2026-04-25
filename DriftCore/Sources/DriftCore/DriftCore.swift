// DriftCore — multi-platform core for the Drift health app.
//
// This module contains the platform-agnostic logic that ships with the iOS app
// AND is testable on macOS without the simulator. iOS-bound code (SwiftUI views,
// HealthKit live integration, UIKit OCR) stays in the iOS app target.
//
// Public surface is grown incrementally as files are moved in. See
// /Users/ashishsadh/workspace/Drift/DriftCore/MIGRATION.md (when present) for the
// per-batch plan.

public enum DriftCore {
    /// Sentinel constant — replaced once the first real type lands here.
    public static let bootstrap = "ok"
}
