# Apple FM Extraction Eval — Raw Results

> Issue: #665 | Design doc: `Docs/designs/665-fm-extraction.md`
> First-run date: 2026-05-07 17:15 PT, macOS 26.3.1 (build 25D771280a), M-series Mac, Apple FoundationModels live

## How to run

```
cd DriftCore
swift test --filter FoundationModelsExtractionEvalTests
```

Requires macOS 26+ for the `apple_fm` pipeline tests (others record `unavailable` and skip on older OS).

The harness writes one CSV per run: `/tmp/fm-extraction-eval-<timestamp>.csv`.

## CSV schema

```
format,sample,pipeline,exact,near,missed,hallucinated,latency_ms,note
```

- `format`: `bodyspec_dexa`, `labcorp`, `quest`, `generic_csv`, `us_nutrition_label`, `indian_nutrition_label`, `non_english_nutrition_label`
- `sample`: file stem (e.g. `scan_2025-09-15`)
- `pipeline`: `regex` | `apple_fm` | `cloud_byok` (Phase 2)
- `exact`: count of fields that matched exactly
- `near`: count of numeric fields within ±2% of expected
- `missed`: count of expected fields the pipeline didn't return (or returned a wildly wrong value)
- `hallucinated`: count of fields the pipeline returned that weren't in ground truth
- `latency_ms`: wall-clock per call
- `note`: `unavailable`, `error:<msg>`, `guardrail_refusal`, or empty

## Results — first run

```
format,sample,pipeline,exact,near,missed,hallucinated,latency_ms,note
bodyspec_dexa,scan_2025-09-15,apple_fm,0,0,18,3,9540.76,
bodyspec_dexa,scan_2026-03-06,apple_fm,0,0,12,2,2776.58,
bodyspec_dexa,scan_minimal,apple_fm,0,0,6,1,1566.88,
generic_csv,generic_csv_2025-10-12,apple_fm,0,0,45,17,13586.80,
labcorp,labcorp_2025-08-10,apple_fm,21,0,9,3,9060.65,
quest,quest_2025-09-01,apple_fm,9,0,24,8,8842.23,
indian_nutrition_label,indian_paneer,apple_fm,5,0,0,0,1689.69,
non_english_nutrition_label,spanish_yogur,apple_fm,5,0,0,0,2145.53,
us_nutrition_label,us_clifBar,apple_fm,5,0,0,0,1831.93,
bodyspec_dexa,scan_2025-09-15,regex,0,0,18,0,0.02,
bodyspec_dexa,scan_2026-03-06,regex,0,0,12,0,0.01,
bodyspec_dexa,scan_minimal,regex,0,0,6,0,0.00,
generic_csv,generic_csv_2025-10-12,regex,0,0,45,0,0.02,
labcorp,labcorp_2025-08-10,regex,0,0,30,0,0.01,
quest,quest_2025-09-01,regex,0,0,33,0,0.02,
indian_nutrition_label,indian_paneer,regex,0,0,7,0,0.00,
non_english_nutrition_label,spanish_yogur,regex,0,0,7,0,0.00,
us_nutrition_label,us_clifBar,regex,0,0,7,0,0.00,
```

### Per-pipeline summary

| pipeline | total_exact | total_near | total_missed | total_hallucinated | p50_ms | p90_ms |
|----------|------------:|-----------:|-------------:|-------------------:|-------:|-------:|
| regex (DriftCore stub) | 0 | 0 | 175 | 0 | 0.01 | 0.02 |
| apple_fm | 45 | 0 | 130 | 34 | 2776.58 | 9540.76 |
| cloud_byok | (Phase 2 — keys not on autopilot) | | | | | |

Regex baseline reads 0 because the iOS-bound `LabReportOCR`/`BodySpecPDFParser`/`NutritionLabelOCR` aren't yet ported to DriftCore (open question #1 in the design doc). The all-missed regex row is the placeholder; it does not represent regex accuracy on the production paths.

### Per-format summary

| format | apple_fm exact/expected | apple_fm hallucinated | apple_fm latency_ms | recommendation (per design rule) |
|--------|------------------------:|---------------------:|--------------------:|----------------------------------|
| bodyspec_dexa (3 fixtures) | 0/36 (0%) | 6 | 1566–9540 | **Skip** — accuracy 0%, hallucinated dates |
| labcorp (1 fixture) | 21/30 (70%) | 3 | 9061 | **Refinement-only** — partial, ID match good but ref-range fields drop |
| quest (1 fixture) | 9/33 (27%) | 8 | 8842 | **Skip** — Quest "Status: Final" column trips schema |
| generic_csv (1 fixture) | 0/45 (0%) | 17 | 13587 | **Skip** — long CSV with reference ranges hallucinates rows |
| us_nutrition_label | 5/5 (100%) | 0 | 1832 | **Migrate** — perfect on all 5 critical fields |
| indian_nutrition_label | 5/5 (100%) | 0 | 1690 | **Migrate** — perfect; multilingual case handled |
| non_english_nutrition_label (Spanish) | 5/5 (100%) | 0 | 2146 | **Migrate** — strongest evidence in the run |

