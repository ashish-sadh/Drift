# Product Review — Cycle 7484 (2026-04-26)

## Executive Summary

Since cycle 7448, Drift closed 2 of the 4 critical failing-query categories (historical weekday queries, calorie goal setting), completed the DriftCore pure-logic test migration enabling 0.1s test loops, and shipped the weight_trend_prediction analytical tool. The AI pipeline is measurably faster to iterate on, and the "trust restoration" sprint is working — but micronutrient tracking and macro goal progress remain open. Next focus: close those last two failing-query categories, add 2 more analytical tools to make the AI coach positioning credible, and fix the P0 combo delete bug.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 176 | +2 since cycle 7448 |
| Tests | 2,061 iOS + DriftCore (macOS 0.1s) | +DriftCore tier 0 migration |
| Food DB | 2,511 | flat (0 net adds) |
| AI Tools | 20 (+ weight_trend_prediction) | +1 analytical |
| Analytical Tools | 3 (cross_domain, weight_trend, wired) | +1 this cycle |
| P0 Bugs Fixed | 2 (historical date, calorie goal) | 1 open (#465) |
| Failing Query Categories Closed | 2/4 since cycle 5965 | ↑ |
| Sprint Velocity | ~60% (3/5 cycle 7448 tasks) | recovering |

## What Shipped Since Last Review

- **Historical weekday queries fixed** — "what did I eat last Tuesday?" now resolves to the correct date using `weekdayDateString()` + `historicalDaySummary()`. Previously returned today's data, a visible trust failure.
- **Calorie goal setting fixed** — "set my calorie goal to 2000" works via `WeightGoal.calorieTargetOverride` in StaticOverrides. Users can now set calorie targets through chat.
- **Micronutrient tracking** (#442) — fiber, sodium, sugar now stored on FoodEntry via DB migration v35. Nullable columns with COALESCE aggregation for pre-migration rows.
- **Macro goal progress queries** (#441) — "am I hitting my protein goal?" compares today's intake vs goal. Depends on #440 (non-weight goal setting) which also shipped.
- **Non-weight goal setting** (#440) — "set protein target to 150g" writes to `calorieGoal`/`proteinGoal` fields in UserPrefs.
- **DriftCore pure-logic test migration** — All pure-logic tests moved from iOS simulator (30s) to `swift test` (0.1s warm). The "run gold set every session" directive is now practical, not aspirational.
- **weight_trend_prediction analytical tool** (#463) — "at this rate, when will I reach 75kg?" returns trend rate, projected date, confidence (R²), and graceful fallbacks for <7 entries or no goal set.
- **FoodLoggingGoldSet pass** — "I'd like to add" conversational prefix miss fixed; gold set passing.
- **Build 176 on TestFlight** — shipped.

## Competitive Analysis

*Based on most recent competitive intelligence from product-designer and principal-engineer personas (through April 2026):*

- **MyFitnessPal:** Today tab redesign (April 2026) is backfiring — user complaints that food logging now takes more taps. This is a concrete competitive gift: while MFP adds friction, Drift's chat-first removes it. MFP's entire AI/coaching stack is behind Premium+ ($20/mo); their Cal AI integration adds cloud photo scanning. Our privacy + free + on-device moat is the differentiator.
- **Boostcamp:** Still the gold standard for exercise visual content — videos, muscle diagrams, Jeff Nippard programming. Drift's exercise vertical remains text-only. Exercise visual enrichment is a known gap.
- **Whoop:** Behavior Trends (habit → Recovery correlation after 5+ entries) went live April 2026 — directly competing with our analytical tools roadmap. Their AI Coach has conversation memory + contextual guidance (cloud-based). Our `cross_domain_insight` and `weight_trend_prediction` are on-device equivalents at $0 cost. Need 2 more analytical tools to close this perceived gap.
- **Strong:** Minimal, focused workout logging UX remains their moat. No notable changes this review cycle.
- **MacroFactor:** Deepening all-in-one story — Favorites for serving sizes, Expenditure Modifiers, Apple Health write coming. $72/year vs our free tier. Their coaching is paid; ours is free + BYOK-optional.

## Product Designer Assessment

*Speaking as the Product Designer persona (Docs/personas/product-designer.md):*

### What's Working

1. **Trust restoration is measurable.** Two failing-query categories closed in one sprint means users who test "what did I eat Tuesday?" or "set my calorie goal" now get correct answers. This is exactly the "close the queries users test in week-1" principle — early trust failures end relationships before they start.
2. **DriftCore test migration removes the biggest execution bottleneck.** The "run FoodLoggingGoldSetTests every session" product focus was aspirational with 30s simulator boot. At 0.1s, it's just a step. AI quality now has the same fast-feedback loop as pure logic code.
3. **Analytical tools are building the health coach identity.** Three tools (cross_domain_insight, weight_trend_prediction, and the new suite) are moving the product toward forward-looking insight. "At this rate, when will I hit 75kg?" is a coach question, not a logger question.

### What Concerns Me

1. **Food DB at 2,511 has been flat for multiple cycles.** USDA Phase 2 (#345) stays in queue while users hit "not found" daily. Every "not found" moment is a MFP escape. We lose logging sessions before we lose users — and we never notice because they don't file bugs. The compound loss is silent and compounding.
2. **Macro goal progress (#441) and micronutrient tracking (#442) shipped but are unverified in the gold set.** We marked the tasks done, but there's no explicit eval coverage for "am I hitting my protein goal?" queries. If the implementation is incomplete, users get a technically-shipped but functionally-broken feature. Gold set cases for these categories must be this sprint.
3. **P0 bug #465 (no delete option on combo detail/preview)** — combo is a first-class domain object. Every domain object needs full CRUD in the UI. A user who created a combo they don't want is stuck with it. This is an activation-phase bug: users who explore the feature hit a dead end. Fix first.

### My Recommendation

Close the AI chat quality loop: add 10+ gold set cases for the 4 recently-fixed failing-query categories, fix #465 immediately, and ship `supplement_insight` as the 4th analytical tool. The "AI health coach" positioning becomes defensible at 5 analytical tools — we're at 3. Every sprint that passes without adding one is a sprint where Whoop widens the gap.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (Docs/personas/principal-engineer.md):*

### Technical Health

The DriftCore migration is the most architecturally significant improvement of the past 50 cycles. Pure logic tested at 0.1s vs 30s changes the feedback loop from "maybe later" to "always." The 5-tier test map in CLAUDE.md is clear and being followed — Tier 0 for pure logic, Tier 1 for simulator-only needs. 

The 6-stage pipeline is clean: StaticOverrides handles 60-70% instantly, LLM classifier handles ambiguity, per-stage eval harness provides attribution. The macro goal and micronutrient changes (DB migration v35) follow established patterns — nullable columns, COALESCE aggregation, log-time backfill only.

### Technical Debt

1. **State.md shows build 174, but actual is 176.** Two builds behind already. State.md staleness is a chronic issue — was flagged in 6+ consecutive reviews. Need a junior task each cycle to keep it current or it misleads planning AI.
2. **Planning session crash pattern (#381, #354, #407, #408) is still unresolved.** Six consecutive crashes with human manual restart as workaround. Root cause (exit hook timing when DOD isn't cleanly reached) was identified but not fixed. This is infra debt that costs one human interaction per planning cycle.
3. **USDA DEMO_KEY still in production.** Fine for TestFlight; will hit rate limits on App Store launch. Pre-launch blocker accumulating silently.
4. **Queue at 59 open tasks, SENIOR queue ~20.** At 5 tasks/session that's 4 senior sessions to drain SENIOR backlog. Manageable but any new SENIOR additions >2 per cycle will start growing again.

### My Recommendation

Fix the planning session crash pattern this sprint — it's been deferred 10+ cycles and costs human time every planning cycle. Prioritize `supplement_insight` as the next analytical tool (same InsightResult schema, SupplementService already has the query methods). Run FoodLoggingGoldSetTests explicitly for the 4 newly-fixed categories — if coverage is missing, add it before claiming those categories as "closed."

## The Debate

**Designer:** We need to close the AI coach gap with Whoop now. They shipped Behavior Trends in April — that's the same analytical correlation pattern as our `supplement_insight` and `food_timing_insight`. Every cycle those stay unshipped, Whoop claims "we show you how habits affect your health" and we don't. The positioning window is closing. Ship two analytical tools and gold set cases for the fixed failing-query categories this sprint.

**Engineer:** Agree on analytical tools — but the planning crash bug has been deferred 10+ cycles and costs human time every cycle. That's the infra debt I want fixed first. Also: macro goal progress and micronutrient tracking shipped but their eval coverage doesn't exist. If those features are broken in edge cases (nil goal, pre-migration rows returning wrong fiber numbers), users will experience exactly the trust failures we were trying to close. Fix the eval gap before claiming victory on cycle 5965's sprint.

**Designer:** Fair on eval coverage — add 12 gold set cases for the 4 fixed categories as a P0-priority task. But the planning crash is watchdog infra, not product quality — don't let it pull senior budget from the analytical tools. Junior can own gold set cases. Senior owns analytical tools and the crash fix as parallel tracks.

**Engineer:** Agreed. Split it: SENIOR claims (1) supplement_insight analytical tool and (2) planning crash fix. JUNIOR claims (3) gold set +12 for fixed categories, (4) failing-queries.md refresh, (5) State.md refresh to build 176. And #465 (delete combo) is a JUNIOR fix — it's a context menu addition, not an architecture change.

**Agreed Direction:** Ship `supplement_insight` as the 4th analytical tool (closes Whoop parity gap), fix #465 combo delete, add 12+ gold set cases to verify the 4 fixed failing-query categories, and fix the planning crash exit path. No new analytical tools added to queue until supplement_insight ships.

## Decisions for Human

1. **Food DB stagnation.** The food DB has been flat at 2,511 for multiple cycles. USDA Phase 2 (#345) would give access to 400k+ verified foods but has been deferred 15+ cycles. Options: (a) prioritize #345 this sprint as a SENIOR task — it's the highest-ROI food quality investment available; (b) continue deferring until analytical tools sprint is complete. Recommendation: set a hard deadline — ship by cycle 7600 or cut from roadmap.

2. **Analytical tools pace.** Whoop Behavior Trends is now live. We have 3 analytical tools; need 5 for "AI health coach" positioning. At current rate (1 per sprint), that's 2 more sprints. Options: (a) make analytical tools the only SENIOR priority for the next 2 sprints; (b) continue mixed sprint allocation. Recommendation: make `supplement_insight` + `food_timing_insight` the P0 SENIOR priority — they've been deferred 8+ planning cycles.

3. **Planning crash fix scope.** The exit hook timing issue has caused 6+ planning session crashes requiring manual restart. It's watchdog/infra work (~2 senior hours). Options: (a) fix this sprint as SENIOR P1; (b) document the manual restart workaround and defer. Recommendation: fix it — it's costing human time every 6 hours.

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
