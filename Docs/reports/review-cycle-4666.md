# Product Review — Cycle 4666 (2026-04-16)

Review covering cycles 3776–4666. Previous review: cycle 3776 (Review #43, PR #132).

## Executive Summary

The multi-stage LLM pipeline shipped completely — all 8 phases closed, gold set holding at 100%, TestFlight build 125 delivered. Smart Units made the largest cumulative improvement in the product's history: 340+ foods moved off "serving" in batch 3, another 100+ rules added in batch 4 (eggs/benedict fix, seafood, supplements, African/Korean/Latin items). Food DB crossed 2,000. However, the end of this sprint brought a sharp regression: 4 P0 AI chat bugs filed in one session, pointing to over-pruning of StaticOverrides as the likely root cause. The new sprint corrects course — fix the regression first, then implement LLM-first lab report parsing (#74) which is approved and ready.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 125 | +3 from last review |
| Tests | 1,539 | +218 from last review |
| Food DB | 2,046 | +232 from last review |
| AI Tools | 20 | stable |
| AI Eval | 55-query gold set, 100% baseline | stable |
| P0 Bugs Fixed | 3 (fiber 0g, edit ingredient, calories-left misroute) | |
| P0 Bugs Opened | 4 (AI chat regression) | regression |
| Sprint Velocity | 100% (8/8 pipeline tasks closed) | |

## What Shipped Since Last Review

- **Multi-stage pipeline fully shipped** — All 6 stages live: input normalization, StaticOverrides, LLM intent classifier, domain-specific extraction, Swift validation, streaming presentation. Intent classifier replaced keyword matching on the Gemma 4 path.
- **Swift validation stage (PR #136)** — Validates LLM-extracted parameters before execution. Catches type errors, missing required fields, nonsensical values.
- **Smart Units batch 3** — 340 foods moved from "serving" to natural units. Indian flatbreads, chaat, curries, condiments, beverages, fruits, vegetables. "Serving" count dropped from 1,311 to 971.
- **Smart Units batch 4** — 100+ new rules. Egg/benedict disambiguation, seafood (shrimp/prawns/shellfish/pomfret), supplements (collagen/greens/gummies/psyllium), African staples, Korean/Filipino/Latin dishes, branded soft drinks, medium fruits.
- **Smart Units in AI chat** — Confirmation card and recipe builder now use `smartServingText()`. "log 2 dosas" shows "2 piece" not "2.0 serving."
- **Food DB: 2,046 foods** — +232 across Indian regional (Maharashtrian, Odia, Bihari, Rajasthani, Andhra, Karnataka, Goan, Himachal Pradesh, Northeast India, Sindhi, Coorg), Vietnamese, Latin American, African, Italian expanded, branded protein bars/shakes, Bengali fish, Indian snacks/drinks, Filipino, Turkish, Ethiopian.
- **3 P0 bugs fixed** — Fiber always showing 0g (#142), edit ingredient showing wrong amount (#143), "calories left" answering food search (#135).
- **Lab reports design doc** — PR #114 approved and merged. LLM-first parsing architecture documented and ready for implementation.

## Competitive Analysis

- **MyFitnessPal:** Cal AI integration deepening — 20M food DB remains the benchmark. Premium AI features (meal scan, voice log) moving behind paywall at $20/mo. Our free on-device stack remains a differentiator.
- **Boostcamp:** Still the gold standard for exercise content (videos, muscle diagrams). No AI chat features. Gap on exercise visuals persists.
- **Whoop:** AI Strength Trainer now accepts text AND photo → structured workout. AI Coach has conversation memory. Cloud-based. Our privacy moat is the counter.
- **Strong:** Clean, minimal, stable. No AI movement. MFP and MacroFactor are eroding this space.
- **MacroFactor:** Workouts app expanding with Jeff Nippard video content and auto-progression at $72/year. Growing into exercise. Our counter: free, on-device, all-in-one conversation.

## Product Designer Assessment

*Speaking as the Product Designer persona (Docs/personas/product-designer.md):*

### What's Working

- **Smart Units is the most user-visible quality leap since chat cards.** "2 dosas" meaning "2 dosas" instead of "2.0 serving" is what separates a prototype from a product. Users who eat Indian food — which is the primary user — no longer do mental math. Batch 3 + 4 together touched ~440 foods. This is real quality improvement.
- **Pipeline architecture is now sound.** Six stages, gold set at 100%, Swift validation layer catching LLM extraction errors before they reach users. The foundation for AI quality is solid.
- **Food DB at 2,046 is a real database.** Still nowhere near MFP's 20M, but the Indian coverage is now genuinely better than MFP for the primary user's diet. That's the niche we own.

### What Concerns Me

- **4 P0 regressions filed in a single session is a red flag.** Daily summary trying to log food named "daily summary," weekly summary broken, "log 2 eggs" adding egg benedict — these are failures on queries that should be bedrock. The intent classifier is not reliably routing clear-intent queries. Somewhere in the StaticOverrides pruning or the LLM classifier prompt, we broke things that were working.
- **Exercise tab is still text-only.** We approved design doc #66 many reviews ago. Boostcamp and MacroFactor are both investing in exercise visuals. We have 960 exercises with zero images. This is the longest-standing gap that hasn't been addressed.
- **No TestFlight user feedback loop.** Build 125 is on TestFlight. We don't know if real users are hitting the AI regression bugs before we do.

### My Recommendation

Fix the AI chat regressions before anything else. A daily summary that logs food named "daily summary" is a trust-destroying failure. Then implement lab reports LLM parsing — the design doc is thorough and approved, the architecture maps cleanly to the pipeline we just built. Exercise visuals must get a real implementation slot in the sprint after that, not just a research task.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (Docs/personas/principal-engineer.md):*

### Technical Health

The 6-stage pipeline is architecturally clean. StaticOverrides handles deterministic fast-path (60-70% of queries), intent classifier handles ambiguous classification, domain extractors handle parameter extraction, Swift validation provides a safety net. The separation of concerns is correct. Test count at 1,539 is healthy; the +218 from last review mostly covers new pipeline stages.

The regression bugs are almost certainly from over-pruning StaticOverrides. The pipeline design called for pruning to ~10 essential patterns, but the previous StaticOverrides were handling cases (daily/weekly summary routing, egg-type disambiguation) that the LLM classifier isn't reliably reproducing. The fix isn't to restore all the old patterns — it's to identify exactly which LLM classifications are failing and either fix the prompt or restore specific StaticOverrides entries for those cases.

### Technical Debt

- **AIChatView.sendMessage at ~491 lines** — unchanged since last review. The pipeline refactor was the right time to decompose this, and it didn't happen. This needs to be a named task, not just "someday."
- **Smart Units is a 1,100-line function** — `smartUnit(for:)` has grown through batches 1-4 into a complex rule chain. The structure is correct (specific before general, with clear section comments), but it needs periodic audits as edge cases accumulate. The eggs/benedict disambiguation in batch 4 is evidence the rules interact in unexpected ways.
- **Report date defaulting to today** — The lab reports bug (all reports uploaded in one session show the same date) was called out in the design doc but hasn't been fixed yet. This is a real data accuracy issue — two reports from different months appear as the same day. High priority in #151.

### My Recommendation

The P0 regression bugs (#147-150) should block everything else. Run the 55-query gold set immediately after fixing — don't declare done until the baseline is restored. For lab reports implementation (#151), the chunked LLM extraction pattern maps directly to how we do domain extraction in Stage 3. The implementation risk is medium: OCR text is messier than chat input, and hallucination detection via regex cross-check adds complexity. Build the validation layer carefully before shipping to TestFlight.

## The Debate

**Designer:** The regression is embarrassing but fixable. My bigger concern is pattern: we've now seen two cycles where the AI pipeline shipped something that broke previously-working behavior. StaticOverrides pruning broke daily/weekly summary. What's the gate for "this is safe to prune"?

**Engineer:** The gate was supposed to be the 55-query gold set. But the gold set didn't include summary query routing tests, or they weren't sufficient. The fix is to expand the gold set to cover every query category that StaticOverrides previously handled. Before we prune anything again, we need coverage for the thing being pruned.

**Designer:** Agreed. And for lab reports — I want the accuracy warning banner to be genuinely non-dismissible on first upload, not just visible. Medical data is in play. If a user saves wrong cholesterol values because they didn't notice the warning, that's a serious trust violation.

**Engineer:** That's already in the design doc. I'll make it a named test case: banner must be present and non-dismissible before the save button is reachable. Also: the report date fix (extract from document, not `Date()`) is equally important — silent data quality bugs in the biomarker history view are worse than visible failures.

**Designer:** One more thing: exercise visuals can't be research-only forever. At some point we have to pick a source and ship. Wger has Apache-licensed images. Let's make the research task time-boxed — two cycles to evaluate sources, then a go/no-go decision.

**Engineer:** Fair. I'll add a decision point in the sprint board: after #140 research completes, we decide whether to ship static images from Wger or keep deferring.

**Agreed Direction:** Fix AI regressions first with an expanded gold set as the gate. Implement lab reports LLM parsing per the approved design doc. Exercise visuals research is time-boxed with a go/no-go decision at completion, not an indefinite defer.

## Decisions for Human

1. **AI chat regression root cause:** The P0 bugs (#147-150) appear to be from StaticOverrides over-pruning. Should we restore specific patterns for summary/weekly routing as a quick fix, or invest in better LLM prompt tuning for the classifier? Restoring patterns is faster but adds back keyword brittleness we were trying to remove.

2. **Exercise visuals go/no-go:** After the research task (#140) completes, do you want to review the sources and make the call yourself, or should the autonomous loop pick the best-licensed source and ship? Wger has Apache-licensed exercise images that could be bundled in the app without network requests.

3. **Lab reports date picker UX:** When both regex and LLM fail to find the report date, the design calls for a date picker in the preview UI. Should this block saving (user must set a date) or allow saving with today's date as fallback? Blocking prevents duplicate-date bugs but adds friction.

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
