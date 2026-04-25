import Foundation

/// All screens the AI can be aware of.
public enum AIScreen: String, Sendable {
    case dashboard, weight, food, exercise
    case bodyRhythm, cycle, supplements, bodyComposition, glucose, biomarkers
    case goal, settings, algorithm
}
