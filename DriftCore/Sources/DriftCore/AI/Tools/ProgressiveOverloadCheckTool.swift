import Foundation

@MainActor
public enum ProgressiveOverloadCheckTool {

    nonisolated static let toolName = "progressive_overload_check"

    static func syncRegistration(registry: ToolRegistry = .shared) {
        registry.register(schema)
    }

    static var schema: ToolSchema {
        ToolSchema(
            id: "insights.progressive_overload_check",
            name: toolName,
            service: "insights",
            description: "User asks about exercise plateaus, progressive overload, or which lifts are stalling — e.g. 'am I plateauing on bench?', 'which exercises am I stuck on?', 'progressive overload check', 'my squat isn't going up', 'what should I change in my workout?'.",
            parameters: [
                ToolParam("exercise", "string", "Specific exercise name to check (omit to check all exercises)", required: false)
            ],
            handler: { params in
                let exercise = params.string("exercise")
                return .text(run(exercise: exercise))
            }
        )
    }

    // MARK: - Entry point

    public static func run(exercise: String? = nil) -> String {
        if let name = exercise, !name.isEmpty {
            let result = ProgressiveOverloadService.checkPlateau(exercise: name)
            return formatSingle(result)
        }
        let plateaus = ProgressiveOverloadService.allPlateaus(respectDismissed: false)
        return formatAll(plateaus)
    }

    // MARK: - Formatting

    nonisolated public static func formatSingle(_ result: PlateauResult) -> String {
        if !result.isOnPlateau {
            let sessionsNote: String
            if result.sessionsChecked < 3 {
                let s = result.sessionsChecked == 1 ? "" : "s"
                sessionsNote = " (only \(result.sessionsChecked) session\(s) logged — need 3+ to assess)"
            } else {
                sessionsNote = ""
            }
            return "No plateau detected for \(result.exercise)\(sessionsNote). Keep progressing!"
        }
        return result.summary
    }

    nonisolated public static func formatAll(_ plateaus: [PlateauResult]) -> String {
        guard !plateaus.isEmpty else {
            return "No plateaus detected — you're progressing on all tracked exercises!"
        }
        let header = plateaus.count == 1
            ? "1 exercise on plateau:"
            : "\(plateaus.count) exercises on plateau:"
        let lines = plateaus.map { "• \($0.summary)" }
        return ([header] + lines).joined(separator: "\n")
    }
}
