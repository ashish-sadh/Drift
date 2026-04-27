# Product Review — Cycle 7689 (2026-04-26)

## Executive Summary

Since cycle 7484, Drift shipped all 4 remaining failing-query category closures (historical dates, calorie goal, macro goal progress, micronutrients), the `weight_trend_prediction` analytical tool, context-aware IntentClassifier tie-break, and a time-weighted EMA weight trend algorithm (build 178). AI chat is at its most reliable state to date. Critical gaps remaining: `supplement_insight` + `food_timing_insight` (2 of 5 analytical tools needed for "AI health coach" positioning), USDA Phase 2 (15+ cycles deferred), and the planning session crash costing human time every 6 hours.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 178 | +4 since build 174 |
| Tests | 2,061+ iOS + DriftCoreTests (0.1s) | +DriftCore migration complete |
| Food DB | 2,511 | flat (multiple cycles) |
| AI Tools | 20 | flat |
| Analytical Tools | 3/5 | +1 (weight_trend_prediction) |
| Failing Query Categories | 0 open | -4 (all closed this cycle) |
| P0 Bugs Fixed | 4 failing-query categories | ✅ |
| Sprint Velocity | ~85% on P0 | strong P0 execution, P1 slip persists |

## What Shipped Since Last Review (Cycle 7484)

