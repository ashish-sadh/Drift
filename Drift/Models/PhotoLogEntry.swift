import Foundation

/// Mutable editing state for a single `PhotoLogItem` in the review sheet.
/// Users can check/uncheck items and tweak the grams before logging. Calories
/// and macros scale linearly with grams so the summary stays accurate during
/// edits. Separate from `PhotoLogItem` (which is decode-only) so we can keep
/// the wire format immutable. #224 / #267.
struct PhotoLogEditableItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    var grams: Double
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var confidence: Confidence
    var selected: Bool

    /// Original per-gram rates cached on init. All edit scaling is against
    /// these so repeated grams edits don't drift via rounding.
    let caloriesPerGram: Double
    let proteinPerGram: Double
    let carbsPerGram: Double
    let fatPerGram: Double

    init(from item: PhotoLogItem, id: UUID = UUID()) {
        self.id = id
        self.name = item.name
        self.grams = max(item.grams, 0)
        self.calories = max(item.calories, 0)
        self.proteinG = max(item.proteinG, 0)
        self.carbsG = max(item.carbsG, 0)
        self.fatG = max(item.fatG, 0)
        self.confidence = item.confidence
        self.selected = true
        if self.grams > 0 {
            self.caloriesPerGram = self.calories / self.grams
            self.proteinPerGram = self.proteinG / self.grams
            self.carbsPerGram = self.carbsG / self.grams
            self.fatPerGram = self.fatG / self.grams
        } else {
            self.caloriesPerGram = 0
            self.proteinPerGram = 0
            self.carbsPerGram = 0
            self.fatPerGram = 0
        }
    }

    /// Re-derive calories+macros after `grams` is edited. Callers mutate
    /// `grams` then invoke this to keep the per-row totals consistent.
    mutating func rescale() {
        let g = max(grams, 0)
        grams = g
        calories = caloriesPerGram * g
        proteinG = proteinPerGram * g
        carbsG = carbsPerGram * g
        fatG = fatPerGram * g
    }
}

/// UI phases of the Photo Log flow. A single `@State` holds this so the
/// capture/review sheet can swap layouts without nested sheets. #224 / #267.
enum PhotoLogViewState: Equatable {
    case capture                            // pick photo OR take one
    case analyzing                          // in-flight API call
    case review([PhotoLogEditableItem], Confidence, String?)  // items, overall, notes
    case empty                              // 0 items returned
    case error(String)                      // user-visible message
}

/// Summed macro totals across the currently-selected items. Pure helper so
/// the review view can re-render on check/uncheck without re-running UI code.
struct PhotoLogTotals: Equatable {
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int
    var selectedCount: Int

    static let zero = PhotoLogTotals(calories: 0, proteinG: 0, carbsG: 0, fatG: 0, selectedCount: 0)

    static func sum(_ items: [PhotoLogEditableItem]) -> PhotoLogTotals {
        var totals = PhotoLogTotals.zero
        for item in items where item.selected {
            totals.calories += Int(item.calories.rounded())
            totals.proteinG += Int(item.proteinG.rounded())
            totals.carbsG += Int(item.carbsG.rounded())
            totals.fatG += Int(item.fatG.rounded())
            totals.selectedCount += 1
        }
        return totals
    }
}
