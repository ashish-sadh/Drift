import Foundation
import DriftCore

/// SwiftUI-coupled accessors for Food. The data part of Food lives in DriftCore;
/// these accessors reference QuickAddView.RecipeItem (a SwiftUI-nested type) and
/// stay in the iOS app target.
extension Food {
    /// Parsed ingredient names. Handles both legacy ["name"] and new [{...}] formats.
    var ingredientList: [String] {
        guard let json = ingredients, let data = json.data(using: .utf8) else { return [name] }
        // Try new format first (array of objects with "name" key)
        if let items = try? JSONDecoder().decode([QuickAddView.RecipeItem].self, from: data) {
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
    var recipeItems: [QuickAddView.RecipeItem]? {
        guard let json = ingredients, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([QuickAddView.RecipeItem].self, from: data)
    }
}
