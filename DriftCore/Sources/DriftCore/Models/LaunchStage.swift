import Foundation

/// Coarse phase of the cold-launch sequence in DriftApp's `.task` block. The
/// splash view reads this to show progressive status text instead of a single
/// indeterminate spinner — users on a slow cold-launch (TestFlight update +
/// GRDB migration + HealthKit auth) see *which* step is running.
public enum LaunchStage: Equatable, Hashable, Sendable {
    case starting
    case syncingHealth
    case calculatingTrends
    case estimatingEnergy
    case almostThere
    case complete

    public var statusText: String {
        switch self {
        case .starting: return "Starting up…"
        case .syncingHealth: return "Syncing health data…"
        case .calculatingTrends: return "Calculating trends…"
        case .estimatingEnergy: return "Estimating energy budget…"
        case .almostThere: return "Almost there…"
        case .complete: return ""
        }
    }
}
