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

    // MARK: - Portion Hint Parsing

    /// Parse a free-text correction hint into a portion multiplier.
    /// Returns nil when the hint isn't a recognizable size cue — callers
    /// should fall through to food-name DB matching in that case.
    ///
    /// Examples:
    ///   "half" / "half of it" / "1/2" → 0.5
    ///   "double" / "twice" / "2x"     → 2.0
    ///   "smaller portion"             → 0.5
    ///   "1.5x"                        → 1.5
    ///   "50%"                         → 0.5
    ///   "paratha"                     → nil  (food name, not a size cue)
    public static func parsePortionMultiplier(_ hint: String) -> Double? {
        let s = hint.lowercased()

        // Named fractions
        if s.contains("half") || s.contains("1/2") { return 0.5 }
        if s.contains("quarter") || s.contains("1/4") { return 0.25 }

        // Named multiples
        if s.contains("double") || s.contains("twice") || s.contains("2x") { return 2.0 }
        if s.contains("triple") || s.contains("3x") { return 3.0 }
        if s.contains("1.5x") { return 1.5 }

        // Vague size cues — map to nearest sensible fraction
        if s.contains("smaller") || s.contains("small portion") { return 0.5 }
        if s.contains("larger") || s.contains("bigger") { return 1.5 }

        // Percentage: "50%", "75%"
        let pctRegex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*%"#)
        if let match = pctRegex?.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
           let range = Range(match.range(at: 1), in: s),
           let pct = Double(s[range]) {
            return pct / 100.0
        }

        // Explicit "Nx" multiplier: "2.5x", "0.75x"
        let mulRegex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*x\b"#,
                                                options: .caseInsensitive)
        if let match = mulRegex?.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
           let range = Range(match.range(at: 1), in: s),
           let factor = Double(s[range]) {
            return factor
        }

        return nil
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
