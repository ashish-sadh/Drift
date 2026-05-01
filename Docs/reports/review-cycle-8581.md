# Product Review — Cycle 8581 (2026-05-01)

## Executive Summary

Since review cycle 8519, Drift shipped builds 193–197 and closed 11 meaningful pull requests: food-aware unit conversion in chat (#552), ToolRanker routing + LLM eval cases for `supplement_insight`/`food_timing_insight` (#487, #550, #551), 16 historical/goal eval cases (#554), USDA API key injectable via Preferences (#555), South Indian food DB +30 (#557), weight chart tap-to-callout (#558), decimal Nx portion phrases (#559), and the "of" connector parsing fix. Food DB now at ~2,910. The eval harness is materially stronger. But the core finding from review 8519 remains: `supplement_insight` and `food_timing_insight` have routing and eval — they still lack an analytics engine. Whoop continues cementing "habits → outcomes" as their product identity. The implementation is sprint planning's top priority again.

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 197 | +5 (from 192) |
| Tests | ~2,252 (iOS ~1,219 + DriftCore ~1,033) + LLM eval ~160+ | +~120 DriftCore |
| Food DB | ~2,910 | +399 (South Indian +30, Japanese +30, USDA batch delta) |
| AI Tools | 21 registered | flat |
| Analytical Tools Active | 3 (cross_domain, weight_trend, supplement_insight routing only) | routing added, no engine |
| P0 Bugs Fixed | 0 | |
| Sprint Queue | 21 open | ↓4 from 25 |

## What Shipped Since Last Review (Cycle 8519)

- **Food-aware unit conversion in chat** (#552) — "1 cup of rice" now silently converts to grams using per-food cup size. Food logging no longer requires users to know gram weights. Zero-user-math campaign meaningfully closer.
- **Decimal Nx portion phrases** (#559) — "double it", "half serving", "1.5x" parsed correctly in `extractAmount`. Multi-step corrections like "log 1.5 cups of oats" are now handled.
- **"of" connector parsing fix** — `extractAmount` no longer misparses "cup of rice" as a unit called "cup of rice". Attached-unit extraction is cleaner for natural descriptions.
- **ToolRanker routing for `supplement_insight`/`food_timing_insight`** (#487) — Both analytical tools are registered with ToolRanker, so intent routing works. Still no analytics engine behind them — the tools route but return empty/stub responses.
- **LLM eval cases: `supplement_insight`** (#550) — 10 routing eval cases. Confirmation that LLM correctly classifies supplement adherence queries. Also fixed stale unit-conversion tests that were failing post-#552.
- **LLM eval cases: `food_timing_insight`** (#551) — LLM routing eval cases for meal timing queries.
- **16 eval cases for historical/goal/micronutrient queries** (#554) — Covers historical weekday queries, calorie goal setting, macro goal progress, micronutrient queries. Regression prevention for the failing-query closures from cycle 7448.
- **USDA injectable API key** (#555) — USDA API key configurable via Preferences, falls back to DEMO_KEY. Pre-launch blocker partially addressed (key can now be swapped at runtime; DEMO_KEY no longer hardcoded at all call sites).
- **South Indian food DB +30** (#557) — 30 new South Indian dishes including additional regional variants.
- **Weight chart tap-to-callout** (#558) — Tapping a data point on the weight chart shows date + value. Small but visible UI win.
- **Japanese home cooking +30** — Onigiri, ramen variations, donburi, gyoza, edamame, teriyaki, miso staples added.
- **TestFlight builds 193–197** shipped.

## Competitive Analysis

- **MyFitnessPal:** GLP-1 support launched April 28 (free) — medication log, dose reminders, side effect tracking alongside nutrition. The "Today" tab redesign continues to generate user complaints about navigation complexity. MFP Premium AI tools (meal scan, voice log) remain paywalled at $20/mo. Their 20M food DB vs our ~2,910 is a gap we can't close manually; USDA Phase 2 proactive search is the only viable lever.
- **Boostcamp:** No notable Q2 2026 updates. Exercise video + muscle diagram content remains the benchmark for exercise presentation. Our exercise vertical is still text-only at 960 exercises.
- **Whoop:** Behavior Trends fully live and actively marketed — calendar views of habit consistency, correlation to Recovery scores after 5+ entries. Whoop's marketing language is directly in the space our `supplement_insight`/`food_timing_insight` tools are designed to cover. Every cycle these stay unimplemented, Whoop owns the "habits → outcomes" mental model harder.
- **Strong:** No notable April/May 2026 updates. Minimal, clean UX. Not a direct competitor for analytical or food-first direction.
- **MacroFactor:** AI photo + text recipe import live, competing directly with our photo log. Favorites (saved foods with preferred serving sizes) ships a UX pattern we've had in Saved Foods for months — parity achieved. Push Pull Legs split programming still in progress. $72/year vs our free BYOK. The pricing gap is our marketing argument.

## Product Designer Assessment

*Speaking as the Product Designer persona (Docs/personas/product-designer.md):*

### What's Working

1. **Zero-user-math campaign made real progress.** Unit conversion (#552) + decimal Nx phrases (#559) + the "of" connector fix mean users can now type "1.5 cups of oats", "double the chicken", "half a serving" and get correct numbers without any arithmetic. This is the core of what makes the app feel smart vs. a manual logger.
2. **Eval harness is now a real regression net.** 16 historical/goal cases (#554) + supplement + food_timing routing cases means the failing-query categories closed in cycle 7448 are pinned. Sessions can't accidentally break them without a test failing. This is infrastructure that pays forward.
3. **South Indian + Japanese DB expansion.** 2,910 foods. The Indian food bar (#5 in product focus) gets stronger every cycle. The Japanese additions address a high-frequency search category (ramen, sushi, bento) that was underrepresented.

### What Concerns Me

1. **`supplement_insight` and `food_timing_insight` have routing but no engine — again.** This is now the finding at two consecutive reviews. Routing without analytics returns empty results when users ask "am I consistent with my fish oil?" or "when do I usually eat dinner?" The tools are partially live in production — they'll route correctly and silently fail or return nothing. That's worse than not being registered. Either ship the engine or unregister the tools from ToolRanker until ready.
2. **Whoop Behavior Trends is fully shipped and being marketed hard.** Every week we don't have `supplement_insight` working, Whoop has a bigger lead in the "habits → outcomes" space. This is our analytical identity — the same data pattern, on-device and free. Competitive cost is real and compounding.
3. **State.md is stale at build 196; we just shipped 197.** This isn't a major product concern but a planning accuracy risk. Any session reading State.md reasons about a product one build behind. Junior task, 30 minutes.

### My Recommendation

The next senior session's only job: implement `supplement_insight` and `food_timing_insight` engines — not routing (done), not eval (done), the actual analytics. Check for WIP patches in `~/drift-state/wip/` before writing a line. Ship State.md update as a junior task alongside.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (Docs/personas/principal-engineer.md):*

### Technical Health

Unit conversion (#552) and the "of" connector parsing fix are correctness improvements that reduce user-visible errors in the most-used flow. The per-food `cupSizeG`/`tbspSizeG` unit gating from the unit conversion audit is holding — no regressions reported.

DriftCore test count grew to ~1,033 (from ~913 at last review). The `swift test` loop staying at <5s warm is the most important CI property we have. Don't let it creep.

ToolRanker routing is correctly wired for both new tools. The analytics engine gap is isolated: `SupplementService` needs `adherenceStats(for:period:)` and `FoodEntry` queries need `mealTimingStats(for:)`. The schema is ready (SupplementLog, FoodEntry tables); the missing piece is the query + aggregation layer.

### Technical Debt

1. **`supplement_insight`/`food_timing_insight` partially live in production.** Tools are registered with ToolRanker. When a user asks "how consistent am I with my vitamins?", the tool routes correctly and... does nothing. This is a user-visible failure mode, not just debt. Check `~/drift-state/wip/` for any WIP patches from crashed sessions before the next attempt.
2. **State.md at build 196, actual build is 197.** Stale doc creates planning confusion. 30-minute junior fix.
3. **USDA DEMO_KEY still in use.** Injectable API key (#555) means we CAN swap it without a code change, but it defaults to DEMO_KEY (1,000 req/day). App Store launch threshold, not TestFlight. Queue a junior task to document the key swap process in State.md.
4. **Food DB at ~2,910 — 90 short of 3,000.** This isn't a debt item but a milestone within reach. Two 30-food junior sessions get us there. Psychologically meaningful number.
5. **West African cuisine task #475 interrupted twice.** The jollof rice, egusi, fufu, suya additions were started, stalled, and left as the last interrupted task. File it again with the list pre-populated so the next junior session doesn't need to research from scratch.

### My Recommendation

Senior: ship `supplement_insight` + `food_timing_insight` analytics engines in one session. Read WIP patches first. The SupplementLog and FoodEntry tables are ready; the gap is query + aggregation + response formatting. It should fit in a single senior budget. Junior queue: State.md to build 197, West African cuisine retry, push the food DB toward 3,000.

## The Debate

**Designer:** We've said "ship supplement_insight and food_timing_insight next session" at two consecutive reviews. At some point that's not a recommendation — it's a structural problem with how we're claiming and executing senior tasks. What actually happened? Why did the sessions that were supposed to ship these end up shipping eval cases instead of the engine?

**Engineer:** Looking at the commit log: #487 (ToolRanker profiles + eval cases), #550 (supplement_insight LLM eval), #551 (food_timing_insight LLM eval) — three separate sessions each shipped eval infrastructure. The pattern is: sessions claim the task, get stuck on "what does the analytics engine need?", and ship the eval layer instead because it's more bounded. The fix is brutal scoping in the task body: the next issue must say "SupplementService.adherenceStats() + FoodEntry.mealTimingStats() + response card. Not eval. Not routing. The engine." If the issue body says "implement supplement_insight", a session can interpret that as eval work. Close that ambiguity.

**Designer:** Agreed. The task needs to say exactly what to build and explicitly say "routing already done (#487), eval already done (#550/#551), this task is the analytics engine only." On the food DB — we're at 2,910 and 3,000 feels meaningful. Is there a fast path?

**Engineer:** Three consecutive 30-food junior sessions gets us to 3,000. West African (#475, was interrupted twice), plus one more cuisine choice. Each is a self-contained junior task. We should also stop filing "food DB +30" tasks open-endedly and start picking the highest-value gaps: regional Indian cuisines still underrepresented (Bihari, Nagaland, Ladakhi), and branded protein foods (Indian whey brands, ayurvedic supplements). These are what Indian users actually search for.

**Agreed Direction:** Next senior session: implement `supplement_insight` analytics engine (`SupplementService.adherenceStats()` + response formatting) AND `food_timing_insight` analytics engine (`FoodEntry` meal timing aggregation + response card) — explicitly not eval or routing. Junior queue: State.md to build 197, West African cuisine #475 retry (pre-populated), food DB push toward 3,000 with high-value Indian gaps (branded protein foods, regional Indian). File a design-doc issue for GLP-1 tracking to keep it visible.

## Decisions for Human

1. **`supplement_insight`/`food_timing_insight` — ship or unregister?** The tools are live in ToolRanker routing but return no output when triggered. Options: (a) ship the analytics engine next senior session (recommended — routing and eval are already done); (b) unregister from ToolRanker until the engine is ready to avoid silent-failure UX when users ask adhrence questions. Recommendation: (a), but if senior session stalls again, apply (b) as a safety measure.

2. **GLP-1 tracking scope.** MFP launched free GLP-1 support April 28. Medication log + dose reminders + side effect tracking + nutrition correlation. Fits Drift's all-in-one health coach identity. Options: (a) file a design-doc issue now for research/design, no implementation commitment; (b) defer entirely. Recommendation: (a) — low cost, keeps it visible, doesn't commit implementation cycles.

3. **Food DB 3,000 milestone.** At ~2,910, three 30-food junior sessions reach 3,000. High-value targets: West African (stalled #475), Indian branded protein foods, regional Indian cuisines underrepresented in current DB. Should we set 3,000 as an explicit milestone for the next sprint cycle? Recommendation: yes — milestone creates commitment; it's achievable in 2 junior sessions.

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
