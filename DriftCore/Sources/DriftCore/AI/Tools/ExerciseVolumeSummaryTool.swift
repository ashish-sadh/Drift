import Foundation
import DriftCore

@MainActor
public enum ExerciseVolumeSummaryTool {

    nonisolated static let toolName = "exercise_volume_summary"

    static func syncRegistration(registry: ToolRegistry = .shared) {
        registry.register(schema)
    }

    static var schema: ToolSchema {
        ToolSchema(
            id: "insights.exercise_volume_summary",
            name: toolName,
            service: "insights",
            description: "User asks about training volume, sets per muscle group, or whether they're undertrained — e.g. 'how's my training volume this week?', 'how many sets did I do for legs?', 'am I undertrained anywhere?', 'muscle group coverage'.",
            parameters: [
                ToolParam("window_days", "number", "Lookback window in days (default 7)", required: false)
            ],
            handler: { params in
                let window = max(1, min(30, params.int("window_days") ?? 7))
                return .text(run(windowDays: window))
            }
        )
    }

    // MARK: - Entry point

    public static func run(windowDays: Int = 7) -> String {
        let allWorkouts = (try? WorkoutService.fetchWorkouts(limit: 500)) ?? []
        let cutoff = cutoffDateString(windowDays: windowDays)
        let windowWorkouts = allWorkouts.filter { $0.date >= cutoff }

        guard !windowWorkouts.isEmpty else {
            return "No workouts logged in the last \(windowDays) day\(windowDays == 1 ? "" : "s")."
        }

        var workingSets: [WorkoutSet] = []
        for workout in windowWorkouts {
            guard let id = workout.id else { continue }
            let sets = (try? WorkoutService.fetchSets(forWorkout: id)) ?? []
            workingSets.append(contentsOf: sets.filter { !$0.isWarmup })
        }

        guard !workingSets.isEmpty else {
            return "No working sets found in the last \(windowDays) days."
        }

        let setsByGroup = groupSetsByMuscle(workingSets)
        return formatResult(setsByGroup: setsByGroup, windowDays: windowDays, workoutCount: windowWorkouts.count)
    }

    // MARK: - Pure logic (testable)

    nonisolated public static let minimumSetsPerGroup: [String: Int] = [
        "Chest": 10, "Back": 10, "Legs": 10, "Shoulders": 10,
        "Arms": 6, "Core": 6,
    ]

    nonisolated static let majorGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]

    nonisolated public static func groupSetsByMuscle(_ sets: [WorkoutSet]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for set in sets {
            let group = ExerciseDatabase.bodyPart(for: set.exerciseName)
            counts[group, default: 0] += 1
        }
        return counts
    }

    nonisolated public static func formatResult(
        setsByGroup: [String: Int],
        windowDays: Int,
        workoutCount: Int
    ) -> String {
        let dayLabel = windowDays == 7 ? "week" : "\(windowDays) days"
        var lines: [String] = [
            "Training volume (\(dayLabel), \(workoutCount) workout\(workoutCount == 1 ? "" : "s")):"
        ]

        for group in majorGroups {
            let count = setsByGroup[group] ?? 0
            let min = minimumSetsPerGroup[group] ?? 10
            let tag: String
            if count == 0         { tag = "none" }
            else if count < min   { tag = "\(count) sets (min \(min))" }
            else                  { tag = "\(count) sets ✓" }
            lines.append("  \(group): \(tag)")
        }

        // Any non-major groups (e.g. "Full Body")
        let extras = setsByGroup.keys.filter { !majorGroups.contains($0) }.sorted()
        for group in extras {
            lines.append("  \(group): \(setsByGroup[group] ?? 0) sets")
        }

        // Identify most undertrained major group
        let under = majorGroups
            .filter { (setsByGroup[$0] ?? 0) < (minimumSetsPerGroup[$0] ?? 10) }
            .sorted { (setsByGroup[$0] ?? 0) < (setsByGroup[$1] ?? 0) }

        if let weakest = under.first {
            let count = setsByGroup[weakest] ?? 0
            let min = minimumSetsPerGroup[weakest] ?? 10
            lines.append("Most undertrained: \(weakest) (\(count)/\(min) sets) — add more \(weakest.lowercased()) work.")
        } else {
            lines.append("All major groups at or above minimum volume.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Date helper

    /// Returns "yyyy-MM-dd" for `windowDays` ago (string-comparable to Workout.date).
    nonisolated static func cutoffDateString(windowDays: Int, now: Date = Date()) -> String {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -(windowDays - 1), to: now) ?? now
        return DateFormatters.dateOnly.string(from: cutoff)
    }
}
