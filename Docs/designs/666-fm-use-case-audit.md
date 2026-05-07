# Design: Apple Foundation Models — Use-Case Audit Beyond Chat

> Issue: #666 | Status: Awaiting approval — implementation tasks file separately
> Related: #662 (FM chat eval), extraction-eval sibling — this audit assumes those evals run separately and does not duplicate

## Problem

Drift has invested heavily in handcrafted regex / rule tables / hardcoded keyword lists across the AI pipeline. The chat eval (#662) and extraction-eval sibling cover two surfaces. There are many more places where 3B-on-device structured output would replace fragile code — and Apple FM has no per-call cost, so the gating is purely correctness, latency, and guardrails.

Chat is already in the queue. This audit catalogs *non-chat* surfaces and ranks them so we don't burn cycles converting things that aren't worth it (or worse, things where rules are precisely better).

## Proposal

A prioritized roadmap of 5 quick-win FM migrations and 3 risky-but-valuable candidates that need eval before commit. No code changes in this PR — design only. Each top-5 quick win becomes a separate ~1-day sprint task with a sketched `@Generable` schema and a target file path. The skip list documents what NOT to migrate (so a future audit doesn't repeat the analysis).

Scope **out**: AI-chat domain extraction (covered by #662), telemetry-driven failure auto-categorization (depends on telemetry pipeline that doesn't exist yet), photo-log calorie estimation (covered by #224).

## Audit method

Phase 1 — codebase sweep across `DriftCore/Sources/DriftCore/AI/Parsing/`, `DriftCore/Sources/DriftCore/AI/Pipeline/`, `DriftCore/Sources/DriftCore/Domain/{Food,Workout,Health}/`, and `Drift/Services/`. Grep for `NSRegularExpression`, `\.range(of:)`, hand-rolled tokenizers, and hardcoded keyword lists.

Phase 2 — score each candidate:
- **Impact (1-5)**: 5 = hits every food/chat session, 1 = rare path
- **Effort (1-5)**: 1 = single function + small struct, 5 = cross-cutting refactor
- **Guardrail risk**: high = medical/dosing/weight semantics; medium = could refuse on edge cases; low = food/measurement/copy; none = pure transformation

Phase 3 — bucket into Quick Win, Risky-but-Valuable, or Skip.

## Inventory (18 candidates)

| # | Area | Current impl | What FM would replace | Impact | Effort | Risk | Priority |
|---|------|-------------|----------------------|:-:|:-:|:-:|---|
| 1 | Food quantity/unit/multiplier | `AIActionExecutor.extractAmount` (~227 LOC) | "200g paneer", "1/3 plate", "double the rice" → typed Quantity + Unit | 5 | 2 | Low | **QW1** |
| 2 | Ingredient density matching | `AIActionExecutor.matchIngredient` (~27 LOC) | Food → density gram lookup | 4 | 1 | Low | **QW1** (combined) |
| 3 | Composed food split | `ComposedFoodParser` (~55 LOC) | "coffee with milk" → [coffee, milk] | 4 | 2 | Low | **QW2** |
| 4 | Food intent parsing | `AIActionExecutor.parseFoodIntent` (~37 LOC) | "ate 2 eggs for lunch" → FoodIntent | 5 | 2 | Low | **QW1** (combined) |
| 5 | Multi-food split | `AIActionExecutor.parseMultiFoodIntent` (~48 LOC) | "chicken and rice" handling, compound foods | 5 | 2 | Low | **QW1** (combined) |
| 6 | Weight goal regex | `StaticOverrides.weightGoalPattern` (~25 LOC) | "lose 5 kg by August" → GoalUpdate | 2 | 1 | Medium | **RV1** |
| 7 | Protein goal regex | `StaticOverrides` (~16 LOC) | "protein goal 150g" | 1 | 1 | Low | **RV1** (combined) |
| 8 | Calorie goal regex | `StaticOverrides` (~16 LOC) | "calorie target 2000" | 1 | 1 | Low | **RV1** (combined) |
| 9 | Workout exercise parser | `AIActionParser.parseWorkoutExercises` (~14 LOC) | "3x10 bench at 60kg" → WorkoutEntry | 3 | 2 | Low | **QW3** |
| 10 | Activity duration parse | `StaticOverrides` activity duration (~28 LOC) | "30 min yoga", "for an hour" | 2 | 1 | Low | **QW3** (combined) |
| 11 | Workout pattern detect | `StaticOverrides.containsWorkoutSetPattern` (~6 LOC) | Pipeline routing trigger | 3 | 1 | Low | **QW3** (combined) |
| 12 | Biomarker term aliasing | `LabReportOCR+Biomarkers.extractBiomarker` (~46 LOC) | "sugar"→glucose, "iron"→ferritin | 2 | 2 | Medium | **RV2** |
| 13 | Unit conversion table | `BiomarkerKnowledgeBase` (~28 LOC) | mmol/L → mg/dL | 1 | 2 | High | **Skip** |
| 14 | Voice post-repair | `VoiceTranscriptionPostFixer` (~104 LOC) | "mutter in"→metformin context-aware | 2 | 3 | High | **RV3** |
| 15 | Nutrition label OCR | `NutritionLabelOCR.parseNutritionFromText` (~59 LOC) | OCR'd "Calories 200" → values | 2 | 2 | Medium | **Skip** |
| 16 | BodySpec PDF parser | `BodySpecPDFParser.parseText` (~80 LOC) | DEXA tables → body comp rows | 1 | 3 | Low | **Skip** |
| 17 | Behavior insight templating | `BehaviorInsightService` (~142 LOC) | Adaptive grammar/pluralization for reminder copy | 3 | 2 | Low | **QW5** |
| 18 | Inline macro entry | `StaticOverrides` macro pattern (~34 LOC) | "400 cal 30g protein" → MacroEntry | 2 | 1 | Low | **QW4** |

Total LOC of rule-based code potentially superseded across all 18: **~1,100 LOC**. Top-5 alone replace ~660 LOC.

## Top 5 quick wins

Selection rule: high impact ÷ effort, low/none guardrail risk, no medical-judgment surface area. Each is shippable in ~1 day after #662 (eval harness) lands.

### QW1 — Unified `FoodLogIntent` extraction

**Replaces**: candidates #1, #2, #4, #5 — `AIActionExecutor.extractAmount` + `matchIngredient` + `parseFoodIntent` + `parseMultiFoodIntent` (~340 LOC).

**Why this first**: every food log entry, every chat message routed to `log_food`, and every recipe-builder paste hits this code path. Today it has eight known limit tests in `DomainExtractorTests` (`test_knownLimit_*`) that document specific regex misses — those tests become the FM-eval gold set on day one.

**Schema sketch**:

```swift
@Generable
struct FoodLogIntent {
    @Guide(description: "Primary food name, singular canonical form")
    let foodName: String

    @Guide(description: "Numeric quantity")
    let quantity: Double

    @Guide(description: "Unit of measurement; use .servings if ambiguous")
    let unit: Unit

    @Guide(description: "Meal type if user said breakfast/lunch/dinner/snack")
    let mealType: MealType?

    @Guide(description: "Additional foods user mentioned in same message")
    let additionalItems: [Item]

    @Generable enum Unit {
        case grams, ounces, milliliters, cups, tablespoons, teaspoons,
             pieces, slices, plates, bowls, servings
    }
    @Generable enum MealType { case breakfast, lunch, dinner, snack }
    @Generable struct Item { let foodName: String; let quantity: Double; let unit: Unit }
}
```

**Call site**: new `DriftCore/Sources/DriftCore/AI/FoundationModels/FoodLogIntentExtractor.swift`, called from `AIToolAgent` when `log_food` is selected and feature flag `FM_FOOD_INTENT` is on. Falls back to existing `AIActionExecutor` extractors on `GenerationError.guardrailViolation` or unavailability.

**Risk**: low. Output is structured numerics + enums; no medical claim. Worst FM behavior is wrong unit (e.g., grams vs ounces) — same failure mode as today, caught by existing macro sanity checks.

### QW2 — `CompositeFoodEntry` split

**Replaces**: #3 — `ComposedFoodParser` (~55 LOC of hardcoded connector list `["served with", "alongside", "plus", "with"]`).

**Why**: Indian-food bar means we routinely see "dal chawal", "biryani with raita", "idli sambar". The current parser handles three connectors; FM understands "garnished with", "served alongside", "topped with", and regional connectors without a list update. Quickest win after QW1 because it reuses the same FM adapter.

**Schema sketch**:

```swift
@Generable
struct CompositeFoodEntry {
    @Guide(description: "Each distinct food component the user mentioned")
    let components: [Component]

    @Generable struct Component {
        @Guide(description: "Singular food name")
        let foodName: String
        @Guide(description: "True for the dish's main item, false for accompaniments")
        let isMain: Bool
    }
}
```

**Call site**: replace body of `ComposedFoodParser.parse(_:)`. Existing call sites unchanged.

**Risk**: low. Pure linguistic split, no quantitative judgment.

### QW3 — `WorkoutEntry` unified extraction

**Replaces**: #9, #10, #11 — `AIActionParser.parseWorkoutExercises` + `StaticOverrides` activity duration + workout-set-pattern detection (~48 LOC across three files).

**Why**: today's regex `(.+?)\s+(\d+)x(\d+)(?:@(\d+\.?\d*))?` doesn't handle "3 sets of 10", "8-12 reps", "RPE 8", "1h30m", "rest 90s". One typed call covers all of these and exposes optional fields cleanly.

**Schema sketch**:

```swift
@Generable
struct WorkoutEntry {
    @Guide(description: "Canonical exercise name, e.g. 'bench press' not 'bench'")
    let exerciseName: String
    @Guide(description: "Strength: number of sets")
    let sets: Int?
    @Guide(description: "Strength: reps per set; for ranges, use the middle value")
    let reps: Int?
    @Guide(description: "Weight in user's preferred unit; nil for bodyweight")
    let weight: Double?
    @Guide(description: "Cardio/mobility: total duration minutes")
    let durationMinutes: Int?
    @Guide(description: "Movement category")
    let category: Category

    @Generable enum Category { case strength, cardio, mobility, sports }
}
```

**Call site**: new `DriftCore/Sources/DriftCore/AI/FoundationModels/WorkoutEntryExtractor.swift`, replaces parser call in `AIActionParser` and `StaticOverrides` duration helpers.

**Risk**: low. Weight is a number; FM hallucinating wrong weight is no worse than today's regex misreading it. Bound check (max 500 kg / 1100 lbs) in Swift after extraction.

### QW4 — `MacroEntry` inline parser

**Replaces**: #18 — `StaticOverrides` macro pattern (~34 LOC).

**Why**: "400 cal 30g protein" is a short, structured pattern but users write it five different ways ("400 calories, 30g protein", "30 grams protein 400 cal", "400/30/40/15"). Quick win because the schema is small, the eval set is short, and it sits in chat-adjacent code that already has FM scaffolding planned by #662.

**Schema sketch**:

```swift
@Generable
struct MacroEntry {
    @Guide(description: "Total calories in kcal")
    let calories: Int
    @Guide(description: "Protein in grams") let protein: Double?
    @Guide(description: "Carbohydrates in grams") let carbs: Double?
    @Guide(description: "Fat in grams") let fat: Double?
    @Guide(description: "Optional food name if user named the meal")
    let foodName: String?
    @Guide(description: "Optional meal type")
    let mealType: MealType?

    @Generable enum MealType { case breakfast, lunch, dinner, snack }
}
```

**Call site**: replace `parseInlineMacros` in `StaticOverrides`. Keep the existing macro-vs-calorie sanity check (`4P + 4C + 9F ≈ calories ± 10%`) post-extraction.

**Risk**: low. Numeric; sanity-checked downstream.

### QW5 — Behavior-insight copy adaptation

**Replaces**: #17 — pluralization/grammar branches in `BehaviorInsightService` (~142 LOC of templated insight strings).

**Why**: today's templates fork on `count == 1 ? "workout" : "workouts"` for every metric. FM generates one fluent sentence from a structured insight, eliminating the per-template grammar branches. The output is text the user reads — no structured downstream consumer — so guardrail risk is zero in the *parsing* sense (FM might still refuse some prompts, fallback to template).

**Schema sketch**:

```swift
@Generable
struct InsightCopy {
    @Guide(description: "Single sentence, plural-aware grammar, encouraging tone, no emojis")
    let message: String
    @Guide(description: "Optional 1-3 word CTA button label, or nil for passive insight")
    let ctaLabel: String?
}
```

Caller passes a structured `InsightContext` (metric, current value, goal value, streak length, direction) and gets back ready-to-render copy.

**Call site**: `BehaviorInsightService.copy(for:)` — new method; existing template helpers stay as fallback when `FM_INSIGHT_COPY` is off or FM returns nil.

**Risk**: none-to-low. Copy generation, not data extraction. Fallback to template is one line.

## Top 3 risky-but-valuable

These have real upside but need an explicit eval before any commit lands. Each lists the eval question that gates the migration.

### RV1 — Goal setting NL (weight + protein + calorie unified)

**Replaces**: #6, #7, #8 — three separate regexes in `StaticOverrides` (~57 LOC combined).

**Schema sketch**:

```swift
@Generable
struct GoalUpdate {
    @Guide(description: "Which metric the user is setting")
    let goalType: GoalType
    @Guide(description: "Target numeric value in the unit field below")
    let value: Double
    @Guide(description: "Unit literal, e.g. 'lbs', 'kg', 'g', 'kcal'")
    let unit: String
    @Guide(description: "Optional ISO date if user named a deadline")
    let deadline: String?

    @Generable enum GoalType {
        case targetWeight, proteinDaily, caloriesDaily, weightChangeRate
    }
}
```

**Why valuable**: today `weightGoalPattern` misses ranges ("150-160 lbs"), hyphenated word numbers, and date deadlines entirely. FM nails all three.

**Why risky**: weight-loss prompts are the most likely surface to trip Apple FM's guardrails ("I want to lose 5 kg" can pattern-match restrictive-eating intent classifiers).

**Eval question (must answer before commit)**: across the existing weight-goal gold set in `StaticOverridesTests`, what fraction triggers `GenerationError.guardrailViolation`? If >5%, drop weight goals from the migration and keep regex; migrate only protein + calorie. If 0–5%, ship with fallback and log refusal rate to `ChatTelemetryService`.

**Risk**: medium. Mitigation: bounds check (target weight in [25, 300] kg, protein in [0, 500] g, calories in [500, 6000]); refuse silent no-ops if bounds violated.

### RV2 — Biomarker term canonicalization

**Replaces**: #12 — `LabReportOCR+Biomarkers.extractBiomarker` alias table (~46 LOC).

**Schema sketch**:

```swift
@Generable
struct BiomarkerCanonical {
    @Guide(description: "Canonical biomarker ID from the BiomarkerKnowledgeBase enum")
    let canonicalID: BiomarkerID
    @Guide(description: "Confidence 0.0-1.0 that the user/document means this biomarker")
    let confidence: Double

    @Generable enum BiomarkerID {
        case glucose, hba1c, ldl, hdl, totalCholesterol, triglycerides,
             ferritin, vitaminD, vitaminB12, tsh, t3, t4, /* ... */
    }
}
```

**Why valuable**: lab reports use 40+ aliases per biomarker across formats and locales. Today's hardcoded alias list is the single biggest source of "biomarker not recognized" errors during PDF import.

**Why risky**: medical interpretation. FM might canonicalize "thyroid" → tsh confidently when the user actually has T3/T4 values listed.

**Eval question**: build a 100-case gold set of misheard/aliased biomarker terms (drawn from real failing-queries log + OCR'd lab PDFs). What's the per-class precision? If any class drops below 95%, gate that class behind dictionary fallback (FM only handles the cases dictionary fails on).

**Risk**: medium. Mitigation: confidence threshold gate (≥0.7 to apply, else fall through to dictionary).

### RV3 — Voice transcription post-repair (biomarker + medication terms)

**Replaces**: #14 — `VoiceTranscriptionPostFixer` regex rules (~104 LOC, 52+ unambiguous rules + 6 context-guarded).

**Why valuable**: every new misheard term today requires a code change. FM understanding of "what term is this user probably saying given the biomarkers/medications in their log history" is the cleanest fix — and the user *already* maintains this list in their profile, which we can pass as context.

**Why risky**: hallucinating a medication name not in the user's history is worse than logging the raw misheard text. Today's regex either matches or doesn't; FM might confidently rewrite "creatinine" as "creatine" because creatine is a more common word.

**Eval question**: precision/recall on the existing `VoiceTranscriptionPostFixerTests` gold set + 50 net-new misheard terms collected from real users. Recall must beat current regex (today ~70% on canon list); precision must stay ≥98% (i.e., no introduction of names the user has never logged).

**Risk**: high. Mitigation: pass the user's own medication/biomarker list as context (`@Guide` candidate set), so FM is constrained to terms the user already tracks.

## Skip list (≥3, with reasoning)

### Skip 1 — Unit conversion table (mmol/L → mg/dL) [#13]

**Why**: deterministic math. Once you know the unit string, the conversion is a fixed multiplier. FM brings no value, adds 200-500ms latency, and on a guardrail refusal we'd just fall back to the multiplier table anyway. Better to fix unit-string detection (which is just keyword matching) and keep the conversion arithmetic.

**What to fix instead**: the unit-string detector — but that's a 5-line keyword match, not an FM candidate.

### Skip 2 — BodySpec PDF parser [#16]

**Why**: BodySpec PDFs have a precise tabular format. The hard problem is OCR token reassembly across PDF columns, not semantic understanding. A 3B LLM doesn't help when the input is `["12.3", "%", "BF"]` instead of `"12.3% BF"` — the tokenizer fix is upstream of any FM call. Once tokens are clean, regex parsing is reliable. Investing here would mean rewriting OCR pre-processing, not the parser.

**What to fix instead**: tokenizer fix is `BodySpecPDFParser.preserveSpacing` — separate task.

### Skip 3 — Nutrition label OCR value extraction [#15]

**Why**: similar to BodySpec — the bottleneck is OCR confidence, not parsing. Once the OCR text is clean, "Calories 200" is a 1-line regex. Where OCR is bad ("Calories Z00"), FM hallucinates ("Calories 200" or "Calories 700" — both plausible). Net regression risk. The right fix is multi-pass OCR with confidence scoring, not FM extraction.

**What to fix instead**: OCR confidence pass — separate task (out of scope of this audit).

### Skip 4 — Word number resolution ("one sixty" → 160) [in StaticOverrides]

**Why**: deterministic; the existing `resolveWordNumbers()` already handles single-digit + tens combos. Edge cases ("two hundred and fifty") could be handled by a short dictionary extension. FM is overkill — adds latency and cost (token-wise) for a problem that's pure NumberFormatter territory.

### Skip 5 — Static-override navigation patterns ("show me my weight chart")

**Why**: short prefix matching, ~6 keywords per tab, 4 tabs. Hardcoded flow is fast and zero-failure. FM call adds 200-500ms to a navigation that should feel instant.

## Roadmap (top-5 sequenced)

Each task is filed as a separate sprint-task issue once #662 (eval harness) lands. Order is impact-first, with QW2 sequenced after QW1 because it reuses the same FM adapter scaffolding.

| Order | Task | Est. effort | Blocked-by | Files touched |
|------|------|-------------|------------|---------------|
| 1 | **FM-QW1** Unified FoodLogIntent extraction | ~1 day | #662 | New `FoodLogIntentExtractor.swift`; rewire `AIActionExecutor.parseFoodIntent` + `parseMultiFoodIntent` + `extractAmount` |
| 2 | **FM-QW2** CompositeFoodEntry split | ~0.5 day | QW1 (FM adapter) | `ComposedFoodParser.swift` body replacement |
| 3 | **FM-QW3** WorkoutEntry unified extraction | ~1 day | QW1 (FM adapter) | New `WorkoutEntryExtractor.swift`; rewire `AIActionParser.parseWorkoutExercises` + `StaticOverrides` duration helpers |
| 4 | **FM-QW4** MacroEntry inline parser | ~0.5 day | QW1 (FM adapter) | `StaticOverrides.parseInlineMacros` body replacement |
| 5 | **FM-QW5** BehaviorInsight copy adaptation | ~1 day | QW1 | `BehaviorInsightService.copy(for:)` new method + per-template fallbacks |

**Total**: ~4 days of impl work, replacing ~660 LOC of rule-based parsing with ~5 typed `@Generable` calls + Swift validators.

Each task gets:
- Tier 0 unit tests for the new extractor (Swift-side mock + assertion that fallback fires on simulated guardrail refusal)
- Tier 3 eval extension in `DriftLLMEvalMacOS` reusing existing gold sets
- A feature flag (`FM_FOOD_INTENT`, `FM_COMPOSED_FOOD`, `FM_WORKOUT`, `FM_MACROS`, `FM_INSIGHT_COPY`) so we can ship dark and toggle live

## Edge cases (audit-level — per-task edges live in their own designs)

- **Unavailable on iOS < 26 / Mac < 26**: every QW must keep its rule-based fallback intact and behind a `#available` check. No QW deletes the rule code — it stays as the fallback path.
- **Guardrail refusal** mid-extraction: caller catches `GenerationError.guardrailViolation`, logs to `ChatTelemetryService` with `outcome: .fmRefusal`, falls back to existing extractor, returns the same shape so downstream code doesn't branch on backend.
- **Latency spike**: each QW must be measured against current rule-based latency in the eval. If FM p90 > 1.5× current p90, we ship behind a slower-path flag instead of replacing the regex. (For QW4 / QW5 the latency budget is tight because they're in the inline-macro and reminder paths respectively.)

## Open questions

1. **Schema location**: do we keep `@Generable` structs alongside their extractors (`FoundationModels/FoodLogIntent.swift` next to `FoodLogIntentExtractor.swift`), or in a shared `FoundationModels/Schemas/` directory? Recommend co-location until ≥3 schemas share fields.
2. **Feature-flag default**: should QW1-QW5 default ON for iOS 26+ devices on first install, or OFF until a TestFlight cohort validates? Recommend OFF on first ship, flip to ON in the next TestFlight after a clean week of telemetry.
3. **Confidence-threshold convention**: RV2 introduces a per-result confidence (0.0-1.0). Should this become a standard pattern across all FM extractors (every `@Generable` returns confidence), or only where downstream needs to gate? Recommend opt-in — adds tokens to the prompt for no benefit when caller doesn't read it.
4. **Telemetry depth**: today `ChatTelemetryService` logs intent + outcome. Should FM-extractor failures (refusals, low confidence, fallback fires) get a separate channel, or piggyback on existing? Recommend piggyback with new `outcome` enum values to avoid a new pipeline.
5. **RV1 eval gating**: who decides what refusal-rate threshold kills the migration vs. ships with fallback? Recommend: human owner reviews the eval report PR (per #662 deliverable workflow) and labels `approved` / `needs-rework` / `kill`.

---

*To approve: add `approved` label to the PR. Each top-5 quick win is a separate sprint task filed after this design is approved and #662 lands.*
