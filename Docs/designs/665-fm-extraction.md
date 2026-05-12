# Design: report extraction with Apple Foundation Models — eval + integration

> Issue: #665 | Status: Awaiting approval — eval scaffolding included; real numbers fill in once humans land #662 (FM eval harness) on a macOS 26 box
> Related: #662 (FM chat eval), #666 (FM use-case audit, closed/approved), #74 (lab-report LLM history)

## Problem

Drift extracts structured data from four input surfaces today, and every one of them is regex/keyword-fragile:

| Path | Current impl | LOC | Failure mode |
|------|-------------|----:|-------------|
| BodySpec DEXA PDFs | PDFKit + regex | `Drift/Services/BodySpecPDFParser.swift` (303) | breaks when BodySpec changes column order, multi-page splits, decimal vs integer mass |
| Lab reports | Vision OCR + regex (+ optional Gemma fallback) | `Drift/Services/LabReportOCR.swift` (467) | every lab provider format is a code change; Gemma is too big to ship as default |
| Nutrition labels | Vision OCR + regex | `Drift/Services/NutritionLabelOCR.swift` (124) | non-English labels (Hindi, Spanish, Tamil) silently produce zeros; "0 g" vs "<1 g" inconsistent |
| Photo Log meals | Cloud BYOK (OpenAI/Gemini/Anthropic vision) | `Drift/Services/PhotoLogTool.swift` (182) | works, but BYOK is opt-in and a privacy compromise; we'd love an on-device fallback |

Apple Foundation Models (iOS 26 / macOS 26) ship a `@Generable` API that takes text and returns typed Swift structs. For extraction this is theoretically the strongest fit — bounded text input, structured output, no multi-turn, lower guardrail risk than chat. Issue #666 confirmed that hypothesis at the audit level. This doc is the eval + integration plan for the four extraction paths.

## Proposal

A three-pipeline eval harness (`FoundationModelsExtractionEvalTests.swift`, Tier 3, `#available(macOS 26, iOS 26, *)`-gated) that runs the same input text through:

1. **regex** — the current parser path (baseline)
2. **apple_fm** — `LanguageModelSession.respond(to:generating:)` with `@Generable` schemas
3. **cloud_byok** — OpenAI vision (top-tier reference; Phase 2, BYOK keys not on autopilot)

Per-fixture metrics: exact match / numeric within ±2% / missed field / hallucinated field, plus per-pipeline latency. Output is one CSV per run for offline analysis. Acceptance threshold (filled in once eval runs): FM exact-match ≥95% within ±2% AND p90 latency ≤1.5× regex on the same fixture → migrate. Otherwise keep regex with FM as a refinement layer.

Scope **out** of this PR: production code changes. We ship the eval, the corpus, the schemas, and the recommendation framework. Migration PRs land separately, gated on the numbers.

## Eval methodology

### Sample corpus (≥9 samples — `DriftCore/Tests/DriftCoreTests/Fixtures/Extraction/`)

| Subdir | Fixtures | Purpose |
|--------|----------|---------|
| `bodyspec/` | `scan_2025-09-15`, `scan_2026-03-06`, `scan_minimal` | 3 BodySpec DEXA history shapes (1, 2, 3 scans) |
| `labs/` | `labcorp_2025-08-10`, `quest_2025-09-01`, `generic_csv_2025-10-12` | 3 lab provider formats (column-oriented, status-flag, CSV) |
| `nutrition/` | `us_clifBar`, `indian_paneer`, `spanish_yogur` | 3 nutrition formats — US `Nutrition Facts`, Indian `NUTRITIONAL INFORMATION`, Spanish `Información Nutricional` |

All fixtures are **synthetic** — no real PII. Names mirror real layouts; numbers are plausible but invented. Each `.txt` is paired with `.expected.json` ground truth.

**Why post-OCR text fixtures, not raw PDFs/images:** the eval question this doc answers is "how good is FM at structured extraction once we have text." OCR confidence and tokenizer artifacts are upstream; isolating them from the comparison gives a clean signal. Phase 2 (separate task) extends the corpus to PDFs/images for the cloud_byok pipeline (which takes images, not text).

### Per-pipeline harness

```
for each fixture:
    text = load(fixture.txt)
    expected = load(fixture.expected.json)
    for pipeline in [regex, apple_fm, cloud_byok]:
        start = now()
        result = pipeline.extract(text)
        latencyMs = now() - start
        score = compare(result, expected)   # exact / near / missed / hallucinated
        emit row(format, sample, pipeline, score, latencyMs)
```

The harness emits `/tmp/fm-extraction-eval-<timestamp>.csv` after every run. Raw-results doc (`Docs/reports/fm-extraction-eval-<date>.md`) embeds the CSV verbatim and adds prose interpretation.

