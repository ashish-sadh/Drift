import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Public output type (available on all OS versions)

/// One workout entry extracted by the FM pipeline. Covers both strength
/// (sets / reps / weight) and cardio/mobility (durationMinutes) in a single
/// shape — same as the `@Generable WorkoutEntry` schema below. `category`
/// disambiguates downstream consumers that store strength + cardio
/// differently.
public struct FMWorkoutEntry: Sendable, Equatable {
    public enum Category: String, Sendable {
        case strength, cardio, mobility, sports
    }

    public let exerciseName: String
    public let sets: Int?
    public let reps: Int?
    public let weight: Double?
    public let durationMinutes: Int?
    public let category: Category

    public init(
        exerciseName: String,
        sets: Int? = nil,
        reps: Int? = nil,
        weight: Double? = nil,
        durationMinutes: Int? = nil,
        category: Category
    ) {
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.durationMinutes = durationMinutes
        self.category = category
    }
}

public enum FMWorkoutExtractorError: Error, Sendable {
    case unavailable
    case sessionFailed(String)
    case bounded(field: String, value: Double)
}

// MARK: - Bounds (design-666 sanity post-extraction)

public enum WorkoutBounds {
    public static let setsRange: ClosedRange<Int> = 1...20
    public static let repsRange: ClosedRange<Int> = 1...500   // includes time-based "reps" like seconds
    public static let weightLbsRange: ClosedRange<Double> = 0...1100   // 1100lbs ≈ 500kg
    public static let durationMinutesRange: ClosedRange<Int> = 1...600 // 10h ceiling

    /// Returns the first out-of-range field, or nil when every numeric is sane.
    /// Strength entries are evaluated on sets/reps/weight; cardio on durationMinutes.
    public static func violation(in e: FMWorkoutEntry) -> String? {
        switch e.category {
        case .strength:
            if let s = e.sets, !setsRange.contains(s) { return "sets" }
            if let r = e.reps, !repsRange.contains(r) { return "reps" }
            if let w = e.weight, !weightLbsRange.contains(w) { return "weight" }
        case .cardio, .mobility, .sports:
            if let d = e.durationMinutes, !durationMinutesRange.contains(d) { return "durationMinutes" }
        }
        return nil
    }
}

// MARK: - Extractor

public enum WorkoutEntryExtractor {

    /// Extract a single workout entry from a free-text user message.
    /// Throws `.unavailable` on iOS<26 / macOS<26 or when FoundationModels is
    /// not linked; throws `.bounded` on out-of-range numerics (caller falls
    /// back to regex). Multiple workouts per message → call with each
    /// comma-split segment, same as the regex path.
    public static func extract(text: String) async throws -> FMWorkoutEntry {
#if canImport(FoundationModels)
        if #available(macOS 26, iOS 26, *) {
            let prompt = buildPrompt(for: text)
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt, generating: FMWorkoutSchema.self)
                let entry = FMWorkoutEntry(
                    exerciseName: response.content.exerciseName,
                    sets: response.content.sets,
                    reps: response.content.reps,
                    weight: response.content.weight,
                    durationMinutes: response.content.durationMinutes,
                    category: FMWorkoutEntry.Category(rawValue: response.content.category.lowercased()) ?? .strength
                )
                if let bad = WorkoutBounds.violation(in: entry) {
                    let badVal: Double
                    switch bad {
                    case "sets": badVal = Double(entry.sets ?? 0)
                    case "reps": badVal = Double(entry.reps ?? 0)
                    case "weight": badVal = entry.weight ?? 0
                    case "durationMinutes": badVal = Double(entry.durationMinutes ?? 0)
                    default: badVal = .nan
                    }
                    throw FMWorkoutExtractorError.bounded(field: bad, value: badVal)
                }
                return entry
            } catch let err as FMWorkoutExtractorError {
                throw err
            } catch {
                throw FMWorkoutExtractorError.sessionFailed("\(error)")
            }
        }
#endif
        throw FMWorkoutExtractorError.unavailable
    }

    /// Prompt sent to the foundation model. Covers strength shorthand
    /// ("3x10", "3 sets of 10", "@135", "RPE 8"), cardio duration
    /// ("30 min yoga", "for half an hour", "ran 5k"), and category
    /// inference (strength/cardio/mobility/sports).
    public static func buildPrompt(for text: String) -> String {
        """
        Parse the user's workout description into a structured entry.

        Strength patterns: "3x10" = 3 sets of 10 reps; "3 sets of 10"; "@135" = 135 lbs; "at 60 kg" = ~132 lbs (convert to lbs); "RPE 8" = use given reps; "8-12 reps" = use the middle (10).

        Cardio/duration patterns: "30 min yoga"; "20 minutes cardio"; "for half an hour" = 30 minutes; "for an hour" = 60; "for like 45 minutes"; "ran 5k" = 5k run with no duration; "1h30m" = 90 minutes.

        Categorize:
        - strength = lifts/calisthenics with sets+reps (bench, squat, push-ups, deadlift)
        - cardio = aerobic with duration or distance (running, cycling, rowing, swim)
        - mobility = stretching, yoga, foam rolling
        - sports = soccer, basketball, climbing

        For bodyweight movements, leave weight nil. For cardio, leave sets/reps/weight nil. Use canonical exercise names (e.g. "bench press" not "bench"; "running" not "ran"). Weights should be in pounds — convert from kg by multiplying by 2.205 (rounded to nearest pound).

        Text:

        \(text)
        """
    }
}

// MARK: - Generable schema (compiled only on macOS 26+ / iOS 26+)

#if canImport(FoundationModels)
@available(macOS 26, iOS 26, *)
@Generable
struct FMWorkoutSchema: Sendable {
    @Guide(description: "Canonical exercise name, e.g. 'bench press' not 'bench', 'running' not 'ran'")
    let exerciseName: String
    @Guide(description: "Strength: number of sets. Nil for cardio/mobility/sports.")
    let sets: Int?
    @Guide(description: "Strength: reps per set; for ranges, use the middle value. Nil for cardio/mobility/sports.")
    let reps: Int?
    @Guide(description: "Strength: weight in POUNDS (convert kg×2.205 if needed); nil for bodyweight or cardio")
    let weight: Double?
    @Guide(description: "Cardio/mobility/sports: total duration in minutes; nil for strength sets")
    let durationMinutes: Int?
    @Guide(description: "Movement category: 'strength', 'cardio', 'mobility', or 'sports'")
    let category: String
}
#endif
