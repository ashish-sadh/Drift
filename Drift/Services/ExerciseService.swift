import Foundation

/// Unified exercise/workout service — used by both UI views and AI tool calls.
/// Wraps WorkoutService + ExerciseDatabase + adds smart builder and progressive overload.
@MainActor
enum ExerciseService {

    // MARK: - Template Start

    /// Find a template by name (fuzzy match). Returns nil if no match.
    static func startTemplate(name: String) -> WorkoutTemplate? {
        guard let templates = try? WorkoutService.fetchTemplates() else { return nil }
        let lower = name.lowercased()
        return templates.first { $0.name.lowercased().contains(lower) }
    }

    // MARK: - Smart Session Builder

    /// Build a smart workout session: max 5 exercises, popular first, with notes.
    /// If user has history, prioritize their exercises. Otherwise use popular defaults.
    static func buildSmartSession(muscleGroup: String? = nil) -> WorkoutTemplate? {
        var exercises: [WorkoutTemplate.TemplateExercise] = []

        // Get user's exercise history (what they actually do)
        let userExercises = (try? WorkoutService.recentExerciseNames(limit: 50)) ?? []

        // Filter by muscle group if specified
        let candidates: [String]
        if let group = muscleGroup {
            let groupLower = group.lowercased()
            // From user history first
            let fromHistory = userExercises.filter {
                ExerciseDatabase.bodyPart(for: $0).lowercased().contains(groupLower)
            }
            // From DB if not enough
            let fromDB = ExerciseDatabase.search(query: group).map(\.name)
            candidates = Array(Set(fromHistory + fromDB))
        } else {
            // Suggest based on what hasn't been trained recently
            let recentParts = recentBodyParts()
            let neglected = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]
                .filter { part in !recentParts.contains(part) }
            let targetPart = neglected.first ?? "Chest"
            let fromHistory = userExercises.filter {
                ExerciseDatabase.bodyPart(for: $0).lowercased() == targetPart.lowercased()
            }
            let fromDB = ExerciseDatabase.search(query: targetPart).map(\.name)
            candidates = Array(Set(fromHistory + fromDB))
        }

        // Pick top 5: user's exercises first, then popular
        let picked = Array(candidates.prefix(5))
        if picked.isEmpty { return nil }

        for name in picked {
            let lastWeight = (try? WorkoutService.lastWeight(for: name)).flatMap { $0 }
            let notes: String
            if let w = lastWeight {
                notes = "3x10 @ \(Int(w)) lbs (last session)"
            } else {
                notes = "3x10 (start light, focus on form)"
            }
            exercises.append(WorkoutTemplate.TemplateExercise(name: name, sets: 3, notes: notes))
        }

        let groupName = muscleGroup ?? "Smart Workout"
        guard let json = try? JSONEncoder().encode(exercises),
              let jsonStr = String(data: json, encoding: .utf8) else { return nil }

