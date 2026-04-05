import Foundation

enum WeightUnit: String, CaseIterable, Codable, Sendable {
    case kg
    case lbs

    var displayName: String {
        switch self {
        case .kg: "kg"
        case .lbs: "lbs"
        }
    }

    func convert(fromKg kg: Double) -> Double {
        switch self {
        case .kg: kg
        case .lbs: kg * 2.20462
        }
    }

    func convertToKg(_ value: Double) -> Double {
        switch self {
        case .kg: value
        case .lbs: value / 2.20462
        }
    }
}

enum Preferences {
    private static let weightUnitKey = "weight_unit"
    private static let cycleFertileWindowKey = "drift_cycle_fertile_window"

    static var weightUnit: WeightUnit {
        get {
            guard let raw = UserDefaults.standard.string(forKey: weightUnitKey),
                  let unit = WeightUnit(rawValue: raw) else {
                return .kg
            }
            return unit
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: weightUnitKey)
        }
    }

    static var cycleFertileWindow: Bool {
        get { UserDefaults.standard.bool(forKey: cycleFertileWindowKey) }
        set { UserDefaults.standard.set(newValue, forKey: cycleFertileWindowKey) }
    }

    private static let aiEnabledKey = "drift_ai_enabled"

    static var aiEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: aiEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: aiEnabledKey) }
    }
}