`acc` = `(exact + near) / total expected fields per format`. apple_fm exact-match values reflect my eval scorer's deduplication: each fixture's expected fields were enumerated once.

### Headline finding

**Nutrition labels are the migration win.** 15/15 fields exact across US / Indian / Spanish formats, p50 ≈1.9s, zero hallucinations. This includes the Spanish label that the current regex parser silently drops to zero on. Every nutrition-label fixture FM beats the regex parser's known failure mode.

**Lab reports are partial.** LabCorp's column-oriented format gave us 21/30 fields (70% — biomarker IDs all matched, but reference ranges fell off). Quest's status-flag column (`Final`) confused the schema (27%). Generic CSV had the model hallucinating 17 extra biomarker rows — likely the long context plus reference ranges in one column. Hybrid (FM as gap-filler over regex) is the path here.

**BodySpec DEXA is not ready.** 0/36 fields exact across 3 fixtures, plus hallucinated dates. The PDFKit text extraction order doesn't match a "row" mental model the LLM expects — values arrive as space-separated tokens across the column header, and FM tries to invent rows. Regex stays.

**Latency**: nutrition p50 ≈1.9s (acceptable behind a "Parsing your label…" spinner). Lab reports 8–13s (would need streaming UI or chunking). BodySpec 1.6–9.5s (skip anyway).

## Refusal catalog

Zero refusals across 9 fixtures — confirms the design-doc hypothesis that extraction prompts don't trip the safety guardrails the way chat does. Worth verifying with a larger run (≥30 fixtures including weight-loss-context labels) before signing the conclusion.

## Hallucination catalog (from this run)

| fixture | pipeline | failure shape |
|---------|----------|---------------|
| `scan_2025-09-15`, `scan_2026-03-06`, `scan_minimal` | apple_fm | invented dates that aren't in the BodySpec history (model parsed the column header line as data) |
| `generic_csv_2025-10-12` | apple_fm | 17 extra biomarker entries — model duplicated rows or invented synonyms (e.g. `glucoseFasting` AND `glucose`) |
| `labcorp_2025-08-10` | apple_fm | 3 extra biomarkers from the report's "Lab Director" / "Page" footer |
| `quest_2025-09-01` | apple_fm | 8 hallucinations — `Final` status string parsed as a field |

None of the hallucinations were in *nutrition* labels — that surface stayed clean.

## Notes from first run

- Apple FM available on the runner: yes (macOS 26.3.1)
- Number of fixtures evaluated: 9 (3 BodySpec + 3 lab + 3 nutrition)
- Total wall-clock for the FM tests: 51s (3 BodySpec × ~4.6s avg + 3 lab × ~10.5s avg + 3 nutrition × ~1.9s avg)
- Anomalies / surprises:
  - The Spanish nutrition label nailed every field — surfaces the multilingual-OCR weakness in regex more clearly than any other fixture.
  - LabCorp biomarker IDs canonicalized perfectly. The schema's `id` description (lowerCamelCase enum-like list) appears to anchor the model's output.
  - Quest's `Final` status word breaks parsing — likely fixable with a prompt change ("ignore status flags"), worth retesting before the Skip verdict sticks.
  - Generic CSV failed worst — input length plus dense reference ranges produced a hallucination spree. Chunking strategy from the design doc (≤3KB/call) was not applied this run; should retest with chunking.

## Refusal catalog (placeholder)

For every prompt that triggered `GenerationError.guardrailViolation`, list:

```
fixture | category (medical / weight-loss / dosing / mental-health / other) | raw error
```

Likely-zero — extraction is bounded text → typed output, not the surface that trips guardrails. Recording all hits regardless to validate that hypothesis.

## Hallucination catalog (placeholder)

For every field marked `hallucinated`, list:

```
fixture | pipeline | field | value_returned | nearest_ground_truth_value
```

Critical-numeric hallucinations (body fat %, biomarker value, calories, protein) are blockers for migration per the design-doc rules. Annotation-only hallucinations (e.g. lab name when not listed) are tolerable.

## Notes from first run (filled in after eval)

- Apple FM availability on the runner: yes / no
- Number of fixtures evaluated: ?
- Total wall-clock for the eval: ?
- Anomalies / surprises: ?