        return WorkoutTemplate(
            name: groupName,
            exercisesJson: jsonStr,
            createdAt: DateFormatters.iso8601.string(from: Date())
        )
    }

    // MARK: - Workout Suggestion

    /// Suggest what to train based on recent history.
    static func suggestWorkout() -> String {
        let parts = recentBodyParts()
        let allParts = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]
        let neglected = allParts.filter { !parts.contains($0) }

        var lines: [String] = []
        if neglected.isEmpty {
            lines.append("You've trained all major muscle groups recently.")
        } else {
            lines.append("Haven't trained: \(neglected.joined(separator: ", "))")
        }

        // Check templates
        if let templates = try? WorkoutService.fetchTemplates(), !templates.isEmpty {
            let names = templates.prefix(3).map(\.name).joined(separator: ", ")
            lines.append("Templates: \(names)")
        }

        let count = (try? WorkoutService.fetchWorkouts(limit: 7))?.filter {
            guard let d = DateFormatters.dateOnly.date(from: $0.date) else { return false }
            return Calendar.current.isDate(d, equalTo: Date(), toGranularity: .weekOfYear)
        }.count ?? 0
        lines.append("This week: \(count) workouts")

        return lines.joined(separator: "\n")
    }

    // MARK: - Progressive Overload

    /// Check if user is in progressive overload for an exercise.
    /// Compares estimated 1RM across last 4 sessions.
    static func getProgressiveOverload(exercise: String) -> ProgressiveOverloadInfo? {
        let sets = (try? WorkoutService.fetchExerciseHistory(name: exercise)) ?? []
        let workingSets = sets.filter { !$0.isWarmup && $0.weightLbs != nil && $0.reps != nil }
        guard workingSets.count >= 4 else {
            return ProgressiveOverloadInfo(exercise: exercise, status: .insufficientData, sessions: [], trend: "Not enough data (need 4+ sessions)")
        }

        // Group by workout (use exerciseOrder changes as session boundary proxy)
        // Simpler: take the best 1RM from each batch of sets
        var sessionBest: [Double] = []
        var currentBatch: [Double] = []
        var lastWorkoutId = workingSets.first?.workoutId ?? 0

        for s in workingSets {
            if s.workoutId != lastWorkoutId {
                if let best = currentBatch.max() { sessionBest.append(best) }
                currentBatch = []
                lastWorkoutId = s.workoutId
            }
            if let rm = s.estimated1RM { currentBatch.append(rm) }
        }
        if let best = currentBatch.max() { sessionBest.append(best) }

        guard sessionBest.count >= 2 else {
            return ProgressiveOverloadInfo(exercise: exercise, status: .insufficientData, sessions: sessionBest, trend: "Not enough sessions")
        }

        // Compare last 4 sessions
        let recent = Array(sessionBest.prefix(4))
        let first = recent.last!  // oldest
        let last = recent.first!  // newest (history is newest-first)
        let change = last - first

        let status: OverloadStatus
        let trend: String
        if change > 5 {
            status = .improving
            trend = "Improving: +\(Int(change)) lb estimated 1RM over \(recent.count) sessions"
        } else if change < -5 {
            status = .declining
            trend = "Declining: \(Int(change)) lb estimated 1RM over \(recent.count) sessions"
        } else {
            status = .stalling
            trend = "Stalling: 1RM roughly the same for \(recent.count) sessions. Try adding weight or reps."
        }

        return ProgressiveOverloadInfo(exercise: exercise, status: status, sessions: recent, trend: trend)
    }

    // MARK: - Exercise Lookup

    /// Exercises for a muscle group, sorted by user history (popular first).
    static func exercisesByMuscle(group: String) -> [ExerciseDatabase.ExerciseInfo] {
        let userExercises = Set((try? WorkoutService.recentExerciseNames(limit: 100)) ?? [])
        let results = ExerciseDatabase.search(query: group)
        // User's exercises first
        return results.sorted { a, b in
            let aUsed = userExercises.contains(a.name)
            let bUsed = userExercises.contains(b.name)
            if aUsed && !bUsed { return true }
            if !aUsed && bUsed { return false }
            return a.name < b.name
        }
    }

    /// Most popular exercises from user's history.
    static func popularExercises(limit: Int = 10) -> [String] {
        (try? WorkoutService.recentExerciseNames(limit: limit)) ?? []
    }

    // MARK: - Helpers

    /// Body parts trained in the last 7 days.
    private static func recentBodyParts() -> Set<String> {
        guard let workouts = try? WorkoutService.fetchWorkouts(limit: 7) else { return [] }
        var parts: Set<String> = []
        for w in workouts.prefix(5) {
            guard let wId = w.id,
                  let d = DateFormatters.dateOnly.date(from: w.date),
                  Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 99 < 7,
                  let sets = try? WorkoutService.fetchSets(forWorkout: wId) else { continue }
            for name in Set(sets.map(\.exerciseName)) {
                parts.insert(ExerciseDatabase.bodyPart(for: name))
            }
        }
        return parts
    }
}

// MARK: - Data Types

enum OverloadStatus: String, Sendable {
    case improving, stalling, declining, insufficientData
}

struct ProgressiveOverloadInfo: Sendable {
    let exercise: String
    let status: OverloadStatus
    let sessions: [Double]  // estimated 1RM per session
    let trend: String       // natural language description
}
