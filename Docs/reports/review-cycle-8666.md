# Product Review — Cycle 8666 (2026-05-02)

## Executive Summary

Since review cycle 8581, Drift finally closed the most persistent product gap across three consecutive reviews: both `supplement_insight` and `food_timing_insight` analytics engines are now live with working response cards. The analytical tool suite stands at 5 active tools (supplements, food timing, weight trends, cross-domain insights, glucose-food correlation) — enough to defensibly claim "AI health coach" positioning. Food DB expanded to ~3,150 with 7 new cuisine batches including deep European and Asian coverage. Two test failures (#568, #569) remain open on main and need immediate closure.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 200 | +3 since cycle 8581 |
| Tests | ~2,252 (iOS ~1,219 + DriftCore ~1,033) + LLM eval ~160+ | flat |
| Food DB | ~3,150 | +210 (~7 batches of 30 since build 197) |
| AI Tools | 21 registered | flat |
| Analytical Tools Active | 5 (cross_domain, weight_trend, glucose_food, supplement_insight, food_timing_insight) | +2 engines shipped |
| P0 Bugs Fixed | 0 | — |
| Sprint Velocity | ~80% (8/10 sprint 8581 items closed) | ↑ from 60% |

## What Shipped Since Last Review

- **supplement_insight analytics engine** (#565) — "How consistent am I with my creatine?" now returns adherence %, streak, and gap report. Previously routed but silently failed.
- **food_timing_insight analytics engine** (#566) — Meal timing patterns, average meal time per period, late-night eating detection. "When do I usually eat dinner?" is now a real query.
- **Recent foods quick-log** (#573) — Food search shows most-logged foods when query is empty. Zero-friction re-log of habitual meals.
- **Indian branded protein foods +30** (#572) — MuscleBlaze, RiteBite, TrueBasics, sattu, makhana, regional whey products in DB.
- **piece_size_g fix for 20 multi-piece Indian foods** (#434) — Idli, dosa, roti, and 17 more now have correct per-piece weight instead of 100g default.
- **Food DB expanded across 6 cuisine categories** — Mediterranean & Levantine (+30), East Asian home cooking (+30), Caribbean & island cuisine (+30), Southeast Asian (+30), German/Austrian/Swiss (+30), Greek & Balkan (+30). Total ~3,150.
- **Eval hygiene** — FoodLoggingGoldSet run (#571), failing-queries.md refreshed (#570), State.md refreshed (#567).
- **TestFlight builds 199 and 200** shipped.

## Competitive Analysis

- **MyFitnessPal:** Redesigned "Today" tab (April 2026) is backfiring — user complaints that food logging now takes more taps, diary navigation is worse. Separately, launched free GLP-1 support April 28 (medication log, dose reminders, side-effect tracking + nutrition correlation). Our competitive window on chat-first one-sentence logging remains open; GLP-1 is now a gap.
- **Boostcamp:** Launched Web Program Creator — desktop tool for building multi-week programs synced to mobile. No AI features. Still the gold standard for exercise visual content; we remain text-only on exercise.
- **Whoop:** Behavior Insights (habits → Recovery correlation with 90-day trending) is live and marketed — direct overlap with our analytical tools. Also launched Navigator band (rugged any-wear sensor). Their AI features remain cloud-only; our 5 analytical tools match the pattern on-device at $0.
- **Strong:** Minor updates — Apple Watch improvements, stability fixes. No new AI or chat features. Minimal, focused UX is still their moat.
- **MacroFactor:** Apple Watch support for on-wrist food logging. AI photo logging, micronutrient tracking, adaptive TDEE continue to deepen their all-in-one story at $72/year. Our equivalent features are free.

## Product Designer Assessment

*Speaking as the Product Designer persona (Docs/personas/product-designer.md):*

### What's Working

1. **"AI health coach" identity is now credible.** Five analytical tools covering supplements, meal timing, weight trends, cross-domain correlations, and glucose-food patterns — plus weight chart tap-to-callout and recent foods quick-log — make Drift feel like a product that learns and advises. This is a milestone tracked since review 41 (cross_domain_insight was "tool #1 of 5 needed"). We're there.
2. **Food DB is approaching parity with casual logging needs.** At ~3,150 foods with deep Indian, Asian, Mediterranean, and now Central/Eastern European coverage, the "not found" moment is rarer. Indian branded protein coverage (MuscleBlaze, sattu, makhana) is particularly high-value for the target user base — these are daily foods for serious Indian fitness users who represent our core cohort.
3. **Recent foods quick-log is the kind of friction removal users notice.** Empty search showing yesterday's oats and eggs is a 1-tap re-log instead of typing. This is the AI-first promise made concrete in a non-chat surface — no query needed for habitual meals.

### What Concerns Me

1. **Two test failures (#568, #569) are open on main.** testPortionScaling_DecimalServings (4/6 cases failing) and testRouterPrompt_TokenCeiling (6080 > 6000 chars) are quality signals that haven't been acted on. The router prompt budget violation is a correctness risk for users on 6GB devices — it cannot wait another cycle.
2. **Settings → Feedback (#329) has been deferred 9+ planning cycles.** An in-app mailto link is 30 minutes of work. We are now multiple cycles without user-filed bugs or feature requests. That silence is a structural problem: the feedback loop is broken. A product that can't hear from its users can't improve for them.
3. **GLP-1 tracking gap is growing.** MFP launched free GLP-1 support April 28. Design doc #574 exists. Every cycle without an implementation plan, MFP cements this as "theirs" in the all-in-one health category. A minimum `log_medication` tool + `DailyMedication` model is one senior session — same pattern as supplements.

### My Recommendation

Close test failures (#568, #569) immediately — these are regression signals on a released build. Ship Settings → Feedback (#329) this cycle — it has been deferred too long. File a scoped GLP-1 implementation task and treat it as P1 for the next senior session.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (Docs/personas/principal-engineer.md):*

### Technical Health

supplement_insight/food_timing_insight engines closing is architecturally significant — a tool registered without an engine produces silent failure after correct routing, which is worse UX than "command not recognized." The standing PE rule from review 8581 is validated: don't register a tool until engine + tests ship in the same PR. The InsightResult schema is shared across all 5 analytical tools; each new tool is 1–2 new service queries + a format wrapper. Architecture is clean and extensible.

DriftCore at 1,033 tests with sub-second warm runs is the right discipline. The `swift test` quality gate makes "run gold set every session" happen in practice, not just as a directive.

### Technical Debt

1. **testRouterPrompt_TokenCeiling (#569) is a prompt budget violation on main.** Router prompt at 6,080 chars + user message + response leaves < 2,000 chars headroom in SmolLM's 8K context. This affects real users on 6GB devices. The fix is prompt pruning — trim dead examples and redundant RULES wording, not just checking the ceiling in the test. Do not add eval examples to the router prompt until it's under 6,000.
2. **Planning session crash (#407) has been deferred 10+ cycles.** Human manual restart every 6 hours is operational overhead with a known root cause (planning-service.sh exit path when DOD isn't cleanly reached). Estimated fix: 2 hours. At this effort-to-cost ratio, continued deferral is irrational.
3. **State.md at build 197, actual is build 200.** Three builds stale after one planning cycle confirms the pattern. A pre-commit hook that warns when State.md's build number lags the project.yml version would make this structural problem self-correcting.

### My Recommendation

Fix #568 and #569 first (one junior session, both deterministic). Then fix planning crash #407. After that: #329 (Settings → Feedback, 30 min) + a scoped GLP-1 task using the existing supplement architecture pattern.

## The Debate

**Designer:** We've hit the analytical tools milestone — 5 tools live, Indian food parity improving, recent-foods quick-log reducing friction. The next product-level move is GLP-1 tracking. MFP launched it free April 28. Every day we wait, they entrench in that domain with free users.

**Engineer:** Agreed GLP-1 matters, but we have two test failures on main right now. A product claiming "AI health coach" with a failing prompt-ceiling test is inconsistent. testRouterPrompt_TokenCeiling isn't just a test — it means real users on 6GB devices may hit context truncation mid-conversation. Fix the foundation before expanding scope.

**Designer:** Fair — fix #568 and #569 first, no argument. But #329 (Settings → Feedback) has been deferred 9 cycles. That's a broken feedback loop, not a prioritization decision. It ships this cycle regardless. And for GLP-1: scope it small — `log_medication` tool, `DailyMedication` model, medication card. Same pattern as `mark_supplement`. One senior session. Then we have user feedback driving what comes next.

**Engineer:** Agreed on both counts. #329 is a 30-minute task that should have been done 9 cycles ago — it ships next junior session. For GLP-1: `log_medication` + `DailyMedication` + card is the right scope. Use supplement architecture: `SupplementLog` → `MedicationLog`, `mark_supplement` tool → `log_medication` tool, supplement card → medication card. No new infrastructure, proven pattern. Ship it, then let user feedback drive dose tracking and side-effect correlation.

**Agreed Direction:** (1) Close #568 + #569 immediately. (2) Ship #329 (Settings → Feedback) this junior session. (3) File a scoped GLP-1 task: `log_medication` tool + `DailyMedication` model + medication confirmation card, following supplement architecture.

## Decisions for Human

1. **GLP-1 implementation scope:** Do you want to ship a minimum `log_medication` + `DailyMedication` + card (one senior session) as a direct MFP counter, or wait for a fuller design pass on dose tracking + side effects before committing code?
2. **Food DB cap policy (#575):** Autopilot kept recreating +30 food tasks despite many pending in the queue. The infra cap task enforced a halt. Does this policy hold — no new food DB tasks until existing +30s are claimed and queue drops below 8 pending food tasks?
3. **#329 Settings → Feedback:** Should this be treated as a hard P0 for the next junior session, blocking all other work until it ships?

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
