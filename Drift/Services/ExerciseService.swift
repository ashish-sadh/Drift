import Foundation

/// Unified exercise/workout service — used by both UI views and AI tool calls.
/// Wraps WorkoutService + ExerciseDatabase + adds smart builder and progressive overload.
@MainActor
enum ExerciseService {

    /// Reasoning for the last smart session built. Read after calling buildSmartSession().
    static var lastSessionReasoning: String?

    // MARK: - Template Start

    /// Find a template by name (fuzzy match). Returns nil if no match.
    static func startTemplate(name: String) -> WorkoutTemplate? {
        guard let templates = try? WorkoutService.fetchTemplates() else { return nil }
        let lower = name.lowercased()
        return templates.first { $0.name.lowercased().contains(lower) }
    }

    // MARK: - Smart Session Builder

    /// Build a smart workout session: max 5 exercises, popular first, with reasoning notes.
    /// If user has history, prioritize their exercises. Otherwise use popular defaults.
    static func buildSmartSession(muscleGroup: String? = nil) -> WorkoutTemplate? {
        var exercises: [WorkoutTemplate.TemplateExercise] = []
        let userExerciseSet = Set((try? WorkoutService.recentExerciseNames(limit: 50)) ?? [])

        // Determine muscle group + build reasoning
        let targetPart: String
        var reasonLines: [String] = []

        if let group = muscleGroup {
            targetPart = group
            reasonLines.append("Targeting \(group.capitalized) (your request)")
        } else {
            let recentParts = recentBodyParts()
            let allParts = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]
            let neglected = allParts.filter { !recentParts.contains($0) }
            targetPart = neglected.first ?? "Chest"
            let days = daysSinceLastTrained(targetPart)
            if days < 99 {
                reasonLines.append("Targeting \(targetPart) — \(days) days since last trained")
            } else {
                reasonLines.append("Targeting \(targetPart) — not trained recently")
            }
            if !neglected.isEmpty {
                reasonLines.append("Neglected groups: \(neglected.joined(separator: ", "))")
            }
        }

        // Gather candidates: user history first, then DB
        let groupLower = targetPart.lowercased()
        let fromHistory = userExerciseSet.filter {
            ExerciseDatabase.bodyPart(for: $0).lowercased().contains(groupLower)
        }
        let fromDB = ExerciseDatabase.search(query: targetPart).map(\.name)
        let candidates = Array(Set(Array(fromHistory) + fromDB))

        let picked = Array(candidates.prefix(5))
        if picked.isEmpty { return nil }

        // Build exercises with reasoning notes + form tips
        for name in picked {
            let lastWeight = (try? WorkoutService.lastWeight(for: name)).flatMap { $0 }
            let fromUser = userExerciseSet.contains(name)

            // Base: sets/weight info
            var parts: [String] = []
            if let w = lastWeight {
                parts.append("3x10 @ \(Int(w)) lbs")
            } else if fromUser {
                parts.append("3x10")
            } else {
                parts.append("3x10 — start light")
            }

            // Form tip
            if let tip = formTip(for: name) {
                parts.append("Tip: \(tip)")
            }

            exercises.append(WorkoutTemplate.TemplateExercise(name: name, sets: 3, notes: parts.joined(separator: " | ")))
        }

        // Summarize exercise sources in reasoning
        let fromHistoryCount = picked.filter { userExerciseSet.contains($0) }.count
        let fromDBCount = picked.count - fromHistoryCount
        if fromHistoryCount > 0 { reasonLines.append("\(fromHistoryCount) exercises from your history") }
        if fromDBCount > 0 { reasonLines.append("\(fromDBCount) new exercises suggested") }
        lastSessionReasoning = reasonLines.joined(separator: "\n")

        guard let json = try? JSONEncoder().encode(exercises),
              let jsonStr = String(data: json, encoding: .utf8) else { return nil }

