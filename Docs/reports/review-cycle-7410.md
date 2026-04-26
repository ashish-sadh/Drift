# Product Review — Cycle 7410 (2026-04-25)

## Executive Summary
Drift is in its strongest technical shape since the codebase began: DriftCore extraction complete (pure logic builds on macOS in 0.1s), 5-tier test architecture operational, per-stage AI eval coverage across all 6 pipeline stages. The gap is execution breadth — 4 known failing query categories (#439–#442) are still open, the analytical tool suite needs 2 more entries to credibly claim "AI health coach" positioning, and the queue hygiene crisis (110 tasks) consumed this planning cycle's energy. Build 175 ships today; next sprint must be 100% AI chat quality wins.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 175 | +1 since last review (174 was last shipped) |
| Tests | 2,091 (2,061 iOS + 30 macOS) | ↑ from ~1,677 at cycle 3200 |
| Food DB | 2,511 | ↑ from ~1,532 at cycle 3200 |
| AI Tools | 20 | ↑ from 10 at cycle 3200 |
| Queue Health | 60 tasks | ↓ from 110 (pruned 50 this cycle) |
| Per-tool Reliability | 96% (48/50) | ↑ from untracked |
| Failing Query Categories | 4 open | Unchanged from cycle 5965 |

## What Shipped Since Last Review (Cycle 3200)

- **6-stage AI pipeline** — InputNormalizer → IntentClassifier → DomainExtractor → Swift validation → tool execution → stream presentation. 55-query gold set at 100% baseline, per-stage isolated eval coverage.
- **Analytical AI tools** — `cross_domain_insight`, `weight_trend_prediction`, `glucose_food_correlation`, `sleep_food_correlation`. Four cross-domain correlation tools. Users can ask "when will I reach my goal?" and "does rice spike my glucose?"
- **DriftCore module extraction** — All pure logic in a cross-platform Swift package. macOS `swift test` at 0.077s warm vs 27s on iOS simulator.
- **5-tier test architecture** — Each test file belongs to exactly one tier; inner loop is now instant for pure logic changes.
- **Per-tool reliability eval** — 50-query gold set per top tool. log_food 100%, log_weight 100%, mark_supplement 100%, edit_meal 90%, food_info 90%. Overall 96%.
- **PhotoLog multi-provider** — Anthropic + OpenAI + Gemini BYOK. Provider fallback chain in queue.
- **Confirmation cards across all 8 health domains** — Food, weight, workout, navigation, supplement, sleep, glucose, biomarker.
- **Voice input** — On-device SpeechRecognizer, partial/final transcription handling, health-term post-processing repair.
- **Harness reliability fixes** — Sessions now reach task loop reliably; gh errors no longer swallowed; atomic state writes.

## Competitive Analysis

*Based on most recent intelligence from persona learning log:*

- **MyFitnessPal:** Cal AI acquired (Mar 2026, 15M downloads, $30M ARR), ChatGPT Health integrated. 20M food DB. Photo-to-log, voice log, Blue Check dietitian recipes behind Premium+ ($20/mo). GLP-1 tracking. Redesigned Today tab. Their cloud AI is table stakes but behind paywall. Our moat: free, on-device, privacy-first BYOK model.
- **Boostcamp:** Still the gold standard for exercise content — videos, muscle diagrams, detailed instructions. We match on 873+ exercises but text-only. Their content depth is hard to replicate without budget.
- **Whoop:** Behavior Trends (habits → Recovery correlation, April 2026) is live. This is the same pattern as our analytical tools suite. AI Coach now has conversation memory and contextual guidance ($30/mo). Whoop is pulling ahead on the "AI coach" positioning while our `supplement_insight` and `food_timing_insight` sit in queue.
- **Strong:** Remains clean and minimal — their UX speed for set/rep entry is the bar. No AI ambitions publicly. Our AI chat logging is faster than their manual entry for multi-exercise sessions.
- **MacroFactor:** Launched Workouts app (Jan 2026) — auto-progression, cardio, Apple Health write, AI recipe photo logging ($72/year). All-in-one is now their angle too. Our edge: free, on-device, privacy-first. Their adaptive TDEE is still their killer feature; we reverted our equivalent.

## Product Designer Assessment

*Speaking as the Product Designer persona:*

### What's Working
- **AI pipeline is production-quality.** 96% per-tool reliability across the top 5 tools is a real number, not a hope. The 6-stage pipeline with per-stage eval means failures are attributable, not mysterious.
- **DriftCore extraction unlocks speed.** The inner loop for AI changes is now 0.1s vs 27s. This means senior sessions can iterate on pipeline logic 270x faster. This is a velocity multiplier, not just a code quality win.
- **Analytical tools are the right category.** `weight_trend_prediction` ("when will I reach my goal?") is exactly the forward-looking coaching question that turns a logger into a coach. Four analytical tools live. Whoop's Behavior Trends launched in April 2026 doing the same pattern — we're parallel, not behind.

### What Concerns Me
- **4 failing query categories still open.** "How many calories last Tuesday?" returning today's data is a trust-eroding failure. "Set my protein goal to 150g" silently not working is worse. These are the queries users try first when they hear "AI chat" — we fail them. This is cycle 5965's sprint and they're still open at cycle 7410. Every cycle they stay unfixed, user trust erodes.
- **Analytical tools stopped at 4.** `supplement_insight` (#417) and `food_timing_insight` (#418) have been in queue since cycle 4815 — 2595 cycles without shipping. Whoop Behavior Trends launched in April 2026 with the exact same habit→outcome correlation pattern. We have 4 analytical tools; we need 5+ for "AI health coach" to be a defensible positioning claim. We're at the 1-yard line and have been for months.
- **Feedback vacuum.** Five+ consecutive cycles with zero user-filed bugs or feature requests. Either TestFlight dogfooding has paused or the feedback loop is broken. Settings → Feedback row (#329) is still in queue. Without user signal, we're building in the dark.

### My Recommendation
Fix the 4 failing query categories first (#439–#442). These are trust-eroding failures on core queries. Then ship `supplement_insight` (#417) and `food_timing_insight` (#418) to complete the analytical suite. These two sprints, done back-to-back, get us to the "AI health coach" milestone. Don't add new food DB or new analytical tools until these two sprints ship cleanly.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona:*

### Technical Health
- **Architecture: Excellent.** DriftCore extraction is the right boundary — iOS-only seams (HealthKit, Widget, Speech, OCR) are properly isolated. Adapter pattern (`HealthDataProvider`, `WidgetRefresher`) is clean. No DDD violations in recent work.
- **Test coverage: Good.** 5-tier architecture with tier assignment per file is the right discipline. macOS `swift test` at 0.077s means Tier 0 tests run on every save. The 2,091 test count covers all major pipeline paths. LLM eval at ~160+ cases gives confidence in AI routing changes.
- **6-stage pipeline eval: Complete.** All stages now have isolated gold sets (StaticOverrides, IntentClassifier, DomainExtractor, per-tool, pipeline E2E, latency). This is the eval infrastructure I've been pushing for since Review #40. Every future AI change has a measurement framework.
- **Technical debt: Minimal.** Main open items: context window still at 2048 tokens (State.md stale vs actual 4096), missing `pieceSizeG` overrides on ~2,000 foods (bulk enrichment script queued), USDA DEMO_KEY still in prod (fine for TestFlight, latent risk at App Store).

### Technical Debt
- **State.md reflects build 174 but says 2048 token context.** The actual context may be 4096 (post-build-130-era bump). State.md #431 was on close list this cycle. CLAUDE.md says 2048 but `DriftCore/AI` may have been updated. Senior sessions reading stale State.md make wrong architectural assumptions.
- **`/debug last-failures` must be DEBUG-only.** The `#if DEBUG` gate requirement from PE cycle 5965 learning hasn't shipped yet (#447 is still queued). Release builds with debug routes are an App Store risk.
- **Historical date query failures are service-layer gaps, not prompt gaps.** `food_info` handler needs Calendar arithmetic for relative dates. This is 30-50 lines of Swift, not prompt work. The same pattern applies to macro goal queries (#440, #441) — service migration first, then wiring to chat. Strict ordering: #440 → #441.
- **DB migration v35 (micronutrients) must nil-guard historical rows.** `fiber_g ?? 0.0` at aggregation layer. Backfilling is wrong — historical accuracy is unknowable. Guard the reads, not the backfill.

### My Recommendation
The 4 failing query fixes (#439–#442) are all service-layer changes, not prompt work. Historical dates need Calendar arithmetic in the food_info handler; macro goals need a DB migration v35 + UserPrefs extension; micronutrients need migration v36 with nil-safe reads. Order of operations is strict: #440 (schema + UserPrefs) before #441 (queries that read the schema). Do these two sprints, then ship the analytical tool pair (#417, #418) which are fully independent.

## The Debate

**Designer:** The 4 failing query categories have been on the roadmap since cycle 3022. We're now at cycle 7410 — that's 4400 cycles. "How many calories last Tuesday" is a basic question. Every time a user tries it and fails, they learn not to trust the AI. We fix these first, full stop. No new analytical tools, no new food DB until these ship.

**Engineer:** Agreed on the failing queries — they're all service changes (Calendar arithmetic, DB migrations), not risky AI prompt work. The strict ordering matters: #440 before #441, because #441 reads the columns #440 creates. On the analytical tools: `supplement_insight` and `food_timing_insight` are architecturally cheap — they reuse the InsightResult schema from `weight_trend_prediction`, and both SupplementService and FoodService already have the query methods needed. These can run in parallel with junior food DB work; they don't conflict. Risk: the micronutrient migration (#442) and the analytical tools both touch FoodEntry. Serialize those two, do them in separate sessions.

**Designer:** Fair. But I want a hard commitment: failing queries ship in the next senior session, not "this sprint." Senior budget is 5 tasks per session. The four fixes (#439, #440, #441, #442) plus the test additions (#443) is exactly 5. Done in one session, gold set validated. Then the next senior session is analytical tools. No drift between the two sprints.

**Engineer:** Agreed — one session for the 4 failing-query fixes + gold set, next session for analytical tools. I'll add the threading constraint as a comment on #441: "Depends on #440 landing in same session or prior." One more thing: the harness still has a crash-on-exit pattern from the last planning session. That's an infra blocker if it happens mid-sprint. #407 should be investigated in the first few lines of the failing-query session, not deferred.

**Agreed Direction:** Fix all 4 failing query categories (#439–#442) plus gold set (#443) in a single senior session. Then ship `supplement_insight` + `food_timing_insight` (#417, #418) in the next. These two sessions complete both the "trust" and "analytical coach" milestones. Harness crash investigation (#407) runs alongside as the first task of the failing-query session.

## Decisions for Human

1. **Analytical tools priority:** `supplement_insight` (#417) and `food_timing_insight` (#418) have been queued ~2600 cycles. Should these become P0 for the VERY NEXT senior session after failing-query fixes, or is there other work they should yield to? Whoop Behavior Trends shipped in April 2026 with the exact same pattern.

2. **TestFlight feedback:** Zero user-filed bugs/requests for 5+ cycles. Is dogfood testing paused? Should we send a direct ask to TestFlight testers this build?

3. **USDA DEMO_KEY:** Still in production. Not urgent for TestFlight but must be resolved before App Store submission. Any timeline on App Store launch that would make this urgent now?

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
