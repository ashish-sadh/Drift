import Foundation

/// Display formatter for `WorkoutSet`. References `Preferences.weightUnit`.
extension WorkoutSet {
    public var display: String {
        let u = Preferences.weightUnit
        if let d = durationSec, d > 0 {
            let m = d / 60; let s = d % 60
            let timeStr = m > 0 ? "\(m):\(String(format: "%02d", s))" : "\(s)s"
            let w = weightLbs.map { "\(Int(u.convertFromLbs($0))) \(u.displayName) · " } ?? ""
            return "\(w)\(timeStr)"
        }
        let w = weightLbs.map { "\(Int(u.convertFromLbs($0))) \(u.displayName)" } ?? "BW"
        let r = reps.map { "× \($0)" } ?? ""
        return "\(w) \(r)"
    }
}