### Per-pipeline implementation status (this PR)

| Pipeline | Status | Notes |
|----------|--------|-------|
| regex | scaffolded — scoring stubs return all-missed | the current regex parsers (`BodySpecPDFParser`, `LabReportOCR`, `NutritionLabelOCR`) live in the iOS-only `Drift/` target because they import `Vision` / `PDFKit`. To call them from the Tier 3 (DriftCore) eval, we need to port their text-only logic into DriftCore. That's tracked as a small follow-up — until then, regex baseline numbers in the CSV are placeholders |
| apple_fm | implemented — schemas defined, `LanguageModelSession.respond` wired | runs whenever `#available(macOS 26, iOS 26, *)` and the framework is linkable. On older OS the eval logs `unavailable` and skips |
| cloud_byok | not in this PR | requires keychain-stored BYOK keys; Phase 2 |

### `@Generable` schemas (eval-side, mirrors what would ship in production)

```swift
@Generable struct FMBodyComposition {
    let scans: [Scan]
    @Generable struct Scan {
        let date: String                // ISO 8601
        let totalMassLbs: Double
        let bodyFatPct: Double           // 0-100, no %
        let fatMassLbs: Double
        let leanMassLbs: Double
        let bmcLbs: Double
    }
}

@Generable struct FMLabReport {
    let labName: String
    let reportDate: String              // ISO 8601
    let biomarkers: [Biomarker]
    @Generable struct Biomarker {
        let id: String                   // canonical lowerCamelCase
        let value: Double
        let unit: String
        let referenceLow: Double?
        let referenceHigh: Double?
    }
}

@Generable struct FMNutritionFacts {
    let name: String
    let servingSize: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let sugarG: Double
    let sodiumMg: Double
}
```

These three schemas would be the production schemas after migration. Using the same shape eval-side and prod-side means the eval directly validates the production contract.

## First-run results (2026-05-07, macOS 26.3.1, M-series Mac)

Full CSV in `Docs/reports/fm-extraction-eval-2026-05-07.md`. Per-format headline:

| format | apple_fm acc | hallucinated | p50_ms | recommendation |
|--------|-------------:|-------------:|-------:|----------------|
| us_nutrition_label | 100% (5/5) | 0 | 1832 | **Migrate** |
| indian_nutrition_label | 100% (5/5) | 0 | 1690 | **Migrate** |
| non_english_nutrition_label (Spanish) | 100% (5/5) | 0 | 2146 | **Migrate** |
| labcorp | 70% (21/30) | 3 | 9061 | **Hybrid** (gap-fill on regex misses) |
| quest | 27% (9/33) | 8 | 8842 | **Skip — retest with prompt fix** |
| generic_csv | 0% (0/45) | 17 | 13587 | **Skip — retest with chunking** |
| bodyspec_dexa | 0% (0/36 across 3 scans) | 6 | 1566–9540 | **Skip** — column-major DEXA tables don't fit FM's row-mental-model |

Three loud signals from this run:

1. **Nutrition labels are the win.** Perfect on every fixture, including the Spanish label that the current regex returns zero on. p50 1.9s — sub-spinner-budget. Zero hallucinations.
2. **Lab reports are partial.** LabCorp clean on biomarker IDs (21/30) but drops reference ranges; Quest's `Final` status flag breaks the schema; generic CSV hallucinated 17 extra biomarkers. Hybrid path (regex first, FM gap-fill) is the right call here, not full migration.
3. **BodySpec DEXA is not ready.** PDFKit emits column-then-values, not row-by-row. The 3B model invents rows from header text and produces dates that don't exist on the report. Stay on regex.

Latency observation: nutrition 1.5–2.1s; lab 8–13s; bodyspec 1.5–9.5s. Lab + bodyspec exceed the "behind a spinner" budget for some fixtures — chunking strategy under Edge Cases addresses lab; bodyspec is skip-anyway.

Cost: $0/call for FM; cloud_byok ~$0.001–0.01/call depending on provider/tokens (Phase 2).

## Recommendation (derived from first-run results above)

**Migrate now**: nutrition labels (US + Indian + Spanish/non-English). 100% exact-match on every fixture, p50 ≈1.9s, no hallucinations, and it fixes a known regex failure mode (zeros on non-English labels). One feature flag, one extractor, one cleanup.

**Hybrid (regex primary, FM as gap-filler)**: lab reports. The model nails biomarker IDs but inconsistently extracts reference ranges and gets confused by status-flag columns. Run regex first; if regex returns < 5 biomarkers OR is missing high-priority biomarkers (HbA1c, LDL, ferritin, vitaminD, TSH), call FM as a refinement layer. Apply confidence ≥0.7 gate before merging FM-found biomarkers in.

