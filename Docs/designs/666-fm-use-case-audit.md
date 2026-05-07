# Design: Apple FM Use-Case Audit — Beyond Chat

> References: Issue #666 (related: #662 chat eval, sibling extraction-eval design)

## Problem

Drift today has zero use of Apple's Foundation Models framework. We run our own Gemma 4 / SmolLM stack for chat and a hand-coded harness everywhere else. Outside the AI-chat surface, the codebase carries **~1,700+ lines of regex, alias dictionaries, and rule-based parsing** doing semantic work that an on-device 3B FM with `@Generable` typed output would do better:

- `AIActionExecutor.extractAmount` (food unit + portion parsing) — 5 known-limit tests permanently failing on qualifiers, time expressions, hyphenated ranges, fraction+volume combos
- `LabReportOCR` + `LabReportOCR+Biomarkers` — ~650 lines of multi-line merging, ~80 biomarker IDs × ~2.5 hand-written aliases, per-test regex per lab vendor
- `StaticOverrides` — 24+ regex patterns for goals, BMI, body fat, macros, medications
- `VoiceTranscriptionPostFixer` — 30 hardcoded regex repairs for ~20 health terms (metformin, creatine, ashwagandha, A1C…)
- `AIActionParser.parseExercises` — single regex `(.+?)\s+(\d+)x(\d+)(?:@(\d+\.?\d*))?` that drops RPE, tempo, rest, modifiers
- `SpellCorrectService` — 60-entry misspelling table + 100-entry synonym table (aloo→potato, gobi→cauliflower)
- `BodySpecPDFParser` / `NutritionLabelOCR` — column-aware regex tokenizers that break on layout changes

