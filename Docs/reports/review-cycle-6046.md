# Product Review — Cycle 6046 (2026-04-18) · PR #48

## Executive Summary

Since Review #47 (cycle 5374): per-component gold sets shipped (#161), AIChatView.sendMessage ViewModel extraction complete (#162), IntentRoutingEval expanded to ~130 cases with protein shake + phase reset routing hardened, auto-research pipeline optimizer (Karpathy-style HardEvalSet) added, FoodTabView ViewModel extraction done (#179), 4 P0 bugs fixed (#170/#171/#182 + voice stuck/utterance loss), and food DB grew to 2,187. Sprint planning for cycle 6046 adds two new AI quality tickets: implicit food intent eval coverage (#183) and conversation context pass-through (#184). Eval infrastructure is now the strongest it's ever been — per-component gates, auto-research optimizer, and 130+ case gold set.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 136 | +6 (from 130) |
| Tests | 1,564+ | stable |
| Food DB | 2,187 | +80 (from 2,107) |
| AI Tools | 20 | — |
| Gold Set (FoodLogging) | 100% | stable |
| Gold Set (IntentRouting) | 100% | +30 cases (~100→130) |
| Per-Component Gold Sets | 3 shipped | IntentClassifier (22), FoodSearch (20+), SmartUnits (20+) |
| P0 Bugs Fixed | 4 | #170 dal, #171 awaitingMealItems, voice, #182 hallucination |
| Sprint Velocity | 12/12 | all tasks closed |

## What Shipped Since Last Review (cycles 5374→6046)

