# Product Review — Cycle 719 (2026-04-12)
Review covering cycles 699–719. Previous review: cycle 699.

## Executive Summary

This sprint achieved 100% completion on all 6 planned items — every P0, P1, and P2 shipped. Three silent data-accuracy bugs were found and fixed through systematic analysis, proactive health alerts now notify users about protein and supplement gaps, workout history gained muscle group visualization, and AI chat can now answer "how's my bench?" The app is transitioning from a data logger to a proactive health coach. Next sprint should begin USDA API implementation and deepen the proactive intelligence pattern.

## Scorecard
| Goal | Status | Notes |
|------|--------|-------|
| P0: AI chat workout intelligence | Shipped | "How's my bench?" returns 1RM trend, session history, last weight |
| P0: USDA API design document | Shipped | Full design doc: offline-first, opt-in toggle, cache table, 4-phase plan |
| P1: Proactive insight alerts | Shipped | Protein streak + supplement gap alerts on dashboard |
| P1: Systematic bug hunting | Shipped | 3 P0 bugs found and fixed with regression tests |
| P2: Exercise presentation | Shipped | Muscle group chips with SF Symbol icons on workout cards |
| P2: Coverage maintenance | Shipped | 942 tests (+6), all services above threshold except IntentClassifier (63%) |

## What Shipped (user perspective)

- **"How's my bench progress?"** — Ask the AI about any exercise and get your strength trend, recent 1RM history, and last weight used — all in the correct unit.
- **Proactive protein alerts** — If you miss your protein target 3+ days in a row, the dashboard warns you with a specific suggestion.
- **Supplement reminders** — Haven't taken creatine or vitamin D in 3 days? The dashboard tells you.
- **Muscle group chips on workouts** — Each workout in history now shows which body parts were hit (Chest, Back, Legs, etc.) with icons.
- **3 silent bugs fixed** — "1000 calcium" no longer logs 1000 calories, servings of "2" from AI no longer default to 1, and "undo" now correctly undoes what you just did (not always food).
- **USDA API design complete** — Ready to implement external food database search when approved.
- **942 automated tests** — 6 new regression and feature tests.

## Competitive Position

With proactive alerts (workout overload, protein streaks, supplement gaps), Drift is moving beyond data logging into proactive health coaching — a space Whoop occupies for recovery but no competitor does holistically across nutrition, exercise, and supplements on-device. Our exercise vertical closed the gap significantly: progressive overload alerts, workout intelligence in chat, and muscle group visualization. The main remaining gaps are food DB breadth (1,500 vs MFP's 20M — USDA API will address) and exercise content (text-only vs Boostcamp's videos).

## Designer × Engineer Discussion

### Product Designer

This is the most productive sprint we've had. Six for six, including features that fundamentally change how the app feels. The proactive alerts on the dashboard are exactly the "health coach" pattern I've been pushing — users open the app and immediately see what needs attention. This is what separates Drift from every other tracker that just shows you numbers.

The muscle group chips are small but important — they add visual information density without clutter. When you scroll through workout history, you can now see at a glance that Monday was chest/shoulders and Wednesday was legs. Boostcamp still has richer exercise content (videos, animations), but our workout cards now communicate more information than Strong's.

For next sprint, I want to see the USDA API built. The design doc is solid — opt-in, offline-first, cached locally. This is the single biggest remaining gap for food logging credibility. A user who can't find "quinoa" in our database will leave. The 80/20 is: implement Phase 1 (search + cache), skip branded products initially, and ship it behind the opt-in toggle.

### Principal Engineer

The 3 P0 bugs from systematic analysis validate this as a permanent practice. The integer JSON bug (servings silently defaulting to 1) was particularly insidious — Apple's `JSONSerialization` returns `Int` for whole numbers, and our parser only checked `Double`. This pattern exists in any Swift code that deserializes JSON numbers. The undo fix was architecturally significant — we now have a proper `lastWriteAction` tracking mechanism in ConversationState, which makes the undo system extensible.

Coverage is stable at 942 tests. The only file below threshold is IntentClassifier (63%) — but this is LLM-dependent code where deterministic testing is inherently limited. I'd accept 63% as the floor for this specific file.

For USDA API implementation, the key risk is scope creep. The design doc covers 4 phases — we should ship Phase 1 (USDAClient + cache table) in a single sprint, behind the toggle, and iterate. The `URLSession` wrapper, the `usda_cache` GRDB table, and the `searchWithFallback()` orchestration in FoodService are all straightforward. The hard part is nutrient mapping (USDA uses numeric nutrient IDs, not names).

### What We Agreed

1. **USDA API Phase 1 (P0)** — Build USDAClient, usda_cache table, and FoodService fallback. Ship behind opt-in toggle.
2. **Navigate to screen from chat (P1)** — "Show me my weight chart" should switch tabs. Closes an AI parity gap.
3. **Deepen proactive alerts (P1)** — Add workout consistency alert (no workouts in 5+ days) and logging gap alert.
4. **Systematic bug hunting (P1)** — Continue every-sprint cadence. Focus on new code paths (USDA, proactive alerts).
5. **IntentClassifier coverage (P2)** — Push from 63% toward 80% with deterministic test cases.

## Sprint Plan (next 20 cycles)
| Priority | Item | Why |
|----------|------|-----|
| P0 | USDA API Phase 1 (client + cache + fallback) | Biggest food DB gap — 1,500 vs 300K+ with USDA |
| P1 | Navigate to screen from chat ("show weight chart") | AI parity gap — chat should reach any screen |
| P1 | More proactive alerts (workout consistency, logging gaps) | Extend health coach pattern — proven with overload/protein/supplement |
| P1 | Systematic bug hunting | Every-sprint cadence — 3 P0s found last sprint |
| P2 | IntentClassifier coverage improvement | Only file below 80% threshold — push toward target |
| P2 | Coverage maintenance via boy scout rule | 942 tests, maintain organically |

## Feedback Responses

No feedback received on previous reports (PR #12, Review #19 at cycle 670, PR #14, Review #20 at cycle 699 — zero comments).

## Open Questions for Leadership

1. **USDA API go/no-go** — Design doc is complete. Should we begin implementation this sprint? The opt-in toggle preserves privacy-first identity while closing the food DB gap.
2. **Proactive alerts expansion** — We now have 4 alert types (overload, protein, supplement, and soon workout consistency). Should we build a generalized alerting framework, or keep implementing domain-specific alerts individually?
3. **App Store timeline** — With 942 tests, zero open bugs, proactive coaching, and soon a larger food DB — when should we target public launch beyond TestFlight?