        return WorkoutTemplate(
            name: "Coached Workout",
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

    /// Days since a muscle group was last trained. Returns 99 if never.
    private static func daysSinceLastTrained(_ part: String) -> Int {
        guard let workouts = try? WorkoutService.fetchWorkouts(limit: 20) else { return 99 }
        for w in workouts {
            guard let wId = w.id,
                  let d = DateFormatters.dateOnly.date(from: w.date),
                  let sets = try? WorkoutService.fetchSets(forWorkout: wId) else { continue }
            let parts = Set(sets.map { ExerciseDatabase.bodyPart(for: $0.exerciseName) })
            if parts.contains(part) {
                return Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 99
            }
        }
        return 99
    }

    /// One-line form tip for common exercises. Matched by keyword in exercise name.
    static func formTip(for exercise: String) -> String? {
        let e = exercise.lowercased()
        // Chest
        if e.contains("bench press") && !e.contains("close") { return "Drive feet into floor, retract shoulder blades" }
        if e.contains("incline") && e.contains("press") { return "30-45 degree angle, control the negative" }
        if e.contains("fly") || e.contains("flye") { return "Slight bend in elbows, squeeze at the top" }
        if e.contains("push up") || e.contains("pushup") { return "Core tight, elbows 45 degrees from body" }
        if e.contains("dip") { return "Lean forward for chest, upright for triceps" }
        // Back
        if e.contains("deadlift") && !e.contains("romanian") { return "Brace core, push floor away, bar close to shins" }
        if e.contains("romanian") || e.contains("rdl") { return "Hinge at hips, slight knee bend, feel the hamstring stretch" }
        if e.contains("barbell row") || e.contains("bent over row") { return "Pull to lower chest, squeeze shoulder blades" }
        if e.contains("pull up") || e.contains("pullup") || e.contains("chin up") { return "Full hang at bottom, drive elbows down" }
        if e.contains("lat pulldown") { return "Pull to upper chest, lean back slightly" }
        if e.contains("cable row") || e.contains("seated row") { return "Pull to belly, chest up, squeeze back" }
        // Legs
        if e.contains("squat") && !e.contains("split") { return "Brace core, knees track over toes, depth to parallel" }
        if e.contains("leg press") { return "Full range of motion, don't lock knees at top" }
        if e.contains("lunge") || e.contains("split squat") { return "Front knee over ankle, torso upright" }
        if e.contains("leg curl") { return "Control the negative, full contraction at top" }
        if e.contains("leg extension") { return "Pause at top, control the descent" }
        if e.contains("calf raise") || e.contains("calf") { return "Full stretch at bottom, hold peak contraction" }
        if e.contains("hip thrust") { return "Drive through heels, squeeze glutes at top" }
        // Shoulders
        if e.contains("overhead press") || e.contains("shoulder press") || e.contains("military press") { return "Brace core, press straight up, don't flare elbows" }
        if e.contains("lateral raise") { return "Slight forward lean, lead with elbows, control weight" }
        if e.contains("face pull") { return "Pull to forehead, external rotate at end" }
        if e.contains("front raise") { return "Slight bend in elbows, stop at shoulder height" }
        if e.contains("shrug") { return "Straight up, hold at top, no rolling" }
        // Arms
        if e.contains("bicep curl") || e.contains("barbell curl") { return "Pin elbows to sides, full extension at bottom" }
        if e.contains("hammer curl") { return "Neutral grip, control both directions" }
        if e.contains("tricep") && e.contains("push") { return "Lock upper arms, full extension at bottom" }
        if e.contains("skull crusher") || e.contains("lying tricep") { return "Elbows pointed up, lower to forehead" }
        if e.contains("close grip") { return "Hands shoulder-width, elbows tucked" }
        // Core
        if e.contains("plank") { return "Flat back, engage glutes, breathe steady" }
        if e.contains("crunch") || e.contains("sit up") { return "Exhale on the way up, don't pull neck" }
        if e.contains("leg raise") && !e.contains("calf") { return "Press lower back into floor, slow descent" }
        if e.contains("cable woodchop") || e.contains("wood chop") { return "Rotate from hips, arms stay extended" }
        if e.contains("ab wheel") || e.contains("rollout") { return "Brace hard, don't let hips sag" }
        return nil
    }

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
