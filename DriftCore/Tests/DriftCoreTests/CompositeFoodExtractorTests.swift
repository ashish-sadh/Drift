import Foundation
@testable import DriftCore
import Testing

// Tier-0 tests for design-666 QW2 unified composite-food extractor.
// Pure helpers only — bounds + prompt + flag default + sync-path regex
// equivalence + 30-query gold set. The FM-backed Tier-3 gold set lives in
// DriftLLMEvalMacOS (when the eval target catches up to composite fixtures).

// MARK: - CompositeFoodBounds — hallucination guard

@Test func compositeBounds_twoComponentsOK() {
    let e = FMCompositeFoodEntry(components: [
        .init(foodName: "coffee", isMain: true),
        .init(foodName: "milk", isMain: false),
    ])
    #expect(CompositeFoodBounds.violation(in: e) == nil)
}

@Test func compositeBounds_thaliCeilingOK() {
    // 8 components is the realistic ceiling — a thali. Should pass.
    let e = FMCompositeFoodEntry(components: (0..<8).map {
        .init(foodName: "item\($0)", isMain: $0 == 0)
    })
    #expect(CompositeFoodBounds.violation(in: e) == nil)
}

@Test func compositeBounds_singleComponentNotComposite() {
    let e = FMCompositeFoodEntry(components: [.init(foodName: "biryani", isMain: true)])
    #expect(CompositeFoodBounds.violation(in: e) == .notComposite)
}

@Test func compositeBounds_emptyNotComposite() {
    let e = FMCompositeFoodEntry(components: [])
    #expect(CompositeFoodBounds.violation(in: e) == .notComposite)
}

@Test func compositeBounds_rejectIngredientHallucination() {
    // FM splitting "chicken biryani" into 9+ ingredient words = hallucination.
    let e = FMCompositeFoodEntry(components: (0..<9).map {
        .init(foodName: "ingredient\($0)", isMain: $0 == 0)
    })
    #expect(CompositeFoodBounds.violation(in: e) == .tooMany(9))
}

// MARK: - Feature flag default (serialized — both tests touch one UserDefaults key)

@Suite(.serialized) struct CompositeFoodFlagBehavior {
    private let key = "drift_fm_composite_food_extract"

    @Test func defaultsAndPersistence() {
        defer { UserDefaults.standard.removeObject(forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        #expect(Preferences.fmCompositeFoodExtractEnabled == true,
                "Per design-666 QW2 the FM composite-food path defaults ON")

        Preferences.fmCompositeFoodExtractEnabled = false
        #expect(Preferences.fmCompositeFoodExtractEnabled == false)
        Preferences.fmCompositeFoodExtractEnabled = true
        #expect(Preferences.fmCompositeFoodExtractEnabled == true)
    }

    @Test func asyncParse_flagOffMatchesSync() async {
        defer { UserDefaults.standard.removeObject(forKey: key) }
        Preferences.fmCompositeFoodExtractEnabled = false
        let input = "log coffee with milk"
        let asyncIntents = await ComposedFoodParser.parseAsync(input)
        let syncIntents = ComposedFoodParser.parse(input)
        #expect(asyncIntents?.map(\.query) == syncIntents?.map(\.query),
                "Flag-off async path must match sync regex output exactly")
    }

    @Test func asyncParse_flagOffMatchesSync_allGoldRows() async {
        // Exhaustive flag-off equivalence: every gold-set row must round-trip
        // identically through parseAsync vs parse. Pins the kill-switch
        // guarantee: when fmCompositeFoodExtractEnabled is false, the async
        // path is byte-for-byte the sync regex with zero FM influence.
        defer { UserDefaults.standard.removeObject(forKey: key) }
        Preferences.fmCompositeFoodExtractEnabled = false
        for row in compositeGoldSet {
            let asyncIntents = await ComposedFoodParser.parseAsync(row.input)
            let syncIntents = ComposedFoodParser.parse(row.input)
            #expect(asyncIntents?.map(\.query) == syncIntents?.map(\.query),
                    "Flag-off divergence on '\(row.input)' — async=\(asyncIntents?.map(\.query) ?? []), sync=\(syncIntents?.map(\.query) ?? [])")
        }
    }
}

// MARK: - Prompt anchoring

@Test func compositePromptCoversIndianComposites() {
    let p = CompositeFoodExtractor.buildPrompt(for: "any").lowercased()
    #expect(p.contains("biryani"))
    #expect(p.contains("dal chawal") || p.contains("idli sambar"),
            "Indian-food bar means the prompt must show at least one bare-juxtaposition example")
}