The chat eval (#662) and the extraction eval (sibling) cover the chat surface only. This audit catalogs every other place where typed FM output beats fragile rules, scores by impact × effort × guardrail risk, and produces a sequenced 1-day-each impl roadmap.

## Proposal

Audit-only design doc. **No production code in this PR.** Output is:

1. Inventory of ≥15 candidates with file refs, impact/effort/guardrail scores
2. Top-5 quick-wins with `@Generable` schema sketches
3. Top-3 risky-but-valuable with eval gates that must clear before commit
4. Skip list with explicit reasoning
5. Sequenced 1-day impl roadmap, ordered by impact and dependency

The downstream impl tickets (filed separately after this doc lands) carry the actual code + Tier-0 unit tests + Tier-3 FM eval extensions.

## UX Flow

This is an audit, not a feature, so the user-visible UX is unchanged in this PR. Each downstream impl task improves a specific surface. Two example future flows the audit unlocks:

```
User: "log approximately 200 grams of paneer for lunch"
Today: extractAmount drops "approximately"; food name becomes "paneer for lunch" (test_knownLimit_qualifierPrefix fails)
With FM:  @Generable {amount: 200, unit: .grams, foodName: "paneer", meal: .lunch, qualifier: .approximate}
```

```
User: "bench press 3x8 at 60kg rpe 7, then 3 sets dumbbell rows 12 reps each"
Today: AIActionParser regex matches first phrase only; drops RPE; second phrase has no match
With FM: [
  {name:"bench press", sets:3, reps:8, weight:60, weightUnit:.kg, rpe:7},
  {name:"dumbbell row", sets:3, reps:12, weight:nil, rpe:nil}
]
```

## Apple FM availability

**Framework:** `FoundationModels` (iOS 26+, macOS 15+, Apple Intelligence-capable hardware: A17 Pro, M-series, A19 Pro). On-device, free, zero per-call cost.

**Drift deployment target:** iOS 14 (`project.yml` line `deploymentTarget: "14.0"`). FM calls must be gated by `if #available(iOS 26.0, *)` + runtime `SystemLanguageModel.default.availability == .available`. **Existing rule-based fallbacks stay** — they keep working on older devices and serve as the always-available baseline. FM wins compound on top, they don't replace.

**Latency budget** (Apple-published, on-device): ~50–200 ms for short structured outputs (<200 tokens), faster than Gemma 4. Acceptable inside a typing-pause boundary; not acceptable inside a per-keystroke autocomplete.

## Inventory — full candidate table

Scoring rubric:
- **Impact** 1–5: 1=rare/edge, 3=several daily users hit weekly, 5=every food/weight/exercise log
- **Effort** 1–5: 1=schema only, drop-in; 3=schema + 2-stage call + plumbing; 5=multi-week reshape
- **Guardrail risk:** none / low (display copy) / medium (numeric extraction in non-medical surface) / high (medical, dosing, weight goals)

| # | Area | Current impl (file:line) | What FM replaces | Impact | Effort | Risk | Priority |
|---|---|---|---|---|---|---|---|
| 1 | Food unit normalization | `AIActionExecutor.swift:117–225` (extractAmount) | regex + table for amount/unit/food/qualifier/meal-suffix | 5 | 2 | low | **Quick-win 1** |
| 2 | Workout natural-language parsing | `AIActionParser.swift:98–113` | single `NxR@W` regex → typed sets/reps/weight/rpe/tempo/rest list | 4 | 2 | low | **Quick-win 2** |
| 3 | Goal-setting | `StaticOverrides.swift` (goalPattern, BMI, body fat, macros) | typed `{kind, target, deadline?, unit?}` extractor | 3 | 2 | low | **Quick-win 3** |
| 4 | Biomarker term canonicalization (chat surface) | `SpellCorrectService.swift:81–180` synonym table | "how's my sugar" → glucose; "iron" → ferritin in chat queries | 4 | 1 | low | **Quick-win 4** |
| 5 | Voice transcription post-repair (long tail) | `VoiceTranscriptionPostFixer.swift:42–156` | contextual repair for health terms beyond the 20 hardcoded | 3 | 2 | low | **Quick-win 5** |
| 6 | Lab biomarker extraction | `LabReportOCR.swift` + `LabReportOCR+Biomarkers.swift` (~650 lines) | typed list of `{biomarkerId, value, unit, refLow, refHigh, date}` end-to-end on OCR text | 5 | 4 | medium | **Risky-1** |
| 7 | Recipe builder smart-fill | new surface (`Drift/Views/Food/QuickAddView.swift` is structured-input only today) | "biryani with 200g chicken, 1 cup rice, raita" → `[RecipeItem]` with food-DB resolution | 4 | 3 | low-med | **Risky-2** |
| 8 | Photo Log retake hints | `Drift/CloudVision/PhotoLogService.swift` + `PhotoLogTool.swift` (cloud-provider strings today) | local FM rewrites cloud failure into actionable hint | 2 | 2 | low | **Risky-3** |
| 9 | Nutrition label OCR | `NutritionLabelOCR.swift:65–93` (~15 regex) | typed `{calories, p, c, f, fiber, servingSize, servingUnit}` from OCR text | 3 | 2 | medium | Roadmap 6 |
| 10 | DEXA body composition PDF | `BodySpecPDFParser.swift:1–303` | typed regional body-comp from concatenated tokens | 2 | 3 | medium | Roadmap 7 |
| 11 | Failing-queries auto-categorization | does not exist | telemetry classifier into existing `Docs/failing-queries.md` taxonomy | 2 | 2 | none | Roadmap 8 |
| 12 | Composed food additive split | `ComposedFoodParser.swift:37–81` | "oatmeal with milk and honey" → `{base, additives[]}` typed | 2 | 2 | low | Skip — see below |
| 13 | Multi-food split | `AIActionExecutor.swift:138–163` | "eggs, toast, and coffee" → `[FoodIntent]` | 3 | 2 | low | Folded into #1 |
| 14 | InputNormalizer filler removal | `InputNormalizer.swift:32–138` | filler/correction-marker handling | 2 | 2 | none | Skip — see below |
| 15 | AIResponseCleaner list/bullet | `AIResponseCleaner.swift:28–35` | markup normalization | 1 | 1 | none | Skip — see below |
| 16 | Bracket action-tag parsing | `AIActionParser.swift:41–93` | `[LOG_FOOD: …]` etc. | 1 | 1 | none | Skip — model output, not user input |
| 17 | PronounResolver | `Parsing/PronounResolver.swift:23–92` | "it" / "that" / "those" referent resolution | 2 | 3 | low | Skip — works, rule-based contextual matching is fine |
| 18 | PhotoLogMatcher portion defaults | `PhotoLogMatcher.swift:18–46` (curry→200g, beverage→250g) | contextual portion default given vision result | 2 | 2 | low | Folded into Risky-3 |
| 19 | SpellCorrectService misspellings | `SpellCorrectService.swift:19–75` | 60-entry "chiken→chicken" table | 1 | 2 | none | Skip — finite, fast, deterministic |
| 20 | MealReminderScheduler copy | `MealReminderScheduler.swift:36–40` | reminder string templating | 1 | 2 | low | Skip — algorithmic, no NL parse |
| 21 | BehaviorInsightService copy | `BehaviorInsightService.swift` (498 lines) | insight title/description templates | 1 | 3 | low | Skip — data-driven, FM adds nothing |
| 22 | CSVParser | `Utilities/CSVParser.swift` | CSV tokenization | 1 | 1 | none | Skip — exact format |

Total: 22 candidates surveyed, 8 prioritized for impl roadmap, 7 explicit skips, 7 folded/lower-priority.

## Top-5 Quick-Wins

Each impl is one file change in DriftCore + a typed `@Generable` struct + `if #available(iOS 26.0, *)` gate that falls back to the existing rule path on miss. Tier-0 unit tests for the typed-output mapping; Tier-3 FM eval cases for the FM call itself.

### 1. Food unit normalization

**Replaces:** `AIActionExecutor.swift:117–225` (extractAmount and friends). Today regex tries to find amount/unit/food/qualifier/meal in one pass and drops `test_knownLimit_*` cases.

**Schema sketch:**
```swift
@Generable
struct FoodIntentExtraction {
    @Guide(description: "Numeric amount the user said. Nil if no amount mentioned.")
    let amount: Double?
    @Guide(description: "Unit the amount is in.")
    let unit: AmountUnit
    @Guide(description: "Food name with all qualifiers and meal suffixes stripped.")
    let foodName: String
    @Guide(description: "Meal period if user said 'for breakfast/lunch/dinner/snack'.")
    let meal: MealPeriod?
    @Guide(description: "Approximate, exact, or range. Default exact.")
    let qualifier: AmountQualifier
    @Guide(description: "If a hyphenated range (2-3), this is the upper bound; amount is lower.")
    let rangeUpper: Double?
}

enum AmountUnit: String, Generable {
    case grams, milliliters, ounces, fluidOunces, cup, tablespoon, teaspoon
    case piece, serving, portion, none
}
```

**Wire-in:** `AIActionExecutor.parseFoodIntent` calls FM first when available, validates with existing `normalizeToGrams`, falls back to current regex on FM unavailable / low confidence / validation failure. The 5 `test_knownLimit_*` cases become `test_*` (no limit) once gated.

**Effort:** ~80 lines new code, ~30 lines test, 1 day.

### 2. Workout natural-language parsing

**Replaces:** `AIActionParser.swift:98–113` single regex. Drops RPE, tempo, rest, modifier ("hard" / "+25kg" / bodyweight).

**Schema sketch:**
```swift
@Generable
struct ParsedWorkoutSet {
    let exerciseName: String
    let sets: Int
    let reps: Int?           // nil for time-based
    let durationSeconds: Int? // nil for rep-based
    let weight: Double?
    let weightUnit: WeightUnit?  // .kg, .lb, .bodyweight, .none
    let rpe: Double?         // 1–10
    let tempo: String?       // "3-1-2" or nil
    let restSeconds: Int?
}
```

**Wire-in:** `AIActionParser.parseExercises(_:)` returns `[WorkoutExercise]` from `[ParsedWorkoutSet]`, falling back to existing regex on FM miss. `WorkoutExercise` model gets nullable `rpe`, `tempo`, `restSeconds`, `durationSeconds` (additive — no breaking change).

**Effort:** ~60 lines + Tier-0 mapping tests + Tier-3 eval for "3x8 bench rpe 7", "amrap pullups", "30s plank", 1 day.

### 3. Goal-setting

**Replaces:** `StaticOverrides.swift` regex cluster: weight goal, calorie goal, BMI, body-fat %, macro goals (carb/protein/fat).

**Schema sketch:**
```swift
@Generable
enum GoalKind: String, Generable {
    case weightTarget, calorieTarget, proteinTarget, carbTarget, fatTarget
    case bodyFatPercent, bmi, bodyMeasurement
}

@Generable
struct GoalIntent {
    let kind: GoalKind
    let value: Double
    let unit: String?       // "kg", "lb", "g", "%", "kcal"
    @Guide(description: "ISO-8601 date if user said 'by Aug', 'in 8 weeks', etc. Nil otherwise.")
    let deadline: String?
    @Guide(description: "Direction inferred — typically 'lose' for weight, 'gain' for muscle, 'reach' for macros.")
    let direction: GoalDirection
}
```

**Wire-in:** new `GoalIntentExtractor` in `DriftCore/Sources/DriftCore/AI/Pipeline/`, called from `StaticOverrides.handleGoal` before the regex chain. Existing regex stays as fallback. Critically: deadline parsing ("by August", "in 8 weeks") is the value — regex can't do this and we currently silently drop it.

**Effort:** ~80 lines + Tier-0 + Tier-3, 1 day. **Guardrail:** weight goals are user-driven targets, not medical advice — low risk, but require `confirm: true` UI flow before persisting (already exists for goals).

### 4. Biomarker term canonicalization (chat surface only — not lab-extraction)

**Replaces:** `SpellCorrectService.swift:81–180` synonym lookups specifically when the chat user references a biomarker informally ("how's my sugar trending", "what was my iron last month", "is my A1C ok").

**Schema sketch:**
```swift
@Generable
enum BiomarkerCanonical: String, Generable {
    case glucose, hba1c, ldl, hdl, totalCholesterol, triglycerides
    case ferritin, iron, tsh, freeT3, freeT4, vitaminD, b12
    case crp, homocysteine, testosterone, cortisol
    // ~40 canonical IDs total
    case unknown
}

@Generable
struct BiomarkerReference {
    let canonical: BiomarkerCanonical
    let userTerm: String     // what the user said, for echo
    let confidence: Double
}
```

**Wire-in:** thin layer in front of existing `BiomarkerKnowledgeBase` lookup; if FM returns `.unknown` or low confidence, fall through to current dictionary. Improves recall on long-tail terms ("good cholesterol" → hdl) without growing the dictionary.

**Effort:** ~50 lines + Tier-0 + Tier-3 with 30 informal-term cases, 1 day.

### 5. Voice transcription post-repair (long tail)

**Replaces:** `VoiceTranscriptionPostFixer.swift:42–156`. The 30 hardcoded regex repairs catch the top-20 health terms; everything else mistranscribed today silently corrupts the AI input.

**Schema sketch:**
```swift
@Generable
struct TranscriptRepair {
    @Guide(description: "Repaired transcript. Identical to input if no health/medical terms appear mistranscribed.")
    let repaired: String
    @Guide(description: "List of (originalSpan, repairedTo) pairs for telemetry. Empty if no changes.")
    let edits: [Edit]
    let confidence: Double
}

@Generable
struct Edit { let originalSpan: String; let repairedTo: String }
```

**Wire-in:** `VoiceTranscriptionPostFixer.fix(_:)` runs the existing 30 regex first (deterministic, fast, free), then if FM is available **and** the result still contains low-confidence tokens (ratio of out-of-vocab health terms), runs FM as a second pass. Two-tier so we don't pay 100ms latency on every utterance.

**Effort:** ~60 lines + Tier-0 + Tier-3, 1 day. **Guardrail:** never repair into a *different* drug name — eval gate on a 50-term confusion set asserts no false flips between distinct supplements.

## Top-3 Risky-But-Valuable

These have high impact but enough guardrail or latency risk to require explicit eval before commit. Each lists the eval question that must answer "yes" before merging.

### Risky-1. Lab biomarker extraction (medical accuracy)

**What:** Replace ~650 lines of OCR-line-merging + per-biomarker regex + alias dictionary with a single FM call returning a typed list of `{biomarkerId, value, unit, refLow, refHigh, date}` from OCR text. Today's pipeline already does LLM extraction (Gemma 4) when loaded and merges with regex by confidence; this swaps Gemma 4 for Apple FM (faster, free, structured output).

**Why valuable:** the 80 biomarkers × ~2.5 aliases × N lab vendors is a combinatorial alias-table that only grows. FM learns lab-report structure implicitly.

**Risk:** medical surface. A wrong glucose value or wrong unit (mg/dL vs mmol/L) leads the user to a wrong conclusion about their health.

**Eval gate before commit:** 50 anonymized lab reports across Quest, Labcorp, Everlywell, Whoop, BodySpec. Required: ≥98% extraction recall vs. current pipeline, **zero unit-confusion errors**, ≥99% precision (false biomarkers extracted is worse than missing one). If any of those fail, ship as parallel-extractor + confidence-merge against existing regex, not a replacement.

**Effort:** ~3 days impl + 2 days eval set construction.

### Risky-2. Recipe builder smart-fill

**What:** Add a free-text field to `Drift/Views/Food/QuickAddView.swift` ("paste a meal description") that FM expands into `[RecipeItem]` populated against the existing food DB. Today users tap-and-search per ingredient.

**Why valuable:** the "log my home-cooked recipe" flow is the highest-friction surface in the app. A friend tested logging palak paneer with rice and dal — 6 taps per ingredient, 18 taps total. FM smart-fill is one paste.

**Risk:** hallucinated ingredients (FM invents a food name not in the DB), wrong macros (FM picks the wrong DB row), stale carryovers if the FM ignores the food-DB grounding instructions.

**Eval gate before commit:** 50 recipe-text inputs covering Indian, American, snack, drink, dessert. Required: 100% of returned items must either (a) resolve to an existing `Food` row by ID or (b) be flagged `customFood: true` for explicit user confirmation. Any item that silently invents a non-existent ingredient is a fail.

**Effort:** ~3 days (schema + FM call + UI for confirm-or-edit + grounding-prompt that includes top-50 candidate foods from DB search).

### Risky-3. Photo Log retake hint generation

**What:** When `PhotoLogService` returns low-confidence or empty results, run FM locally over the photo's vision-API result + user prompt to produce a friendly retake hint ("the dal is in shadow — try with the plate by the window"). Today retake messaging is hardcoded by the cloud provider, generic.

**Why valuable:** Photo Log failures are the second-most-common friction surface (after free-text recipe). Hardcoded "try better lighting" doesn't tell the user *what* the model couldn't see.

**Risk:** weird copy. FM occasionally generates over-specific or condescending hints.

**Eval gate before commit:** 30 sample failure photos with vision-API results stubbed. Friend rates each generated hint on a 3-point scale (helpful / neutral / cringe). Ship if ≥80% helpful, <5% cringe.

**Effort:** ~2 days, mostly the eval rig + UI string flow.

## Skip list (with reasoning)

Surfaces that surfaced during the audit and are **not** worth migrating. Explicit reasoning beats hand-wavy "out of scope":

1. **InputNormalizer filler removal** (`InputNormalizer.swift:32–138`) — the 40-entry filler list and correction-marker patterns are deterministic, fast (<1ms), and run on every voice utterance before any LLM. Adding a 100ms FM call here delays the entire chat path. The list maintenance cost is real but small (~3 entries/year), and the failure mode of "we missed a filler" is benign — the downstream classifier handles it.
2. **AIResponseCleaner bullet/list normalization** (`AIResponseCleaner.swift:28–35`) — markup cleanup on **model output**, not user input. The markup format is what we ask the model to produce. If we replace the producer, we change the format. FM on the consumer side fixes a problem we caused.
3. **Bracket action-tag parsing** (`AIActionParser.swift:41–93`) — same: `[LOG_FOOD: …]` is a contract between *our* model prompt and *our* parser. FM doesn't help parse a format we control.
4. **CSVParser** (`Utilities/CSVParser.swift`) — exact RFC 4180 format. FM is the wrong tool; regex is correct.
5. **PronounResolver** (`Parsing/PronounResolver.swift:23–92`) — context-aware "it" / "that" referent resolution. Works well today; rule + recency-window matching is sound and FM would lose deterministic behavior here. Replace only if the existing tests start regressing.
6. **SpellCorrectService 60-entry misspelling table** (`SpellCorrectService.swift:19–75`) — finite known misspellings (chiken, brocoli, …). Deterministic, fast, drives food search ranking. FM can't add value here without latency cost. The synonym table (entries 81–180) is a different surface — that one is in the **Quick-Win 4** scope.
7. **BehaviorInsightService templates** (`BehaviorInsightService.swift`, 498 lines) — algorithmic insights from logged data, not NL parsing. FM doesn't make "you logged 95g protein this week, 5g short of your 100g goal" any better.
8. **MealReminderScheduler copy** — 4-line templated string. Replacing with FM-generated copy is variety for the sake of it; user research would steer this, not an audit.

## Roadmap

Sequence the top-5 quick-wins as separate impl tasks. Each ticket should be ~1-day effort, file scope ≤2 files in DriftCore, with Tier-0 unit tests for typed-output mapping and Tier-3 FM eval cases for the FM call itself. Top-3 risky items file as ≥3-day tickets with the explicit eval gate as acceptance criterion.

| # | Ticket | Depends on | Est. effort |
|---|---|---|---|
| 1 | Wire `FoundationModelsBackend` (shared `LanguageModelSession` + availability gate + retry/throttle) | — | 1 day |
| 2 | **Quick-Win 1**: Food unit normalization (`AIActionExecutor`) | #1 | 1 day |
| 3 | **Quick-Win 2**: Workout NL parsing (`AIActionParser`) | #1 | 1 day |
| 4 | **Quick-Win 3**: Goal-setting (`StaticOverrides` + new `GoalIntentExtractor`) | #1 | 1 day |
| 5 | **Quick-Win 4**: Biomarker term canonicalization (chat surface) | #1 | 1 day |
| 6 | **Quick-Win 5**: Voice transcription post-repair (long tail) | #1 | 1 day |
| 7 | **Risky-1**: Lab biomarker extraction (eval-gated) | #1 + 50-report eval set | 5 days |
| 8 | **Risky-2**: Recipe builder smart-fill | #1 + UI design | 3 days |
| 9 | **Risky-3**: Photo Log retake hints | #1 + 30-photo failure set | 2 days |

Ticket #1 (the shared backend) is the only blocker. After that, quick-wins #2–#6 are independent and can be picked up in any order. Risky tickets #7–#9 require eval-set construction up front and should not start until at least one quick-win ships and validates the integration pattern in production TestFlight.

## Technical Approach

**Where the FM call lives:** new `DriftCore/Sources/DriftCore/AI/LLM/FoundationModelsBackend.swift`. Owns the `LanguageModelSession`, availability check, retry, and a generic `extract<T: Generable>(_:from:) async throws -> T` helper. Each candidate (food, workout, goal, …) calls this with its `@Generable` schema.

**Availability gating:**
```swift
@available(iOS 26.0, macOS 15.0, *)
struct FoundationModelsBackend {
    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }
}
```
Every call site:
```swift
if #available(iOS 26.0, *), FoundationModelsBackend.isAvailable {
    if let result = try? await FoundationModelsBackend.shared.extract(...) { return result }
}
return existingRuleBasedFallback(input)
```
This satisfies the "wins compound, don't replace" constraint and means **older devices keep working unchanged**.

**Test tier mapping (per CLAUDE.md):**
- Schema → typed-output mapping: Tier 0 (`DriftCoreTests`)
- Mock-FM round-trip (deterministic, no real model): Tier 2 (`DriftLLMEvalMacOS`, no env gate)
- Real FM accuracy on candidate set: Tier 3 (`DriftLLMEvalMacOS`, gated by FM availability — runs on macOS 15 host with Apple Intelligence)
- Risky-tier eval sets (50 lab reports, 30 photos, 50 recipes): Tier 4 (env-gated — `DRIFT_FM_EVAL=1`)

**Performance budget per call site:**
- Food extraction: <200ms — one-shot, blocks send-to-AI flow
- Workout extraction: <300ms — ok, multi-line input is rarer
- Goal-setting: <300ms — confirm-step UI absorbs latency
- Voice repair: <100ms or skip — runs on every utterance
- Lab biomarker: <2s — already async, user is reviewing PDF

## Edge Cases

- **FM unavailable** (older device, Apple Intelligence not enabled, on-device model still downloading): every call site falls through to the existing rule-based path. No behavior regression on iPhone 14 / iOS 25.
- **FM returns invalid output** (unparseable JSON despite `@Generable`, schema drift on OS update): retry once, then fall back to rules. Log the input to telemetry-free local "failing-FM" log for offline review.
- **FM output passes schema but fails domain validation** (food unit "lightyear", weight 9999kg): existing Swift validators (`normalizeToGrams`, `WeightEntry.isValid`) reject and we fall back. Validators aren't optional even when FM is "trusted."
- **Latency spike** (cold session start, model paging): per-call timeout (200–300ms quick-wins, 2s lab) → fall back to rules. The user never sees a hung send button.
- **Concurrent calls** (food + biomarker extraction in same chat turn): backend serializes via session actor; ordered queue with bounded depth = 4. Older queued calls dropped with timeout error → rule fallback.
- **Privacy:** every FM call is on-device. No tenets violated. The existing privacy memo in `Docs/decisions.md` already permits Apple's on-device frameworks (HealthKit, Vision); FoundationModels is the same category.

## Open Questions

1. **Which iOS version do we set as the baseline for ticket #1?** Apple FM is iOS 26+. Drift's deployment target is iOS 14. Confirm with owner whether to (a) keep iOS 14 deployment + runtime gate (recommended, no user lockout), or (b) raise to iOS 17 deployment to use newer Swift Concurrency APIs (cleaner code, locks out 5–8% of installed base).
2. **Telemetry policy for FM accuracy:** the audit recommends a local "failing-FM" log for offline review. Confirm this is OK under the privacy-first tenet (it's local, never transmitted, mirrors the existing `Docs/failing-queries.md` workflow). If not, eval gates on impl tickets become the only signal.
3. **Risky-1 eval set sourcing:** we need 50 anonymized lab reports across Quest, Labcorp, Everlywell, Whoop, BodySpec. We have a smaller corpus from the existing `LabReportOCR` test fixtures. Confirm whether owner can supply more, or whether the eval gate scales to whatever fixtures exist (~15 today).
4. **Quick-Win 4 scope:** biomarker term canonicalization is described as the chat-surface only (resolving "sugar" → glucose for queries). Confirm this stays out of the **lab-extraction** path — that's Risky-1 and has separate eval requirements.
5. **Friend feedback on Risky-3:** the photo-retake-hint eval gate ("≥80% helpful, <5% cringe") relies on friend rating. Confirm whether two friends' ratings is enough, or whether to gate on owner sign-off only.

---

*To approve: add `approved` label to the PR. To request changes: comment on the PR.*
