# Design: Improve Lab Reports with LLM Parsing

> References: Issue #74

## Problem

Lab report parsing relies on regex pattern matching across 83 biomarker aliases with line-by-line extraction. This works for standard Quest/Labcorp formats but fails on:
- Non-standard lab formats (international labs, hospital reports, specialty panels)
- OCR artifacts (broken lines, merged cells, garbled text)
- Biomarkers not in the alias list (new tests, niche panels)
- Reports where values are in different positions than expected

Currently the LLM is a fallback: if regex finds <10 results, Gemma gets the OCR text and tries to extract more. This misses the opportunity to use LLM as the primary parser with regex as validation.

## Proposal

Make the on-device LLM (Gemma 4) the primary lab report parser. Feed it the full OCR text with a structured extraction prompt. Use the existing 71 biomarker definitions as the schema — LLM maps extracted values to known biomarker IDs. Regex becomes validation (unit checking, range sanity) rather than extraction.

**In scope:**
- LLM-first parsing pipeline for Gemma 4 devices
- Structured extraction prompt with biomarker schema
- Multi-pass extraction (chunked for 2048 context window)
- Confidence scoring per extracted value
- Regex validation layer (unit normalization, range checks)

**Out of scope:**
- New biomarker definitions (71 is sufficient)
- Cloud-based parsing
- Camera capture / live OCR (stays with file picker)
- SmolLM parsing (too small for structured extraction)

## UX Flow

**Current flow (unchanged):**
1. User taps "Upload Lab Report" → picks PDF/image
2. Processing spinner with progress
3. Preview of extracted biomarkers → user confirms → save

**What changes under the hood:**

```
PDF/Image
    |
    v
OCR (Vision framework — unchanged)
    |
    v
LLM Extraction (NEW primary path)
  Gemma 4 receives OCR text in chunks (~500 tokens each)
  Prompt: "Extract biomarker results. Return JSON array."
  Schema: list of known biomarker IDs + expected units
  Returns: [{id, value, unit, refLow, refHigh, confidence}]
    |
    v
Regex Validation (existing, repurposed)
  Verify units match expected (mg/dL not mg/L for cholesterol)
  Sanity check ranges (glucose 40-500, not 4000)
  Normalize units (mmol/L → mg/dL conversions)
    |
    v
Merge & Deduplicate
  LLM results + any regex catches LLM missed
  Highest confidence wins on conflicts
    |
    v
Preview → Save (unchanged)
```

**SmolLM fallback:** Devices without Gemma 4 use regex-only path (current behavior).

## Technical Approach

### LLM extraction prompt (~200 tokens system)

```
Extract lab results from this report. Return JSON array.
Each result: {"id":"biomarker_id","value":NUMBER,"unit":"UNIT","refLow":NUMBER,"refHigh":NUMBER}
Known biomarkers: [compact list of 71 IDs with expected units]
Only extract values you're confident about. Skip headers, dates, patient info.
```

### Report date extraction

The report date must be read from the document itself, not defaulted to today. Lab reports contain the collection or result date (e.g. "Collection Date: 03/14/2026" or "Report Date: 14-Mar-2026").

**Current bug:** All uploaded reports are stored with `date = Date()` (today), meaning three reports uploaded in one session all appear as the same date even if they span months.

**Fix in this design:**
- Add a date extraction pass: before biomarker extraction, run a lightweight regex scan (and LLM fallback) to find the report date
- Regex patterns: `Collection Date:`, `Report Date:`, `Date:`, `Collected:`, plus common date formats (MM/DD/YYYY, DD-Mon-YYYY, YYYY-MM-DD)
- If regex finds a date → parse and use it as the report date
- If regex fails → ask LLM in first chunk: "What is the date of this lab report? Return as YYYY-MM-DD. If no date found, return null."
- If LLM also fails → show date picker in preview UI so user can enter it manually
- `LabReportResult` struct gains a `reportDate: Date` field (replaces implicit `Date()`)

### Chunked processing

OCR text from a full lab report can be 2000-5000 tokens. With 2048 context window:
1. Split OCR text into ~500-token chunks (by line breaks, not mid-line)
2. Each chunk gets the same system prompt + chunk text
3. Merge results across chunks, deduplicate by biomarker ID
4. ~3-4 LLM calls per report, ~12-15s total (acceptable for a one-time import)

### Confidence scoring

LLM returns confidence per value. Low confidence triggers:
- Regex cross-check (does this value appear near this biomarker name in raw text?)
- Unit validation (is this the expected unit for this biomarker?)
- Range sanity (is this physiologically possible?)

Values below confidence threshold shown with warning icon in preview.

### Files that change

| File | Change |
|------|--------|
| `Services/LabReportOCR.swift` | Add LLM-first extraction path, chunk splitting, merge logic |
| `Services/LabReportOCR+Biomarkers.swift` | Repurpose as validation layer (unit checks, range sanity) |
| `Services/IntentClassifier.swift` or new `LabReportParser.swift` | LLM extraction prompt + response parsing |
| `Models/BiomarkerResult.swift` | Add `confidence: Double?` field |

### Format expansion

With LLM parsing, format support expands automatically:
- International formats (SI units, different lab layouts)
- Hospital discharge summaries (biomarkers embedded in text)
- Specialty panels (hormone panels, allergy panels)
- No new regex patterns needed per format

## Edge Cases

- **Gemma 4 not available (SmolLM device):** Fall back to regex-only (current behavior). No regression.
- **OCR quality very poor:** LLM extraction returns few/no results. Regex fallback catches what it can. User sees "X biomarkers found" and can manually add missing ones.
- **LLM hallucination:** Returns biomarker values not in the OCR text. Regex validation cross-checks against raw text. Values not found in raw text flagged as low confidence.
- **Very long report (20+ pages):** Chunk limit of 10 chunks (~5000 tokens). Excess pages skipped with warning.
- **Duplicate biomarkers across chunks:** Deduplicate by biomarker ID, keep highest confidence value.

## UX: Accuracy Warning

LLM parsing is probabilistic — values can be misread, especially from poor OCR or unusual formats. Users must not make medical decisions based on unverified AI-parsed values.

**Implementation:**
- Show a persistent banner in the lab report preview screen: "Values extracted by AI — verify against your original report before saving."
- Banner uses the warning color (Theme.surplus/amber), not dismissible on first upload
- After saving, biomarker entries from LLM-parsed reports show a subtle "AI-parsed" badge in the biomarker history view
- This is a non-negotiable UX requirement — privacy-first + accuracy-honest

## Open Questions

1. **Should users see confidence scores?** Could show a subtle indicator (checkmark vs warning) next to each extracted value. Helps users verify important results. Recommend: yes, show in preview before save.
2. **Should we support photo capture (camera) in addition to file picker?** Camera capture would make it easier to scan physical printouts. Vision framework handles camera images already. Recommend: add as follow-up, not in this design.
3. **Token budget for biomarker schema:** Listing all 71 biomarker IDs + units in the prompt is ~150 tokens. Could trim to top 40 most common. Recommend: include all 71 — fits in budget and avoids missing niche biomarkers.

---

*To approve: add `approved` label to the PR. To request changes: comment on the PR.*
