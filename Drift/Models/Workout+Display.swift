import Foundation
import DriftCore

/// Display formatter for `WorkoutSet`. References `Preferences.weightUnit`
/// (which lives in the iOS app target alongside SwiftUI), so the formatter
/// stays here while the data type lives in DriftCore.
extension WorkoutSet {
    var display: String {
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
