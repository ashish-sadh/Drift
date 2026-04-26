import Foundation

/// Parsed food-logging intent: a food query plus optional quantity hints.
/// Lives in Models so both AI parsing (where it's produced) and Domain
/// parsing (where ComposedFoodParser also produces it) can share the type
/// without one layer depending on the other.
public struct FoodIntent: Sendable {
    public let query: String
    public let servings: Double?
    public var mealHint: String? = nil
    public var gramAmount: Double? = nil

    public init(query: String, servings: Double?, mealHint: String? = nil, gramAmount: Double? = nil) {
        self.query = query
        self.servings = servings
        self.mealHint = mealHint
        self.gramAmount = gramAmount
    }
}
