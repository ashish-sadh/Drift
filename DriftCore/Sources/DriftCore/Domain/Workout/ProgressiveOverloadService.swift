import Foundation

// MARK: - Types

public struct PlateauResult: Sendable {
    public let exercise: String
    public let isOnPlateau: Bool
    public let sessionsChecked: Int
    public let suggestion: String
    public let isCompound: Bool

    public var summary: String {
        guard isOnPlateau else { return "No plateau detected for \(exercise)." }
        return "Plateau on \(exercise) (\(sessionsChecked) sessions at same weight/reps). \(suggestion)"
    }
}

// MARK: - Service

public enum ProgressiveOverloadService {

    private static let dismissedKey = "plateau_dismissed"
    private static let cooldownSeconds: TimeInterval = 7 * 24 * 3600

    // MARK: - Plateau Detection

    /// Returns plateau status for an exercise.
    /// Plateau = best working set (weight+reps) unchanged for ≥3 consecutive sessions.
    public static func checkPlateau(exercise: String) -> PlateauResult {
        let sets = (try? WorkoutService.fetchExerciseHistory(name: exercise)) ?? []
        let workingSets = sets.filter { !$0.isWarmup && $0.weightLbs != nil && $0.reps != nil && $0.reps! > 0 }

        let sessions = groupBySession(workingSets)
        guard sessions.count >= 3 else {
            return PlateauResult(exercise: exercise, isOnPlateau: false, sessionsChecked: sessions.count, suggestion: "", isCompound: isCompound(exercise))
        }

        let recent = Array(sessions.prefix(6))
        let bests = recent.compactMap { bestSet(in: $0) }
        guard bests.count >= 3 else {
            return PlateauResult(exercise: exercise, isOnPlateau: false, sessionsChecked: bests.count, suggestion: "", isCompound: isCompound(exercise))
        }

        // Check if ≥3 consecutive sessions share identical weight+reps
        var plateauCount = 1
        for i in 1..<bests.count {
            let prev = bests[i - 1]
            let curr = bests[i]
            if abs(prev.0 - curr.0) < 0.5 && prev.1 == curr.1 {
                plateauCount += 1
            } else {
                break
            }
        }

        let onPlateau = plateauCount >= 3
        let compound = isCompound(exercise)
        let suggestion = onPlateau ? makeSuggestion(compound: compound, currentWeight: bests[0].0) : ""

        return PlateauResult(exercise: exercise, isOnPlateau: onPlateau, sessionsChecked: plateauCount, suggestion: suggestion, isCompound: compound)
    }

    /// Returns plateau results for all exercises with ≥3 sessions, filtered by dismissed state.
    public static func allPlateaus(respectDismissed: Bool = true) -> [PlateauResult] {
        let names = (try? WorkoutService.allExerciseNames()) ?? []
        return names.compactMap { name -> PlateauResult? in
            if respectDismissed && isDismissed(exercise: name) { return nil }
            let result = checkPlateau(exercise: name)
            return result.isOnPlateau ? result : nil
        }
    }

    // MARK: - Dismissed State

    public static func dismiss(exercise: String) {
        var map = dismissedMap()
        map[exercise] = Date().timeIntervalSince1970
        UserDefaults.standard.set(map, forKey: dismissedKey)
    }

    public static func isDismissed(exercise: String) -> Bool {
        let map = dismissedMap()
        guard let ts = map[exercise] else { return false }
        return Date().timeIntervalSince1970 - ts < cooldownSeconds
    }

    // MARK: - Private Helpers

    private static func groupBySession(_ sets: [WorkoutSet]) -> [[WorkoutSet]] {
        var sessions: [[WorkoutSet]] = []
        var current: [WorkoutSet] = []
        var lastId: Int64 = sets.first?.workoutId ?? 0

        for s in sets {
            if s.workoutId != lastId {
                if !current.isEmpty { sessions.append(current) }
                current = []
                lastId = s.workoutId
            }
            current.append(s)
        }
        if !current.isEmpty { sessions.append(current) }
        return sessions
    }

    /// Best working set in a session = highest weight (ties broken by most reps).
    private static func bestSet(in sets: [WorkoutSet]) -> (Double, Int)? {
        let working = sets.filter { !$0.isWarmup && $0.weightLbs != nil && $0.reps != nil && $0.reps! > 0 }
        guard !working.isEmpty else { return nil }
        let best = working.max { a, b in
            let aw = a.weightLbs!, bw = b.weightLbs!
            if aw != bw { return aw < bw }
            return a.reps! < b.reps!
        }
        guard let b = best, let w = b.weightLbs, let r = b.reps else { return nil }
        return (w, r)
    }

    private static func isCompound(_ exercise: String) -> Bool {
        if let info = ExerciseDatabase.info(for: exercise) {
            if info.equipment.lowercased() == "barbell" { return true }
            if info.primaryMuscles.count >= 2 { return true }
        }
        // Fallback: known compound keyword list
        let compoundKeywords = ["squat", "deadlift", "bench press", "overhead press", "row", "pull-up", "chin-up",
                                "dip", "lunge", "clean", "snatch", "press", "thrust"]
        let lower = exercise.lowercased()
        return compoundKeywords.contains { lower.contains($0) }
    }

    private static func makeSuggestion(compound: Bool, currentWeight: Double) -> String {
        let wu = Preferences.weightUnit
        if compound {
            let addLbs = wu == .kg ? WeightUnit.kg.convertToLbs(2.5) : 5.0
            let displayAdd = wu == .kg ? "2.5 kg" : "5 lbs"
            let newWeight = Int(wu.convertFromLbs(currentWeight + addLbs))
            return "Try adding \(displayAdd) → \(newWeight) \(wu.displayName) next session."
        } else {
            return "Try adding 1 rep to each set, or perform a drop-set at the end."
        }
    }

    private static func dismissedMap() -> [String: TimeInterval] {
        UserDefaults.standard.dictionary(forKey: dismissedKey) as? [String: TimeInterval] ?? [:]
    }
}
