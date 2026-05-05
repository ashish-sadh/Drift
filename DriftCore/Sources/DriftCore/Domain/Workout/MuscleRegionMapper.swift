import Foundation

/// Canonical muscle regions used for body-map highlighting.
/// Each region maps to one or both sides of the body diagram.
public enum MuscleRegion: String, CaseIterable, Hashable, Sendable {
    case quadriceps, shoulders, abdominals, chest, hamstrings
    case triceps, biceps, middleBack, lats, calves
    case lowerBack, glutes, forearms, traps, adductors, abductors, neck

    public enum BodySide { case front, back, both }

    public var side: BodySide {
        switch self {
        case .quadriceps, .abdominals, .chest, .biceps, .forearms, .adductors:
            return .front
        case .hamstrings, .lats, .middleBack, .lowerBack, .glutes, .calves, .traps, .triceps, .abductors:
            return .back
        case .shoulders, .neck:
            return .both
        }
    }
}

/// Maps raw exercise `primaryMuscles`/`secondaryMuscles` strings → `MuscleRegion`.
/// All 17 muscle groups from exercises.json are covered; unknowns are silently skipped.
public enum MuscleRegionMapper {

    public static func regions(for muscles: [String]) -> Set<MuscleRegion> {
        Set(muscles.compactMap { region(for: $0) })
    }

    public static func region(for muscle: String) -> MuscleRegion? {
        switch muscle.lowercased() {
        case "quadriceps", "quads":           return .quadriceps
        case "shoulders", "deltoids", "delts": return .shoulders
        case "abdominals", "abs", "core":     return .abdominals
        case "chest", "pectorals", "pecs":    return .chest
        case "hamstrings":                    return .hamstrings
        case "triceps":                       return .triceps
        case "biceps":                        return .biceps
        case "middle back", "rhomboids":      return .middleBack
        case "lats", "latissimus dorsi":      return .lats
        case "calves":                        return .calves
        case "lower back", "erectors":        return .lowerBack
        case "glutes", "gluteus maximus":     return .glutes
        case "forearms":                      return .forearms
        case "traps", "trapezius":            return .traps
        case "adductors", "inner thigh":      return .adductors
        case "abductors", "outer thigh":      return .abductors
        case "neck":                          return .neck
        default:                              return nil
        }
    }
}