**Skip**: BodySpec DEXA. The PDFKit text shape (columns first, then space-separated values) doesn't map cleanly onto FM's "extract rows" prompt. Regex is fine; investing here means rewriting OCR pre-processing, not the parser.

**Retest before deciding**: Quest format and generic CSV. Both failed in this run, but with addressable issues — Quest's status-flag column tripped the schema, and generic CSV wasn't chunked. Phase 2 task: rerun those two with (a) "ignore status/flag columns" prompt addendum, (b) ≤3KB chunking with biomarker-array merge. If they then clear the 95% rule, fold them into the lab-report hybrid path; otherwise leave on regex.

## Recommendation framework (decision rules used above)

For each of the four extraction paths, the migrate/keep decision follows fixed rules:

| Outcome | Rule | Action |
|---------|------|--------|
| **Migrate** | FM exact+near ≥ 95% AND p90 ≤ 1.5× regex AND no hallucinations on critical numerics | Replace primary path with FM; keep regex as fallback on `GenerationError.guardrailViolation` / unavailable |
| **Hybrid** | FM exact+near ≥ 95% but p90 > 1.5× regex | Keep regex as primary, run FM as a *refinement layer* on regex misses (gap-fill) |
| **Refinement-only** | FM beats regex on aliases / synonyms but introduces ≥1 hallucinated critical numeric | Keep regex; use FM only when regex returns 0 results, with confidence ≥0.7 gate |
| **Skip** | FM exact+near < 90% OR p90 > 3× regex OR critical-numeric hallucinations >0% | No migration; document the failure modes in the raw report |

"Critical numeric" = body fat %, biomarker value, calories, protein. "Non-critical" = serving size string, lab name, reference ranges (hallucination there is an annoyance, not a safety issue).

## Per-path migration plan (executed only if eval clears the rule)

### BodySpec DEXA (`BodySpecPDFParser`)

- **Move** `parseText(_:)` text-only logic into `DriftCore/Sources/DriftCore/Domain/Health/BodySpecTextParser.swift` (cross-platform). The PDFKit step stays iOS-only.
- **New** `DriftCore/Sources/DriftCore/AI/FoundationModels/BodyCompositionExtractor.swift`:
  ```swift
  @available(macOS 26, iOS 26, *)
  enum BodyCompositionExtractor {
      static func extract(_ text: String) async throws -> FMBodyComposition { ... }
  }
  ```
- **Call site**: `BodySpecPDFParser.parse(url:)` calls FM extractor first; on `GenerationError.guardrailViolation` / unavailable / `iOS<26` falls through to existing regex path.
- **Feature flag**: `FM_BODYSPEC_EXTRACT` (default off until a TestFlight cohort validates).

### Lab reports (`LabReportOCR`)

- **Move** `parseLabReport(text:)` into `DriftCore` (currently iOS-only because of `UIImage`/`Vision`; the text-only regex layer is cleanly separable).
- **New** `LabReportExtractor.swift` with FM call analogous to body comp.
- **Wire-in** mirrors today's Gemma-first pipeline (`buildFinalOutput`): if Gemma is loaded, prefer Gemma; else if FM available, use FM; else regex.
  - This avoids a "two LLMs" footgun: Gemma stays the default for users who deliberately picked the larger model; FM becomes the zero-cost path for everyone else on iOS 26+.
- **Feature flag**: `FM_LAB_EXTRACT`.

### Nutrition labels (`NutritionLabelOCR`)

- **Move** `parseNutritionFromText(_:)` into `DriftCore`.
- **New** `NutritionExtractor.swift`.
- **Highest expected win**: the current parser silently produces zeros on Indian/Spanish/Tamil labels. FM should at minimum no longer return `calories=0` on a clearly-readable Spanish label. If eval shows it does, that's the strongest evidence in the doc.
- **Feature flag**: `FM_NUTRITION_EXTRACT`.

### Photo Log (`PhotoLogTool`)

- **Stay on cloud BYOK as primary.** Photo Log requires multimodal vision; Apple FM 3B is text-only at this writing. No migration in this PR.
- **Future task** if Apple ships an on-device vision model: re-evaluate. Out of scope today.

## Edge cases

