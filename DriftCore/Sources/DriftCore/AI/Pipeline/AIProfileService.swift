import Foundation

/// Builds a ≤200-token user profile preamble for AI prompt injection.
/// Combines explicit user-stated preferences (stored in UserAIProfile) with
/// cuisine patterns derived from food logs and active medications from logs.
/// All data stays on-device.
public enum AIProfileService {

    static let dietaryKeywords: [String] = [
        "vegetarian", "vegan", "keto", "carnivore", "gluten-free",
        "dairy-free", "lactose intolerant", "halal", "kosher", "paleo", "pescatarian"
    ]

    static let medicationKeywords: [String: String] = [
        "glp-1": "GLP-1", "glp1": "GLP-1",
        "ozempic": "GLP-1", "wegovy": "GLP-1", "semaglutide": "GLP-1",
        "mounjaro": "GLP-1", "zepbound": "GLP-1", "tirzepatide": "GLP-1",
        "metformin": "metformin", "insulin": "insulin"
    ]

    private static let genericCategories: Set<String> = [
        "other", "protein", "general", "misc", "miscellaneous"
    ]

    // MARK: - Derived data from live logs

    /// Top food categories by log frequency in the last 60 foods.
    @MainActor
    public static func topCuisines(limit: Int = 3) -> [String] {
        let recents = FoodService.fetchRecentFoods(limit: 60)
        var counts: [String: Int] = [:]
        for food in recents {
            let cat = food.category.trimmingCharacters(in: .whitespaces)
            guard !cat.isEmpty, !genericCategories.contains(cat.lowercased()) else { continue }
            counts[cat, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.prefix(limit).map(\.key)
    }

    /// Medications logged consistently in the last 30 days.
    @MainActor
    public static func activeMedications() -> [String] {
        MedicationService.consistentMedicationNames(days: 30)
    }

    // MARK: - Explicit preference extraction

    /// Scan a chat message for dietary / medication keywords and return
    /// any preference tags found (e.g. "vegetarian", "GLP-1").
    public static func extractPreferences(from text: String) -> [String] {
        let lower = text.lowercased()
        var found: [String] = []
        for keyword in dietaryKeywords where lower.contains(keyword) {
            found.append(keyword)
        }
        var seenLabels = Set<String>()
        for (keyword, label) in medicationKeywords where lower.contains(keyword) {
            if seenLabels.insert(label).inserted { found.append(label) }
        }
        return found
    }

    /// Merge any newly detected preferences from `chatText` into the persisted profile.
    @MainActor
    public static func updateProfile(from chatText: String) {
        let found = extractPreferences(from: chatText)
        guard !found.isEmpty else { return }
        var profile = UserAIProfile.load()
        let existing = Set(profile.explicitPreferences)
        let new = found.filter { !existing.contains($0) }
        guard !new.isEmpty else { return }
        profile.explicitPreferences = Array(existing.union(new)).sorted()
        profile.updatedAt = Date()
        UserAIProfile.save(profile)
    }

    // MARK: - Prompt preamble

    /// Returns a compact profile line for system-prompt injection, or nil if
    /// there is nothing meaningful to inject yet.
    /// Example: "User profile: vegetarian, logs Indian/South Indian food, on GLP-1"
    @MainActor
    public static func buildSummary() -> String? {
        let profile = UserAIProfile.load()
        let cuisines = topCuisines()
        let meds = activeMedications()

        var parts: [String] = []
        if !profile.explicitPreferences.isEmpty {
            parts.append(profile.explicitPreferences.joined(separator: ", "))
        }
        if !cuisines.isEmpty {
            parts.append("logs \(cuisines.joined(separator: "/")) food")
        }
        if !meds.isEmpty {
            let labels = Set(meds.prefix(3).map { name -> String in
                let lower = name.lowercased()
                for (keyword, label) in medicationKeywords where lower.contains(keyword) {
                    return label
                }
                return name
            })
            parts.append("on \(labels.sorted().joined(separator: ", "))")
        }

        guard !parts.isEmpty else { return nil }
        return String("User profile: \(parts.joined(separator: ", "))".prefix(300))
    }
}
