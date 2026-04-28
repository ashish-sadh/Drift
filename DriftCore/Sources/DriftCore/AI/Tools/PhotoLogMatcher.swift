import Foundation

/// Post-recognition DB matching and category portion defaults for photo-logged foods.
/// Pure DriftCore logic — no UIKit, no cloud.
///
/// After the vision model returns a recognized food name, PhotoLogMatcher
/// runs a ranked local-DB lookup and applies sensible gram defaults by category
/// so the review row doesn't always default to 0g.
public enum PhotoLogMatcher {

    // MARK: - Thresholds

    /// Minimum word-overlap fraction to accept a DB match.
    /// 0.5 = at least half the query words appear in the DB name.
    public static let matchThreshold: Double = 0.5

    // MARK: - DB Matching

    /// Find the best local DB match for a vision-recognized food name.
    ///
    /// Uses ranked FTS search then checks word overlap to avoid accepting
    /// a spurious top-1 result (e.g. "oats" matching "oat bran muffin" for
    /// a query of "steel cut oats and almonds").
    ///
    /// - Parameters:
    ///   - recognizedName: Raw name string returned by the vision model.
    ///   - db: Database instance; defaults to the shared production DB.
    /// - Returns: Matching `Food` entry, or `nil` if no result exceeds the threshold.
    public static func matchFood(
        recognizedName: String,
        db: AppDatabase = AppDatabase.shared
    ) -> Food? {
        let results = (try? db.searchFoodsRanked(query: recognizedName)) ?? []
        guard let top = results.first else { return nil }
        return wordOverlap(recognizedName, top.name) >= matchThreshold ? top : nil
    }

    // MARK: - Portion Defaults

    /// Category-aware gram default when the vision model returned grams == 0.
    ///
    /// Ordered from most-specific (Indian Curries) to least-specific (default).
    /// Recognizes common name-level cues (smoothie, juice, chai) that may not
    /// be reflected in the DB category when the name didn't find a DB match.
    public static func portionDefault(category: String, recognizedName: String) -> Double {
        let cat = category.lowercased()
        let name = recognizedName.lowercased()

        if cat.contains("curr") || cat.contains("indian meal") || cat.contains("indian vegetarian") {
            return 200   // katori / bowl
        }
        if cat.contains("beverage") || cat.contains("drink") ||
           name.contains("smoothie") || name.contains("juice") ||
           name.contains("chai") || name.contains("lassi") || name.contains("shake") {
            return 250   // glass / large cup
        }
        if cat.contains("staple") || cat.contains("rice") || cat.contains("grain") {
            return 150   // standard bowl of rice or dal
        }
        if cat.contains("salad") {
            return 100   // side salad
        }
        if cat.contains("dessert") || cat.contains("sweet") || cat.contains("snack") {
            return 80    // serving piece / small portion
        }
        if cat.contains("protein") || cat.contains("meat") || cat.contains("chicken") ||
           cat.contains("seafood") || cat.contains("egg") {
            return 100   // one serving of protein
        }
        if cat.contains("fruit") || cat.contains("vegetable") {
            return 100
        }
        return 150   // sensible fallback for any unclassified food
    }

    // MARK: - Word Overlap (internal, exposed for testing)

    /// Fraction of words in `query` that appear in `candidate` (case-insensitive).
    /// Scores 1.0 when every query word is found; 0.0 when there is no overlap.
    static func wordOverlap(_ query: String, _ candidate: String) -> Double {
        let qWords = Set(query.lowercased().split(separator: " ").map(String.init).filter { !$0.isEmpty })
        let cWords = Set(candidate.lowercased().split(separator: " ").map(String.init).filter { !$0.isEmpty })
        guard !qWords.isEmpty else { return 0 }
        return Double(qWords.intersection(cWords).count) / Double(qWords.count)
    }
}
