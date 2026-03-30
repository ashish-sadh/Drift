import Foundation

/// Static definition of a biomarker from the knowledge base.
struct BiomarkerDefinition: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let category: String
    let unit: String
    let optimalLow: Double
    let optimalHigh: Double
    let sufficientLow: Double
    let sufficientHigh: Double
    let absoluteLow: Double
    let absoluteHigh: Double
    let description: String
    let whyItMatters: String
    let relationships: String
    let howToImprove: String
    let healthMetrics: String
    let impactCategories: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, category, unit, description, relationships
        case optimalLow = "optimal_low"
        case optimalHigh = "optimal_high"
        case sufficientLow = "sufficient_low"
        case sufficientHigh = "sufficient_high"
        case absoluteLow = "absolute_low"
        case absoluteHigh = "absolute_high"
        case whyItMatters = "why_it_matters"
        case howToImprove = "how_to_improve"
        case healthMetrics = "health_metrics"
        case impactCategories = "impact_categories"
    }

    /// Determine status for a given value.
    func status(for value: Double) -> BiomarkerStatus {
        if value >= optimalLow && value <= optimalHigh {
            return .optimal
        } else if value >= sufficientLow && value <= sufficientHigh {
            return .sufficient
        } else {
            return .outOfRange
        }
    }

    /// Normalized position (0...1) of a value within the absolute range, clamped.
    func normalizedPosition(for value: Double) -> Double {
        guard absoluteHigh > absoluteLow else { return 0.5 }
        return min(1, max(0, (value - absoluteLow) / (absoluteHigh - absoluteLow)))
    }
}

/// Status classification for a biomarker reading.
enum BiomarkerStatus: String, Codable, Sendable, CaseIterable {
    case optimal
    case sufficient
    case outOfRange

    var label: String {
        switch self {
        case .optimal: "Optimal"
        case .sufficient: "Sufficient"
        case .outOfRange: "Out of Range"
        }
    }

    var iconName: String {
        switch self {
        case .optimal: "checkmark.circle.fill"
        case .sufficient: "circle.fill"
        case .outOfRange: "exclamationmark.triangle.fill"
        }
    }
}