@Test func compositePromptCoversConnectorVariety() {
    let p = CompositeFoodExtractor.buildPrompt(for: "any").lowercased()
    #expect(p.contains("with"))
    #expect(p.contains("served with") || p.contains("topped with"),
            "Prompt must cover regional / verb-ending connectors the regex misses")
}

@Test func compositePromptIncludesTheInputText() {
    let unique = "MARKER_\(UUID().uuidString.prefix(8))"
    let p = CompositeFoodExtractor.buildPrompt(for: unique)
    #expect(p.contains(unique))
}

@Test func compositePromptAsksForOneMainItem() {
    let p = CompositeFoodExtractor.buildPrompt(for: "any").lowercased()
    #expect(p.contains("main"))
    #expect(p.contains("ismain"))
}

@Test func compositePromptForbidsIngredientSplit() {
    // Without this guard the model splits "chicken biryani" into [chicken, biryani] —
    // would explode the meal into garbage. The prompt must forbid it explicitly.
    let p = CompositeFoodExtractor.buildPrompt(for: "any").lowercased()
    #expect(p.contains("chicken biryani"))
    #expect(p.contains("not"))
}

@Test func compositePromptPreservesQuantities() {
    // Downstream parses "100ml milk" → gramAmount=100. Prompt must tell the
    // model to keep quantities verbatim instead of normalizing them away.
    let p = CompositeFoodExtractor.buildPrompt(for: "any").lowercased()
    #expect(p.contains("verbatim") || p.contains("preserve"))
}

// MARK: - Gold set — 30 composite-food queries (design-666 QW2 deliverable)

/// `target` = what the FM extractor should return (specification).
/// `regexBaseline` = what the current sync regex returns today:
///   - `.match([...])` → regex matches and equals `target` (no FM win on this row, but useful coverage)
///   - `.wrong([...])` → regex returns *something* but it differs from `target` (FM win: correctness)
///   - `.miss`        → regex returns nil (FM win: coverage)
private enum RegexBaseline: Equatable {
    case match([String])
    case wrong([String])
    case miss
}

private struct CompositeRow {
    let input: String
    let target: [String]
    let regexBaseline: RegexBaseline
}