- **Per-component isolated gold sets (#161)** — IntentClassifierGoldSetTests (22 cases), FoodSearchGoldSetTests (20+ cases), SmartUnitsGoldSetTests (20+ cases). All deterministic, <1s. Every pipeline stage now has its own test suite — directly addressing the longstanding feedback about regressions sneaking through individual components.
- **AIChatView.sendMessage ViewModel extraction (#162)** — 491-line monolith decomposed into 20+ private handlers in AIChatViewModel. AIChatView.swift is now pure SwiftUI. The most critical code path in the app is now testable and maintainable.
- **FoodTabView ViewModel extraction (#179)** — Business logic extracted from FoodTabView into FoodTabViewModel. DDD violations eliminated. Only ActiveWorkoutView remains as a fat view.
- **Auto-research pipeline optimizer** — Karpathy-style HardEvalSet + `testAutoResearch` pipeline. Automatically finds best prompt config, measures on held-out set, applies if regression-free. Automates what was previously manual prompt tuning.
- **IntentRoutingEval calibrated to 2B model capacity** — Protein shake routing fixed (was mis-routing to mark_supplement), phase reset hardened, +13 cases in one batch. ~100→130 total cases.
- **P0 Bug #170** — "a cup of dal" parsing fixed. Dal queries were mis-extracting the unit.
- **P0 Bug #171** — "log lunch" mis-logging cannoli (meal re-request in awaitingMealItems) fixed. State machine was mishandling the awaitingMealItems → idle transition.
- **P0 Bug #182** — AI chat hallucinating food when diary is empty. Fixed.
- **Voice: stuck indicator + utterance loss** — Stuck spinner resolved; earlier utterances no longer lost when pausing mid-session.
- **Dashboard: deduplication + non-logger alert suppression** — Protein and workout alerts no longer nag users who aren't logging. Alert deduplication prevents duplicates.
- **Voice filler word stripping (#164)** — "um", "uh", "like", "you know", "so" stripped from voice input by InputNormalizer before LLM sees it. NormalizerGoldSetTests added.
- **StaticOverrides audit (#165)** — All 20 rules enumerated and annotated. 0 rules removed — every rule is legitimate. Prompt-first discipline maintained.
- **Multi-turn food logging reliability (#166)** — 3-turn breakfast test (oatmeal → banana → black coffee) added to IntentRoutingEval with history context at each turn.
- **Supplement intent disambiguation (#168)** — Mark vs status disambiguation hardened in IntentClassifierGoldSetTests.
- **Non-food negative assertions (#169)** — Exercise instruction queries and protein-status queries added to FoodLoggingGoldSetTests. Chat won't mistake exercise form questions for food logging.
- **Food DB +80 (2,107→2,187)** — Burger King, Subway, Domino's, Gathiya, Surti Locho, Sev Mamra, Fage 0%, Two Good Yogurt, L-Glutamine, Collagen Peptides, Chipotle Burrito Bowl; Indian bread, eggs, Indian vegetables, grains, chicken, salads batch.
- **TestFlight builds 131–136** — Multiple builds shipped to testers.

## Competitive Analysis

- **MyFitnessPal:** Cal AI integration (20M food DB) remains Premium+ only. Free tier continues shrinking. Photo log and voice log are $20/mo. Our free, on-device AI is a direct differentiator. Gap: DB breadth (2,187 vs 20M).
- **Boostcamp:** Still the exercise-content gold standard with animated muscle diagrams. Our YouTube tutorial links (shipped cycle 5374) close part of the gap, but animated GIFs remain unmatched. No meaningful product changes reported.
- **Whoop:** AI Coach conversation memory is live. Cross-domain behavioral insights are strong. Cloud-based — their privacy story is weaker than ours. Relevant: our conversation context pass-through (#184) moves in this direction on-device.
- **Strong:** No AI, minimal changes. Our on-device AI + food logging in the same app is a clear advantage over their workout-only focus.
- **MacroFactor:** Auto-progression AI in Workouts app continues to develop. Cloud-based. Our on-device privacy moat holds.

## Product Designer Assessment

*Speaking as the Product Designer persona (Docs/personas/product-designer.md):*

### What's Working
- **Eval infrastructure is finally real.** Per-component gold sets, auto-research optimizer, 130+ case IntentRoutingEval — this is a genuine quality immune system now, not aspirational. Human feedback asked for this at cycle 4805 and it's fully delivered.
- **ViewModel architecture is clean.** AIChatView and FoodTabView are both extracted. The core of the app is now testable and modular. Architectural debt from 12 months of rapid shipping is largely resolved.
- **P0 bug velocity is good.** Four P0 bugs fixed in one sprint cycle — dal parsing, awaitingMealItems, voice stuck, hallucination. Users who hit these will now have a much smoother experience.

### What Concerns Me
- **Context window is still 2048 tokens (#176 is in Ready but not shipped).** Multi-turn conversations that go longer than ~8–10 turns will lose early context. This is the next real barrier to "AI chat that handles 90% of interactions." Users won't notice until they do, and then it feels broken.
- **No user-visible AI improvement shipped this cycle.** The work was all infrastructure (gold sets, ViewModel extraction, eval expansion). These are essential but a TestFlight tester loading the app today sees nothing new in chat behavior. We need at least one user-facing AI improvement each sprint.
- **Implicit food intent is a real gap (#183).** Most real users say "had rice" not "log rice." Until we have robust coverage for this phrasing, the AI feels unnatural. #183 is the right ticket to address this — it should be a P0, not a junior task.

### My Recommendation
This sprint must ship something a tester can feel. #176 (context window expansion) and #184 (conversation context pass-through) are the two highest-leverage AI improvements in the queue. Pick one and ship it. Don't let another sprint go by with only infrastructure. Eval expansion (#177 to 175 cases) is also important — but it's table stakes maintenance, not a feature.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (Docs/personas/principal-engineer.md):*

### Technical Health
Architecture is in the best shape it's been. AIChatView and FoodTabView are now properly layered. Per-component gold sets mean regressions in individual stages will be caught before they reach the full pipeline. Auto-research optimizer reduces manual prompt tuning to near-zero. The eval harness is legitimate infrastructure.

Remaining fat view: ActiveWorkoutView. Less critical than AIChatView was, but worth extracting when next touching exercise features.

### Technical Debt
- **Context window (2048 tokens)** is the highest-priority architectural constraint. Multi-turn history gets truncated, long food parsing prompts push out context. #176 (4096 token test with memory profiling) should be P0 this sprint — it's scoped correctly and the risk is bounded (profile first, only ship if memory overhead ≤200MB).
- **Conversation state still has scattered vars** (pendingMealName, pendingWorkout) alongside the Phase enum. The Phase enum covers the main states cleanly, but the ancillary vars are technical debt that will cause future bugs. Not blocking — but should be cleaned up when next touching conversation state.
- **No auto-research baseline recorded this sprint.** The auto-research task (#181) is in Ready but hasn't been run. Baseline metrics are needed before optimization. Should be first thing next session.

### My Recommendation
P0 this sprint: run auto-research baseline (#181), then context window expansion (#176). Both are well-scoped and bounded. Context window is the only architectural change with a direct UX payoff for users. After those, #184 (conversation context) is the most impactful user-facing AI improvement we can ship without a major architectural change.

## The Debate

**Designer:** Two camps here: users need something they can feel (context window, conversation context), and the eval infrastructure needs to keep growing (eval to 175, implicit intent coverage). I'm not opposed to infrastructure — I just need one win for testers this sprint. My push: #176 (context window) as P0, #184 (conversation context) as P1. Eval expansion as the junior-track task that runs alongside.

**Engineer:** Agreed on priority order. #176 is bounded risk — profile on device, ship if ≤200MB overhead, revert if not. It's not speculative. #184 (conversation context pass-through) is also well-scoped: store last tool result, prepend to next LLM call, test with 3 multi-turn cases. These two together would make multi-turn chat genuinely smarter. I also want #181 (auto-research baseline) to run before anything else — it sets the measurement baseline so we know if we're improving.

**Designer:** Fully aligned. #181 first (baseline), then #176 (context window), then #184 (conversation context), eval expansion alongside. I want to see a TestFlight build mid-sprint if context window ships cleanly — give testers something to feel.

**Engineer:** Reasonable. Sequence: #181 (auto-research baseline, fast) → #176 (context window, device profiling required) → #184 (conversation context, LLM call change) → eval expansion (#177/#183) in parallel. If #176 fails device profiling, fall back to #184 and #177 as the primary work.

**Agreed Direction:** Run auto-research baseline first, then ship context window expansion if memory overhead is acceptable, then conversation context pass-through. These two together make multi-turn chat genuinely smarter for users. Eval expansion runs alongside as the junior track.

## Decisions for Human

1. **Implicit food intent priority** — #183 is currently a junior P1 task. But "had rice" vs "log rice" is a fundamental naturalness gap that most users hit every session. Should #183 be promoted to P0 AI quality? Recommendation: yes, and fix any routing gaps found with prompt changes (not StaticOverrides).

2. **Conversation context scope** — #184 passes the last tool result to the next LLM call. Should this also include the last tool *call* (what the user asked for), not just the result? E.g., "log 200g rice → rice was logged" vs "the user asked to log rice, and it was logged with 260 kcal." The latter enables better "is that enough protein?" reasoning but is more complex.

3. **USDA API default** — We have 2,187 foods but USDA is still opt-in. Food DB breadth is the biggest gap vs MFP. Should USDA be default-ON for new users? Or does the privacy-first positioning make this a non-starter?

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
