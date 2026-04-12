import Foundation

/// Spell correction using food DB names + hardcoded fallback.
/// Corrects user input before passing to LLM or food search.
enum SpellCorrectService {

    /// Cached food names from DB for fuzzy matching
    nonisolated(unsafe) private static var foodNames: [String] = {
        // Load food names from the bundled DB at startup
        guard let url = Bundle.main.url(forResource: "foods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let foods = try? JSONDecoder().decode([[String: AnyCodable]].self, from: data) else {
            return []
        }
        return foods.compactMap { $0["name"]?.value as? String }.map { $0.lowercased() }
    }()

    /// Curated corrections (edit distance can't catch these well)
    private static let hardcoded: [String: String] = [
        // Proteins
        "chiken": "chicken", "chickin": "chicken", "chikken": "chicken", "chickn": "chicken",
        "salman": "salmon", "samon": "salmon",
        "shrimp": "shrimp", "shirmp": "shrimp",
        "turky": "turkey", "terkey": "turkey",
        "steak": "steak", "staek": "steak",
        // Fruits & vegetables
        "bananaa": "banana", "bananna": "banana",
        "brocoli": "broccoli", "brocolli": "broccoli",
        "avacado": "avocado", "avocadao": "avocado",
        "tomatoe": "tomato", "potatoe": "potato", "potatos": "potatoes",
        "strawbery": "strawberry", "blubery": "blueberry", "bluberry": "blueberry",
        "rasberry": "raspberry", "raspbery": "raspberry",
        "spinich": "spinach", "spinnach": "spinach",
        "lettuse": "lettuce", "letuce": "lettuce",
        "oinon": "onion", "onin": "onion",
        "cumcumber": "cucumber", "cucmber": "cucumber",
        // Dairy
        "yoghurt": "yogurt", "yougurt": "yogurt", "yogart": "yogurt",
        "chese": "cheese", "cheeze": "cheese",
        "buuter": "butter", "buter": "butter",
        // Grains & staples
        "oatmeel": "oatmeal", "oatemeal": "oatmeal",
        "spagetti": "spaghetti", "spagehtti": "spaghetti", "spaghetii": "spaghetti",
        "sandwhich": "sandwich", "sandwitch": "sandwich", "sanwich": "sandwich",
        "piza": "pizza", "pizzza": "pizza",
        "tortila": "tortilla", "tortilia": "tortilla",
        "quinoa": "quinoa", "quinoah": "quinoa",
        // Indian foods
        "panner": "paneer", "panneer": "paneer", "panir": "paneer",
        "samossa": "samosa", "somosa": "samosa",
        "chappati": "chapati", "chappathi": "chapati", "chapatti": "chapati",
        "biryanni": "biryani", "biriyani": "biryani", "bryani": "biryani",
        "daal": "dal", "dhal": "dal",
        "nann": "naan", "nan": "naan",
        "roti": "roti", "rotii": "roti",
        "idly": "idli", "iddli": "idli",
        "dosai": "dosa",
        "gulab": "gulab", "jamun": "jamun",
        // Beverages
        "coffe": "coffee", "cofee": "coffee", "coffie": "coffee",
        "smoothy": "smoothie", "smothie": "smoothie",
        "expresso": "espresso",
        // Nutrition terms
        "protien": "protein", "proteen": "protein", "protine": "protein",
        "calries": "calories", "calroies": "calories", "caloris": "calories",
        "carbohidrate": "carbohydrate", "carbohdyrate": "carbohydrate",
        // Meals
        "breakfest": "breakfast", "brekfast": "breakfast", "brekfest": "breakfast",
        // Exercise
        "excercise": "exercise", "exercize": "exercise",
        "benchpress": "bench press",
        "deadlfit": "deadlift", "dedlift": "deadlift",
        "wieght": "weight", "weigth": "weight",
        "squatt": "squat", "sqaut": "squat",
    ]

    /// Correct spelling. Checks hardcoded first, then fuzzy-matches against food DB.
    static func correct(_ text: String) -> String {
        let words = text.components(separatedBy: " ")
        var result: [String] = []
        var changed = false

        for word in words {
            let lower = word.lowercased()

            // Hardcoded corrections first
            if let fix = hardcoded[lower] {
                result.append(fix)
                changed = true
                continue
            }

            // Skip short words and common English words
            if lower.count < 4 || commonWords.contains(lower) {
                result.append(word)
                continue
            }

            // Skip if word is already a known food word
            if isKnownFoodWord(lower) {
                result.append(word)
                continue
            }

            // Fuzzy match against food DB names (edit distance 1)
            if let match = closestFoodWord(lower) {
                result.append(match)
                changed = true
            } else {
                result.append(word)
            }
        }

        return changed ? result.joined(separator: " ") : text
    }

    /// Check if a word is already a known food word (exact match in DB).
    private static func isKnownFoodWord(_ word: String) -> Bool {
        foodNames.contains(where: { name in
            name.split(separator: " ").contains(where: { String($0).filter(\.isLetter) == word })
        })
    }

    /// Find the closest food name word within edit distance 1.
    private static func closestFoodWord(_ word: String) -> String? {
        // Check against individual words from food names
        var best: (word: String, distance: Int)?
        for name in foodNames {
            let nameWords = name.split(separator: " ").map { String($0).filter(\.isLetter) }
            for nameWord in nameWords {
                guard nameWord.count >= 4 else { continue }
                let dist = editDistance(word, nameWord)
                if dist == 1 && dist < (best?.distance ?? Int.max) {
                    best = (nameWord, dist)
                }
            }
        }
        return best?.word
    }

    /// Levenshtein edit distance between two strings.
    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        let m = a.count, n = b.count
        if m == 0 { return n }
        if n == 0 { return m }

        var dp = Array(0...n)
        for i in 1...m {
            var prev = dp[0]
            dp[0] = i
            for j in 1...n {
                let temp = dp[j]
                dp[j] = a[i-1] == b[j-1] ? prev : min(prev, dp[j], dp[j-1]) + 1
                prev = temp
            }
        }
        return dp[n]
    }

    /// Common English words to skip (not food/exercise terms)
    private static let commonWords: Set<String> = [
        "the", "and", "for", "with", "from", "that", "this", "have", "had",
        "just", "some", "about", "what", "when", "how", "much", "many",
        "today", "yesterday", "calories", "protein", "carbs", "should",
        "log", "ate", "had", "add", "track", "eating", "drank", "made",
    ]
}

/// Helper for JSON decoding with any type
private struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { value = s }
        else if let d = try? container.decode(Double.self) { value = d }
        else if let b = try? container.decode(Bool.self) { value = b }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let s = value as? String { try container.encode(s) }
        else if let d = value as? Double { try container.encode(d) }
    }
}
