import Foundation
import GRDB

struct FoodEntry: Identifiable, Codable, Sendable {
    var id: Int64?
    var mealLogId: Int64
    var foodId: Int64?        // nil if quick-add
    var foodName: String
    var servingSizeG: Double
    var servings: Double
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, servings, calories
        case mealLogId = "meal_log_id"
        case foodId = "food_id"
        case foodName = "food_name"
        case servingSizeG = "serving_size_g"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case createdAt = "created_at"
    }

    init(
        id: Int64? = nil,
        mealLogId: Int64,
        foodId: Int64? = nil,
        foodName: String,
        servingSizeG: Double,
        servings: Double = 1.0,
        calories: Double,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        fiberG: Double = 0,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.mealLogId = mealLogId
        self.foodId = foodId
        self.foodName = foodName
        self.servingSizeG = servingSizeG
        self.servings = servings
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.createdAt = createdAt
    }

    /// Total calories for this entry (per-serving * servings).
    var totalCalories: Double { calories * servings }
    var totalProtein: Double { proteinG * servings }
    var totalCarbs: Double { carbsG * servings }
    var totalFat: Double { fatG * servings }
    var totalFiber: Double { fiberG * servings }
}

extension FoodEntry: FetchableRecord, PersistableRecord {
    static let databaseTableName = "food_entry"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