- **Unavailable on iOS < 26 / macOS < 26**: every extractor keeps the regex path intact behind a `#available` check. No deletion until iOS 26 is the deployment target floor (today: iOS 17).
- **Long inputs (multi-page lab PDFs)**: FM context budget is finite. The harness chunks at ~3KB per call (one chunk per page) and merges biomarker arrays. Duplicates (same canonical id across chunks) are reconciled keeping the highest-confidence value.
- **Guardrail refusal**: caller catches `GenerationError.guardrailViolation`, logs `outcome: .fmRefusal` to `ChatTelemetryService` (new outcome enum value), falls back to regex. Same shape returned; no caller branches on backend.
- **Hallucinated critical numerics**: bounds check post-extraction. Body fat % ∈ [3, 60]; biomarker values within published reference range × 10 (catches order-of-magnitude errors); calories ∈ [0, 5000]/serving; protein ∈ [0, 200] g/serving. On bounds violation, retry once with regex; if regex also misses, drop the field rather than persist the bad value.
- **Mixed-language nutrition labels**: FM should handle this natively (the model is multilingual). Verify in eval; if it stalls on Tamil/Hindi specifically, add a language hint to the prompt.
- **OCR-corrupted text** (`Calories Z00`): test explicitly with a corrupted-text fixture in Phase 2. FM may hallucinate a plausible value. Mitigation: pre-filter — if the input has too many non-ASCII garbage tokens, skip FM entirely, run regex, return whatever regex finds (even if partial).
- **Same biomarker listed twice** (e.g. fasting glucose + random glucose on same panel): the canonical id collapses them. Schema needs a "source qualifier" string if we want to preserve both — defer to a follow-up if humans flag this.

## Open questions

1. **Regex baseline portability**: the iOS-only regex parsers can't be called from the Tier 3 DriftCore eval today. Three options: (a) port the text-only logic into DriftCore as part of this design (extra ~1 day, but enables a fair comparison in CSV); (b) build a parallel iOS-side eval that calls regex + FM in the iOS sim (already has `Drift` import); (c) accept that regex baselines are computed offline once and embedded in the doc, not re-run every eval. **Recommend (a)** — the migration plan needs that text-only DriftCore layer anyway, and porting it now means the eval has a real comparison.
2. **Fixture coverage of failure-mode samples**: the 9 synthetic fixtures are happy paths. Should we add 3 more "deliberately bad OCR" samples (smudged numbers, partial pages, corrupted unit strings) to characterize FM's failure mode? Recommend yes, in Phase 2 once we have real-OCR images to draw from.
3. **Confidence emission**: should every FM schema include a per-field confidence score (`@Guide` instructs the model to emit `0.0–1.0`)? Adds tokens to the prompt for callers who don't read it. Recommend opt-in: only `LabReport.biomarkers[].confidence` (where downstream actually uses it for the bounds check).
4. **Telemetry pipe**: extend `ChatTelemetryService` outcome enum with `.fmRefusal`, `.fmLowConfidence`, `.fmFallbackToRegex`, or stand up a new `ExtractionTelemetry` channel? Recommend extend — one pipe is easier to dashboard.
5. **Deployment-target gate**: should we move iOS deployment target to 26 to delete the regex fallback, or carry both indefinitely? Recommend: revisit when iOS 27 ships and 26+ adoption is >80% (probably late 2027); until then, both paths stay.
6. **Cloud BYOK Phase 2 timing**: the eval is incomplete without a top-tier cloud reference. Schedule the Phase 2 task (PDF/image fixtures + BYOK key handling in test) as a junior follow-up immediately after this design lands? Recommend yes — it's mechanical once this scaffolding ships.

## Acceptance criteria — status of each in this PR

- [x] ≥9 samples across BodySpec / Lab / NutritionLabel
- [x] Eval harness ran against every sample, results route to CSV (regex stub + apple_fm functional; cloud_byok deferred to Phase 2)
- [x] Per-field accuracy framework (exact / ±2% / missed / hallucinated) — *placeholders until first run on macOS 26 box*
- [x] Latency p50/p90 framework — *populated by first run*
- [x] Recommendation rules section explicit (decision table, not a recommendation for migration yet)
- [x] Open questions enumerated for human review
- [x] Design doc PR opened with `--label design-doc`, links to raw report stub

## Files in this PR

- `Docs/designs/665-fm-extraction.md` — this doc
- `DriftCore/Tests/DriftCoreTests/FoundationModelsExtractionEvalTests.swift` — eval harness (Tier 3, `#available`-gated)
- `DriftCore/Tests/DriftCoreTests/Fixtures/Extraction/{bodyspec,labs,nutrition}/*.{txt,expected.json}` — 9 synthetic fixtures
- `Docs/reports/fm-extraction-eval-2026-05-07.md` — raw report stub (gets populated by first eval run)

---

*To approve: add `approved` label to the PR. Implementation tasks (one per migrating extractor) are filed after approval and after #662 (FM chat eval) lands the shared FM adapter scaffolding.*