private let compositeGoldSet: [CompositeRow] = [
    // 1-12: with/plus/alongside/served-with — covered correctly by current regex
    .init(input: "coffee with milk",            target: ["coffee", "milk"],            regexBaseline: .match(["coffee", "milk"])),
    .init(input: "oatmeal with honey",          target: ["oatmeal", "honey"],          regexBaseline: .match(["oatmeal", "honey"])),
    .init(input: "toast with butter",           target: ["toast", "butter"],           regexBaseline: .match(["toast", "butter"])),
    .init(input: "rice with dal",               target: ["rice", "dal"],               regexBaseline: .match(["rice", "dal"])),
    .init(input: "chicken with vegetables",     target: ["chicken", "vegetables"],     regexBaseline: .match(["chicken", "vegetables"])),
    .init(input: "protein shake plus banana",   target: ["protein shake", "banana"],   regexBaseline: .match(["protein shake", "banana"])),
    .init(input: "eggs plus toast",             target: ["eggs", "toast"],             regexBaseline: .match(["eggs", "toast"])),
    .init(input: "sandwich alongside soup",     target: ["sandwich", "soup"],          regexBaseline: .match(["sandwich", "soup"])),
    .init(input: "salad alongside chicken",     target: ["salad", "chicken"],          regexBaseline: .match(["salad", "chicken"])),
    .init(input: "chicken served with rice",    target: ["chicken", "rice"],           regexBaseline: .match(["chicken", "rice"])),
    .init(input: "dal served with roti",        target: ["dal", "roti"],               regexBaseline: .match(["dal", "roti"])),
    .init(input: "biryani with raita",          target: ["biryani", "raita"],          regexBaseline: .match(["biryani", "raita"])),
    // 13-18: multi-additive, "and" splitting
    .init(input: "oatmeal with milk and honey", target: ["oatmeal", "milk", "honey"],  regexBaseline: .match(["oatmeal", "milk", "honey"])),
    .init(input: "rice with dal and vegetables", target: ["rice", "dal", "vegetables"], regexBaseline: .match(["rice", "dal", "vegetables"])),
    .init(input: "toast with butter and jam",   target: ["toast", "butter", "jam"],    regexBaseline: .match(["toast", "butter", "jam"])),
    .init(input: "biryani with raita and salad", target: ["biryani", "raita", "salad"], regexBaseline: .match(["biryani", "raita", "salad"])),
    .init(input: "chai with toast and butter",  target: ["chai", "toast", "butter"],   regexBaseline: .match(["chai", "toast", "butter"])),
    .init(input: "paratha with curd and pickle", target: ["paratha", "curd", "pickle"], regexBaseline: .match(["paratha", "curd", "pickle"])),
    // 19-22: verb prefix variants — regex strips verb, then matches
    .init(input: "drank coffee with milk",      target: ["coffee", "milk"],            regexBaseline: .match(["coffee", "milk"])),
    .init(input: "just had oatmeal with honey", target: ["oatmeal", "honey"],          regexBaseline: .match(["oatmeal", "honey"])),
    .init(input: "i ate rice with dal",         target: ["rice", "dal"],               regexBaseline: .match(["rice", "dal"])),
    .init(input: "had biryani with raita",      target: ["biryani", "raita"],          regexBaseline: .match(["biryani", "raita"])),
    // 23-25: meal suffix stripping — regex strips "for X", then matches
    .init(input: "coffee with milk for breakfast", target: ["coffee", "milk"],         regexBaseline: .match(["coffee", "milk"])),
    .init(input: "dal with rice for lunch",     target: ["dal", "rice"],               regexBaseline: .match(["dal", "rice"])),
    .init(input: "biryani with raita for dinner", target: ["biryani", "raita"],        regexBaseline: .match(["biryani", "raita"])),
    // 26-28: bare-juxtaposition Indian compounds — regex misses entirely (no connector)
    .init(input: "dal chawal",                  target: ["dal", "chawal"],             regexBaseline: .miss),
    .init(input: "idli sambar",                 target: ["idli", "sambar"],            regexBaseline: .miss),
    .init(input: "rajma chawal",                target: ["rajma", "chawal"],           regexBaseline: .miss),
    // 29-30: regional / verb-ending connectors — regex matches but splits at the wrong place
    .init(input: "chicken biryani garnished with cilantro",
          target: ["chicken biryani", "cilantro"],
          regexBaseline: .wrong(["chicken biryani garnished", "cilantro"])),
    .init(input: "toast topped with butter",
          target: ["toast", "butter"],
          regexBaseline: .wrong(["toast topped", "butter"])),
]

@Test func compositeGoldSet_hasThirtyQueries() {
    #expect(compositeGoldSet.count == 30,
            "design-666 QW2 deliverable specifies 30 composite-food gold queries")
}

@Test func compositeGoldSet_regexBaselineMatchesReality() {
    // For every gold-set row, the current regex output must agree with the
    // recorded `regexBaseline`. This pins what the regex does today so a
    // future regex tweak can't silently shift the FM-vs-regex split.
    for row in compositeGoldSet {
        let observed = ComposedFoodParser.parse(row.input)?.map(\.query)
        switch row.regexBaseline {
        case .match(let expected):
            #expect(observed == expected,
                    "Regex baseline drift on '\(row.input)' — recorded \(expected), got \(observed ?? [])")
        case .wrong(let expected):
            #expect(observed == expected,
                    "Regex baseline drift on '\(row.input)' — recorded wrong-output \(expected), got \(observed ?? [])")
        case .miss:
            #expect(observed == nil,
                    "Regex baseline drift on '\(row.input)' — recorded miss, got \(observed ?? [])")
        }
    }
}

@Test func compositeGoldSet_fmWinsCoverIndianAndRegional() {
    // The FM-vs-regex delta is the QW2 win surface. Make sure we have
    // coverage in both win categories — bare-juxtaposition (regex miss)
    // and regional/verb-ending connectors (regex wrong). If we ever drop
    // below this floor the gold set isn't actually testing the migration.
    let misses = compositeGoldSet.filter { if case .miss = $0.regexBaseline { return true } else { return false } }
    let wrongs = compositeGoldSet.filter { if case .wrong = $0.regexBaseline { return true } else { return false } }
    #expect(misses.count >= 3, "Need ≥3 bare-juxtaposition rows so FM coverage gain is measurable")
    #expect(wrongs.count >= 2, "Need ≥2 regional-connector rows so FM correctness gain is measurable")
}
