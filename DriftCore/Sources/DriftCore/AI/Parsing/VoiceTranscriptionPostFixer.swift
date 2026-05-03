import Foundation

/// Post-processes final voice transcripts to repair common health-term misrecognitions
/// (metformin, creatine, whey, etc.) that Apple's speech recognizer frequently fumbles.
///
/// Two rule classes:
///   1. Unambiguous — apply unconditionally (word-bounded, case-insensitive).
///   2. Context-guarded — rewrite only when an adjacent disambiguator appears, so we
///      don't break innocent uses like "I'm creating a meal plan".
///
/// Only invoked on FINAL transcripts (not partials), so we can afford regex work
/// without UX flicker.
public enum VoiceTranscriptionPostFixer {

    /// Apply all rewrites. Idempotent: `fix(fix(x)) == fix(x)`.
    public static func fix(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var working = text
        for rule in unambiguousRules {
            working = rule.apply(to: working)
        }
        for rule in contextGuardedRules {
            working = rule.apply(to: working)
        }
        return working
    }

    // MARK: - Rules

    private struct Rule {
        let pattern: String
        let replacement: String
        let options: NSRegularExpression.Options

        init(_ pattern: String, _ replacement: String, options: NSRegularExpression.Options = [.caseInsensitive]) {
            self.pattern = pattern
            self.replacement = replacement
            self.options = options
        }

        func apply(to text: String) -> String {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
                return text
            }
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
        }
    }

    /// Unambiguous: these phrasings are almost never legitimate English prose.
    /// \b = word boundary; (?i) via options for case-insensitive.
    private static let unambiguousRules: [Rule] = [
        // Metformin — diabetes med. "Mutter in" / "muttering" / "met foreman" are classic misfires.
        Rule(#"\bmutter\s+in\b"#, "metformin"),
        Rule(#"\bmetro\s*form\s*in\b"#, "metformin"),
        Rule(#"\bmet\s+foreman\b"#, "metformin"),
        Rule(#"\bmet\s+form\s+in\b"#, "metformin"),

        // Ashwagandha — herbal adaptogen. Apple hears "ash wagon da".
        Rule(#"\bash\s*wagon\s*da\b"#, "ashwagandha"),
        Rule(#"\bash\s*wag\s*and\s*a\b"#, "ashwagandha"),
        Rule(#"\bashwa\s*ganda\b"#, "ashwagandha"),

        // Psyllium (fiber). "Sillium" / "silly um".
        Rule(#"\bsilly\s*um\b"#, "psyllium"),
        Rule(#"\bsillium\b"#, "psyllium"),

        // Glucosamine — joints.
        Rule(#"\bglue\s*cosa\s*mine\b"#, "glucosamine"),
        Rule(#"\bglucose\s+a\s*mean\b"#, "glucosamine"),

        // Melatonin — sleep.
        Rule(#"\bmela\s*toning\b"#, "melatonin"),
        Rule(#"\bmel\s+a\s+tonin\b"#, "melatonin"),

        // Turmeric — "too miric" / "tumor ick".
        Rule(#"\btumor\s*ick\b"#, "turmeric"),
        Rule(#"\btoo\s+miric\b"#, "turmeric"),

        // Berberine — glucose.
        Rule(#"\bbarber\s*een\b"#, "berberine"),
        Rule(#"\bburberry\b"#, "berberine"),

        // Lion's mane.
        Rule(#"\blions\s+main\b"#, "lion's mane"),
        Rule(#"\blion's\s+main\b"#, "lion's mane"),

        // Ozempic / Wegovy / Mounjaro.
        Rule(#"\bo\s*zen\s*pick\b"#, "ozempic"),
        Rule(#"\bwe\s+go\s+v\b"#, "wegovy"),
        Rule(#"\bmount\s*jarrow\b"#, "mounjaro"),

        // A1C — "a one see" / "a one c".
        Rule(#"\ba\s+one\s+(?:see|c)\b"#, "A1C"),

        // Triglycerides — "tri glycerides" / "three glycerides".
        Rule(#"\btri\s+glycerides\b"#, "triglycerides"),
        Rule(#"\bthree\s+glycerides\b"#, "triglycerides"),

        // LDL — "l d l" / "el dee el".
        Rule(#"\bl\s+d\s+l\b"#, "LDL"),
        Rule(#"\bel\s+dee\s+el\b"#, "LDL"),

        // HDL — "h d l" / "aich dee el".
        Rule(#"\bh\s+d\s+l\b"#, "HDL"),
        Rule(#"\baich\s+dee\s+el\b"#, "HDL"),

        // TSH (thyroid) — "t s h".
        Rule(#"\bt\s+s\s+h\b"#, "TSH"),

        // Ferritin — "fair tin" / "ferret in".
        Rule(#"\bfair\s*tin\b"#, "ferritin"),
        Rule(#"\bferret\s+in\b"#, "ferritin"),

        // B12 — "b twelve" / "bee 12".
        Rule(#"\bb\s+twelve\b"#, "B12"),
        Rule(#"\bbee\s+12\b"#, "B12"),

        // Cortisol — "cortex all" / "court is all".
        Rule(#"\bcortex\s+all\b"#, "cortisol"),
        Rule(#"\bcourt\s+is\s+all\b"#, "cortisol"),

        // Homocysteine — "homo scist ein" / "home o cysteine".
        Rule(#"\bhomo\s+scist\s+ein\b"#, "homocysteine"),
        Rule(#"\bhome\s+o\s+cysteine\b"#, "homocysteine"),

        // CRP (C-reactive protein) — "see reactive protein" / "c reactive protein".
        Rule(#"\bsee\s+reactive\s+protein\b"#, "CRP"),
        Rule(#"\bc\s+reactive\s+protein\b"#, "CRP"),
    ]

    /// Context-guarded: only rewrite when a disambiguator sits adjacent, so we don't
    /// clobber innocent phrases. Uses lookarounds so we don't consume the guard.
    /// Lookaheads/behinds are enabled by default in NSRegularExpression.
    private static let contextGuardedRules: [Rule] = [
        // Way protein → whey protein (only when "protein" follows within a few tokens).
        Rule(#"\bway(?=\s+(?:protein|powder|shake|isolate|concentrate))\b"#, "whey"),

        // Creating → creatine (only when supplement-context follows).
        // Guard on units/forms so "I'm creating a meal plan" stays untouched.
        Rule(#"\bcreating(?=\s+(?:\d+\s*(?:g|mg|grams)|powder|scoop|monohydrate|mono|supplement))\b"#, "creatine"),
        Rule(#"(?<=\btook\s)creating\b"#, "creatine"),
        Rule(#"(?<=\bhad\s)creating\b"#, "creatine"),

        // Case in → casein (only when "protein" follows).
        Rule(#"\bcase\s+in(?=\s+protein)\b"#, "casein"),

        // Colleague in → collagen (when peptide/powder/supplement follows).
        Rule(#"\bcolleague\s+in(?=\s+(?:peptide|powder|supplement))\b"#, "collagen"),

        // "Vitamin d three" → "vitamin d3" — only when dosage follows.
        Rule(#"\bvitamin\s+d\s+three(?=\s+\d)"#, "vitamin d3"),

        // "Omega three" → "omega-3" when supplement context ("fish oil", "capsule", dosage).
        Rule(#"\bomega\s+three(?=\s+(?:fish|oil|capsule|\d))"#, "omega-3"),
    ]
}
