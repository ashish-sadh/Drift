# Product Review — Cycle 8789 (2026-05-03)

## Executive Summary

Since review cycle 8666 (yesterday), Drift shipped GLP-1 medication tracking (#580) as a direct competitive response to MFP's April 28 launch, closed the router prompt token-ceiling correctness bug (#569), expanded the food DB to ~3,335 with 60 new foods across 10 cuisines, and made significant coverage gains (ExerciseService 5%→67%, TDEEEstimator 29%→55%). The core sprint from cycle 8666 is largely complete. Open gaps: #568 (decimal servings test failure), Settings → Feedback (#329, 10+ cycles), planning crash (#407), and State.md refresh (#581).

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 203 | +3 since cycle 8666 |
| Tests | ~2,252 (iOS ~1,219 + DriftCore ~1,039) | flat count, ↑ coverage |
| Food DB | ~3,335 | +185 since cycle 8666 |
| AI Tools | 23 registered | +2 (log_medication + GLP-1 infra) |
| Analytical Tools Active | 5 (cross_domain, weight_trend, glucose_food, supplement_insight, food_timing_insight) | flat |
| Coverage | ExerciseService 67%, TDEEEstimator 55%, WeightTrendCalculator 87% | ↑ all three |
| P0 Bugs Fixed | 1 (#569 router prompt ceiling) | — |
| Sprint Velocity | ~6/10 cycle 8666 items | ↓ from 80% |

## What Shipped Since Last Review

- **GLP-1 medication tracking** (#580) — `log_medication` tool + `DailyMedication` model + medication confirmation card. "I took my Ozempic" now works in chat. Direct counter to MFP's free GLP-1 launch (April 28).
- **Router prompt token ceiling fix** (#569) — Trimmed router prompt from 6,080 to under 6,000 chars. Correctness fix for users on 6GB devices where SmolLM's 8K context was at risk. Shipped in build 203.
- **Food DB +185** — Two batches of 30 in this cycle (Chinese, French, Indonesian, Afghan, British, Polish, Levantine/Moroccan, Burmese, Malaysian, Thai + Persian, Brazilian, Filipino, West African). Total now ~3,335.
- **Accessibility labels fix** (#52) — Missing VoiceOver labels on primary chat UI elements corrected.
- **Coverage gains** (#50) — ExerciseService 5%→67%, TDEEEstimator 29%→55%, WeightTrendCalculator 78%→87%. Three critical service classes now above the 50% threshold.
- **Food context freshness** (#51) — featureContext updated to reflect 3,300+ foods, reducing stale AI responses about food availability.

## Competitive Analysis

- **MyFitnessPal:** GLP-1 support deepening — Head of Nutrition content series launched May 1 as MFP doubles down on medication tracking + nutrition correlation. New Today tab redesign (Winter 2026) continues to generate user complaints about more taps required for food logging. Our one-sentence chat logging is the direct counter. Premium+ at $20/mo remains the paywall for AI features; ours are BYOK-free.
- **Boostcamp:** Minor bug fix update (April 27, 2026). Web Program Creator (desktop workout builder → mobile sync) launched last cycle. No AI features added. Still the gold standard for exercise visual content; we remain text-only on exercise instructions.
- **Whoop:** Major hardware launch — WHOOP 5.0 and MG with 14-day battery, 26x sensor capture rate, Any-Wear sensor array, and Healthspan features (WHOOP Age, on-demand ECG, Blood Pressure Insights). Behavior Insights (habits → Recovery correlation after 5+ logs) is now prominent in their marketing. Subscription tiers at $199–$359/year vs our free + BYOK model.
- **Strong:** No significant updates observed.
- **MacroFactor:** April 2026 update added recipe photo scanning improvements (snap a cookbook photo → pre-fill ingredients), contributing lifts view for muscle group Levels, warm-up management improvements, and full Jeff Nippard program upload support. Workout app deepening. $72/year; our workout + nutrition chat is free.

## Product Designer Assessment

*Speaking as the Product Designer persona (Docs/personas/product-designer.md):*

### What's Working

1. **GLP-1 tracking shipping as a competitive response is exactly right.** MFP launched free GLP-1 support April 28; we shipped `log_medication` + `DailyMedication` + medication card within the same sprint. The minimum viable scope (logging foundation, no dose tracking yet) is the right approach — ship the foundation, let user feedback drive side effects and reminders. We no longer have a GLP-1 gap.
2. **Coverage improvements on service classes are building quality in the right places.** ExerciseService at 67% (was 5%) means progressive overload, smart workout, and workout history queries now have regression protection. This is coverage that catches real bugs, not vanity numbers — these are the services that drive actual chat responses.
3. **Food DB at 3,335 with 10-cuisine additions reflects breadth the target user base now sees.** Southeast Asian, West African, European classics, and Filipino cuisines are now covered. The "not found" moment is becoming rarer for non-Western users.

### What Concerns Me

1. **Settings → Feedback (#329) is now 10+ planning cycles deferred.** This has crossed from a prioritization decision into a systemic product failure. A product that cannot hear from its users cannot improve for them. If this ships 0 more cycles it will have been deferred for 11 consecutive planning rounds. Making it P0 for next junior session is no longer a recommendation — it's a requirement.
2. **testPortionScaling_DecimalServings (#568) may still be open on main.** If it is, we have a test failure on a released build. The "two test failures on main" concern from review 8666 is only half-resolved. Portion scaling accuracy is a user-facing trust issue — 4/6 test cases failing means real decimal serving sizes are wrong.
3. **Whoop's hardware and health breadth expansion is a category-level move.** Blood Pressure Insights, ECG, Healthspan metrics, 14-day battery — this is positioning Whoop as a full health platform, not just a recovery tracker. Our analytical tool suite matches their software layer on-device, but we don't have passive sensor data. The competitive moat needs to be quality + privacy, not just parity.

### My Recommendation

Close #568 and #329 immediately in the next junior session — both are long-overdue and one is a correctness issue. Then file tasks from this review's findings: Whoop competitive response on analytical depth, GLP-1 dose reminder follow-up (let user feedback from build 203 drive scope), and a coverage run for `log_medication` tool.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (Docs/personas/principal-engineer.md):*

### Technical Health

GLP-1 tracking shipped cleanly using the supplement architecture pattern — `DailyMedication` mirrors `SupplementLog`, `log_medication` mirrors `mark_supplement`, medication card mirrors supplement card. Zero new infrastructure. This is the "boring, proven solutions" principle in practice. The InsightResult schema is available for future medication analytics when needed.

Router prompt at <6,000 chars (#569) closed the correctness risk for 6GB device users. The standing rule still applies: don't add eval examples to the router prompt without a token audit. The ceiling is a discipline checkpoint, not just a test.

Coverage improvements on ExerciseService (5%→67%) were overdue — this is a core service with progressive overload, smart workout, and workout history logic that had no regression protection. The `swift test` 0.1s loop means this coverage was added cheaply, and it will catch regressions going forward.

### Technical Debt

1. **testPortionScaling_DecimalServings (#568) status unknown.** Need to verify whether it's still open on main. If it is, 4/6 decimal serving test cases are wrong — that's not a minor failure. The fix is in ServingUnit.swift decimal quantity parsing.
2. **Planning crash (#407) has been deferred 10+ cycles at 2-hour estimated fix time.** Human manual restart every 6 hours has a real operational cost. The effort-to-cost ratio of continued deferral is irrational. This ships in the next senior session, period.
3. **State.md at build 201 while actual is 203.** Minor lag this cycle, but the structural problem persists — it's not being refreshed as part of each sprint. The pre-commit hook proposal (warn when State.md build number lags project.yml by >1) would make this self-correcting. File as an infra task.

### My Recommendation

Verify #568 status first — if still open, fix immediately (one junior session, ServingUnit.swift decimal parsing). Then #407 planning crash. These are the two highest-leverage items before new feature work.

## The Debate

**Designer:** GLP-1 is shipped. The feedback loop (#329) has been missing for 10+ cycles — that's the most urgent gap. Without in-app feedback, we're flying blind on what real users need next. It ships next junior session, full stop.

**Engineer:** Agreed on #329. But I need to verify #568 first — if testPortionScaling_DecimalServings is still failing on main, that's a data accuracy bug affecting real users. It should take 30 minutes. Check that first, then #329.

**Designer:** Fair. Both fit in one junior session — check and close #568 in the first 30 minutes, then ship #329. After that: #407 planning crash is the next senior session's first task. 10 cycles of deferral on a 2-hour fix is irrational.

**Engineer:** Agreed. After #407: a coverage run for `log_medication` tool (it shipped without eval cases, which is exactly the "ship without eval = unverified" failure mode from review 8666's standing rule). And State.md refresh as mandatory Step 0 of every sprint — file the pre-commit hook idea as an infra task.

**Agreed Direction:** (1) Junior: verify + close #568, ship #329. (2) Senior: close #407 planning crash first task. (3) File eval cases for `log_medication`. (4) File pre-commit hook for State.md lag detection.

## Decisions for Human

1. **GLP-1 next steps:** Build 203 now has `log_medication`. Do you want dose reminder notifications (smart meal reminder pattern) as the next GLP-1 task, or wait for user feedback from TestFlight before adding more medication features?
2. **Whoop competitive response:** Whoop 5.0 launched Healthspan (WHOOP Age), on-demand ECG, and Blood Pressure Insights. These are sensor-driven features we can't match on-device. Is our response a deeper analytical tool (medication adherence insights, GLP-1 + weight correlation) or a different differentiator entirely?
3. **#329 Settings → Feedback:** This has been deferred 10+ cycles. Should we make it a hard P0 that blocks all other junior work until it ships, similar to how we handled push notifications after 4 deferrals?

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
