# Product Review — Cycle 3200 (2026-04-15)

## Executive Summary

Since the last review (cycle 1750), Drift shipped voice input hardening, expanded gold set eval to 55 queries with 100% baseline accuracy, grew food DB to 1,616 entries, fixed P0 food logging confirmation flow, and published TestFlight build 120. The primary blocker is design doc #65 — the owner reviewed it and wants a fundamentally different approach (multi-stage specialized prompts, not just pipeline reorder). Sprint planning is complete and oriented around revising the design before implementation.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 120 | +1 from last review |
| Tests | 1321+ | +244 |
| Food DB | 1,616 | +84 |
| AI Tools | 20 | = |
| AI Eval | 55-query gold set, 100% baseline | NEW |
| P0 Bugs Fixed | 2 (#119 food confirmation, workout routing) | |
| Sprint Velocity | 7/10 shipped (previous sprint) | 70% |

## What Shipped Since Last Review

- **Food logging now shows confirmation before saving** — users can correct AI-parsed food before it hits the database (P0 #119)
- **Voice input edge cases hardened** — mid-sentence corrections no longer break the parser (10 new tests)
- **AI eval gold set expanded to 55 queries** — cross-domain coverage (food, weight, exercise, navigation, health, multi-turn, negatives) with 100% baseline accuracy
- **Food DB grew 1,532 → 1,616** — voice-friendly staples (common items people say aloud)
- **Workout-set queries routed correctly** — "I did 3 sets of bench" no longer misroutes to activity handler
- **TestFlight build 120 published**

## Competitive Analysis

- **MyFitnessPal:** Continuing to integrate Cal AI acquisition for photo-to-food logging. Premium+ at $20/mo adds AI meal scanning. Free tier increasingly limited (barcode now paid-only in some regions).
- **Boostcamp:** Still the gold standard for exercise content (videos, muscle diagrams). No significant AI chat features. Strength in curated training programs.
- **Whoop:** AI Strength Trainer now accepts photo/screenshot of workout plans → structured workout. Proactive AI Coach has conversation memory. All cloud-based, $30/mo.
- **Strong:** Remains minimal and focused on workout logging UX. Clean, fast, no AI ambitions. Their moat is simplicity.
- **MacroFactor:** Workouts app maturing with auto-progression and Jeff Nippard content. Expanding from macro coaching into full fitness platform. $72/year.

## Product Designer Assessment

*Speaking as the Product Designer persona (read Docs/personas/product-designer.md first):*

### What's Working
- **Food confirmation flow is the right UX pattern.** Showing a prefilled review before logging means AI mistakes don't erode trust. Users correct once, AI learns the pattern. This should be the template for ALL logging actions.
- **Gold set eval gives us measurement.** 55 queries with 100% baseline means we can now quantify regressions when we change the pipeline. This is what the owner asked for in #65 — "have a gold set and see what works or not."
- **Food DB at 1,616 is approaching usability.** Most common daily foods are covered. The remaining gap is restaurant items and regional specialties, which USDA API handles better than manual additions.

### What Concerns Me
- **Design doc #65 has been open for weeks with unaddressed feedback.** The owner gave substantive architectural direction (multi-stage prompts, not just reorder) and we haven't responded. This is the highest-priority item in the entire project.
- **AI chat is still rules-first.** The fundamental brittleness the owner complained about hasn't changed. Voice input works better (normalization helps), but the core pipeline architecture is the same.
- **No TestFlight feedback from friends.** Build 120 shipped but there's no signal on whether the food confirmation flow actually works well in practice.

### My Recommendation
Address the design doc feedback immediately — the owner's direction toward specialized per-domain prompts is sound. Research how production chat systems handle intent → slot extraction → confirmation, then revise the doc. Don't start implementation until the architecture is approved. Meanwhile, audit all food logging paths for confirm-first behavior — the product focus explicitly requires this.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (read Docs/personas/principal-engineer.md first):*

### Technical Health
- **Test suite is strong.** 1321+ tests, 55-query gold set, coverage gates enforced. The testing infrastructure can support the pipeline refactor safely.
- **Build is stable.** No P0 bugs open, TestFlight 120 published without issues.
- **Pipeline architecture is ready for change.** sendMessage decomposition from Review #39 (491→8 handlers) means the refactor won't fight against monolithic code.

### Technical Debt
- **StaticOverrides at ~50 patterns** is the main debt. The owner explicitly called out brittleness. This is tech debt in the classical sense — it worked initially but doesn't scale.
- **Single unified classifier prompt** is another debt. The owner's feedback on PR #112 is right: one prompt trying to classify AND extract data is too much for a 2B model. Separate intent classification from slot extraction.
- **AIChatView still large** — but this is no longer blocking since handlers were extracted. Low priority.

### My Recommendation
The owner's direction in PR #112 comment 3 is architecturally sound: "Break prompt and have highly specialized prompts, even if you have to run multiple." For a 2B on-device model with 2048 token context, smaller focused prompts will outperform one large multi-task prompt. The latency cost (two ~3s LLM calls instead of one) is acceptable — 6s correct beats 3s wrong. Research multi-stage pipeline patterns, then implement: Stage 1 (intent classification, ~3s) → Stage 2 (domain-specific extraction with specialized prompt, ~3s) → Stage 3 (confirmation UI).

## The Debate

**Designer:** The owner said food logging confirmation is the priority — "we don't want to frustrate customers with wrong logging." The confirm-first audit (#121) should come before the pipeline refactor. Users are affected NOW by wrong logs.

**Engineer:** Agree on urgency, but the confirm-first audit is a 1-cycle task. The pipeline redesign (#120) is the strategic investment. We can do both in parallel — audit existing paths while researching the new architecture.

**Designer:** Fair. But don't let research become another multi-review deferral. The design doc revision has a clear deliverable: address 3 specific comments, update PR #112. Set a hard deadline: revised doc by end of next sprint, or we implement with the current architecture and iterate.

**Engineer:** Agreed. The owner's feedback is specific enough that the revision shouldn't take more than one focused session. Research → revise → approve → implement. No open-ended exploration.

**Agreed Direction:** Revise design doc #65 as the #1 priority (one session), audit food confirmation paths in parallel (#121), then implement the approved pipeline architecture. Hard deadline on the doc revision — if it slips past one sprint, implement incrementally instead.

## Decisions for Human

1. **Design doc #65 revision priority:** We plan to address your 3 review comments on PR #112 as the first sprint task. The direction (multi-stage specialized prompts) is clear. Should we also research specific production systems (e.g., Rasa, Dialogflow, LangChain routing patterns) or focus on what works for on-device 2B models?

2. **Feature request #74 (Lab reports + LLM parsing):** This is P1 with a design doc ready. Should it be included in this sprint or deferred until the AI chat pipeline refactor lands? The LLM parsing work could benefit from the same multi-stage prompt architecture.

3. **TestFlight feedback:** Build 120 has the food confirmation flow. Have friends tested it? Any feedback on whether the prefilled review form works well in practice?

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