- **All 4 failing-query categories closed**: historical date queries ("how many calories last Tuesday?"), calorie goal setting ("set my calorie goal to 2000"), macro goal progress ("am I hitting my protein goal?"), micronutrient tracking (fiber/sodium/sugar on FoodEntry). Highest-trust sprint in Drift history — these are exactly the queries week-1 users test.
- **`weight_trend_prediction` analytical tool** (#463): "When will I reach 75kg?" — linear regression on 30-day weight log, projected date + weekly rate + confidence (R²). Third analytical tool. Forward-looking coaching queries now work.
- **Time-weighted EMA weight trend v2** (build 178): Two-window endpoint slope + adaptive band widening. Weight chart is more accurate on short windows, less jumpy on noisy data.
- **Context-aware IntentClassifier tie-break** (#449): "add 50" during a meal logging session resolves to a food edit without ambiguous clarification prompt. ConversationState.phase injected into classification to resolve close-scored intents silently.
- **DriftCore pure-logic test migration**: All pure-logic tests moved from iOS simulator (30s) to `swift test` (0.1s warm). FoodLoggingGoldSetTests now practical to run every session.
- **FoodLoggingGoldSet pass** + LLM prompt quality audit (cycles 7485 sprint) — routing quality maintained.

## Competitive Analysis

- **MyFitnessPal:** Today tab redesign (April 2026) backfiring — user complaints that food logging now takes more taps, diary harder to find ([coverage](https://piunikaweb.com/2026/04/24/myfitnesspal-new-update-complaints/)). This is a concrete competitive gift while it lasts. Free tier: full food DB + GLP-1 tracker + streaks. AI photo scanning + recipe import remain Premium+ ($20/mo). Opportunity: explicitly market "log lunch in one sentence" vs MFP's 4-tap flow in next TestFlight release notes.
- **Whoop:** Behavior Trends live April 2026 ([whoop.com](https://www.whoop.com/us/en/thelocker/2026-whats-new/)) — behavior→Recovery correlation after 5+ "yes" + 5+ "no" logs. Women's Health blood panel (11 biomarkers, cycle-hormone integration). This is the analytical correlation pattern our `supplement_insight` and `food_timing_insight` implement. Every cycle they stay queued, Whoop's version becomes the user's mental model for this feature.
- **MacroFactor:** April 6 update added step-informed Expenditure Modifier + goal-based calorie adjustments ([release notes](https://macrofactorapp.com/release-notes/)). April 20: program generation improvements, reps-first ordering, exercise DB updates. Workouts app (Jan 2026) deepening with muscle set counts in program editor. $72/year vs our $0 + BYOK-optional.
- **Boostcamp:** No major April updates. Still gold standard for exercise video content — Drift remains text-only on exercise instructions.
- **Strong:** No major updates. Minimal focused UX is their moat.

## Product Designer Assessment

*Speaking as the Product Designer persona (Docs/personas/product-designer.md):*

### What's Working

1. **Failing-query closures are trust-restoration done right.** Closing all 4 categories in one sprint is the pattern: pick the queries week-1 users test, close them systematically, verify with gold set. "How many calories last Tuesday?" and "am I hitting my protein goal?" now work correctly. These are relationship-defining moments — users who get wrong answers at week 1 don't reach week 2.

2. **Context-aware tie-break is invisible and correct.** "Add 50" mid-meal-log resolves correctly without any friction. This is the right design principle: every ambiguity the system can resolve from context should be resolved silently. Users feel smarter; the app looks smarter.

3. **Weight trend analytics deliver the coaching moment.** "When will I reach 75kg?" with a projected date + confidence is exactly the forward-looking question that transforms a data logger into a health coach. Time-weighted EMA adds credibility when data is sparse or noisy.

### What Concerns Me

1. **Food DB flat at 2,511 for multiple cycles is a silent daily loss.** Users who don't find their meal log it in MFP and habitually return there. The compound loss is invisible — they don't file bugs, they just stop logging in Drift. USDA Phase 2 (#345) has been deferred 15+ cycles. This is the most persistent unaddressed product gap.

2. **`supplement_insight` and `food_timing_insight` are unshipped while Whoop Behavior Trends is live.** We're 3/5 analytical tools toward "AI health coach" positioning. Whoop is already marketing "see how your habits affect your recovery." Every cycle these stay queued, Whoop's version cements as the mental model. These must be the #1 SENIOR priority — no exceptions.

3. **MFP Today tab backfire is a brief competitive window that's closing.** User complaints are fresh now. Our TestFlight release notes should explicitly say "log your lunch in one sentence — no 4-tap diary required." This is a PR opportunity that expires when MFP ships a fix.

### My Recommendation

Ship `supplement_insight` + `food_timing_insight` next senior session — they are architectural clones of `weight_trend_prediction` and the Whoop parity window is open right now. Then add a hard deadline for USDA Phase 2 (cycle 7750 or close the issue). After these, the "AI health coach" milestone is reachable in one more sprint.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (Docs/personas/principal-engineer.md):*

### Technical Health

Architecture is clean. The 6-stage pipeline is well-isolated with per-stage eval coverage: StaticOverrides → IntentClassifier → DomainExtractor → ToolExecutor → Presenter → Fallback. DriftCore migration is delivering — `swift test` at 0.1s makes the gold set gate practical, not theoretical. Context-aware tie-break (#449) was implemented correctly: ConversationState.phase read as a copied value before LLM inference, not a captured reference — thread-safety maintained. Macro goal and micronutrient changes follow established migration patterns: nullable columns, COALESCE aggregation, log-time backfill only.

### Technical Debt

1. **Planning session crash (#407) deferred 10+ cycles.** Exit hook timing when DOD isn't cleanly reached causes crashes requiring human manual restart every 6 hours. Root cause is identified; fix is in planning-service.sh exit path. This is not optional infra debt — it actively degrades the autonomous loop reliability.

2. **State.md at build 174, actual at build 178.** Four builds behind after one planning session. State.md staleness has been flagged in 6+ consecutive reviews. Require State.md refresh as first task of every sprint — not reactive.

3. **`supplement_insight` and `food_timing_insight` are low-risk architectural clones.** Both reuse `InsightResult: Codable` schema. SupplementService has adherence/streak/gap query methods already. FoodService needs one new `mealTimingByPeriod()` query. Neither requires new infrastructure — deferral is a planning failure, not a technical risk.

4. **FoodLoggingGoldSet has no coverage for the 4 newly-fixed failing-query categories.** Features shipped without eval coverage can silently regress. Task #470 must close this gap — 12 new cases for historical date, calorie goal, macro goal progress, and micronutrient queries.

5. **USDA DEMO_KEY in production** is a pre-launch blocker accumulating silently. 1000 req/hr is fine for TestFlight; App Store load will hit limits immediately.

### My Recommendation

Fix planning crash (#407) first — 2 hours, isolated to planning-service.sh, and it recovers the autonomous loop's reliability. Then `supplement_insight` + `food_timing_insight` — both are low-risk, same pattern as `weight_trend_prediction`. Run FoodLoggingGoldSetTests with the 12 new cases (#470) to verify the failing-query category closures are eval-verified, not just assumed.

## The Debate

**Designer:** Next sprint must close the Whoop parity gap. Whoop Behavior Trends is live now — behavior→Recovery correlation is exactly `supplement_insight`. We're 2 analytical tools away from credible "AI health coach" positioning. Every cycle these stay queued, Whoop's version cements as the mental model. Ship `supplement_insight` + `food_timing_insight` as P0 SENIOR. Simultaneously: TestFlight release notes with the MFP "one sentence vs 4 taps" messaging while the window is fresh.

**Engineer:** Agree on the analytical tools — both are architectural clones, minimal risk. But the planning crash (#407) is blocking reliable autonomous operation and has been deferred 10+ cycles. It's 2 hours of focused work. Sequence: (1) planning crash fix, (2) supplement_insight, (3) food_timing_insight, (4) FoodLoggingGoldSet +12 for the 4 fixed categories. State.md refresh (#472) and failing-queries.md refresh (#473) as junior parallel track. USDA Phase 2 — start with a batch import script for top 500 USDA foods (no runtime API calls), junior task, ships this sprint.

**Designer:** Agreed on sequencing. The planning crash fix recovers the autonomous loop for free — it's not competing with product features, it's enabling them. And batch import for top 500 USDA foods is exactly the right first step — USDA JSON dumps → foods.json, no new infrastructure, closes the most-common "not found" cases. Start there, proactive search tier in the next sprint.

**Engineer:** One more note: `supplement_insight` and `food_timing_insight` must each ship with their own eval cases (5+ per tool) in the same commit — not filed as follow-up tasks that slip. Ship incomplete features is this project's #1 eval coverage debt pattern.

**Agreed Direction:** (1) Planning crash fix (SENIOR, 1 session), (2) `supplement_insight` with 5+ eval cases (SENIOR, 1 session), (3) `food_timing_insight` with 5+ eval cases (SENIOR, 1 session), (4) FoodLoggingGoldSet +12 for fixed failing-query categories (JUNIOR), (5) USDA batch import top 500 foods script (JUNIOR), (6) State.md + failing-queries.md refresh (JUNIOR). TestFlight release notes with MFP competitive messaging on next build.

## Decisions for Human

1. **USDA Phase 2 deadline.** Food DB at 2,511 for multiple cycles is the most persistent product gap. Batch import approach (USDA JSON dumps → foods.json, no runtime API calls) can ship in one junior session. Should we make this a firm commitment this sprint, or defer further? Recommendation: commit to batch import this sprint; proactive search tier in the next.

2. **TestFlight release notes framing.** MFP's Today tab redesign complaints are fresh. Should the next TestFlight build include explicit competitive messaging ("log your lunch in one sentence — no 4-tap diary required")? Recommendation: yes, this is a brief competitive window.

3. **USDA API key registration.** The DEMO_KEY will hit rate limits before App Store launch. Takes 5 minutes to register a free key at fdc.nal.usda.gov. Should the human do this now? Recommendation: yes — do it before it becomes a launch blocker.

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
