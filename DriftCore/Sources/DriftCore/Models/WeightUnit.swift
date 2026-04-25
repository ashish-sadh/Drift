import Foundation

public enum WeightUnit: String, CaseIterable, Codable, Sendable {
    case kg
    case lbs

    public var displayName: String {
        switch self {
        case .kg: "kg"
        case .lbs: "lbs"
        }
    }

    public func convert(fromKg kg: Double) -> Double {
        switch self {
        case .kg: kg
        case .lbs: kg * 2.20462
        }
    }

    public func convertToKg(_ value: Double) -> Double {
        switch self {
        case .kg: value
        case .lbs: value / 2.20462
        }
    }

    /// Convert exercise weight from storage (lbs) to display unit
    public func convertFromLbs(_ lbs: Double) -> Double {
        switch self {
        case .lbs: lbs
        case .kg: lbs / 2.20462
        }
    }

    /// Convert exercise weight from user input to storage (lbs)
    public func convertToLbs(_ value: Double) -> Double {
        switch self {
        case .lbs: value
        case .kg: value * 2.20462
        }
    }
}
