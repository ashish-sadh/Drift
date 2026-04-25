import Foundation

/// Accessors that decode `Food.ingredients` JSON into typed `RecipeItem` values.
extension Food {
    /// Parsed ingredient names. Handles both legacy ["name"] and new [{...}] formats.
    public var ingredientList: [String] {
        guard let json = ingredients, let data = json.data(using: .utf8) else { return [name] }
        // Try new format first (array of objects with "name" key)
        if let items = try? JSONDecoder().decode([RecipeItem].self, from: data) {
            let names = items.map(\.name)
            return names.isEmpty ? [name] : names
        }
        // Legacy format (array of strings)
        if let arr = try? JSONDecoder().decode([String].self, from: data) {
            return arr.isEmpty ? [name] : arr
        }
        return [name]
    }

    /// Full recipe items with per-ingredient macros. Returns nil for non-recipe or legacy format.
    public var recipeItems: [RecipeItem]? {
        guard let json = ingredients, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([RecipeItem].self, from: data)
    }
}
