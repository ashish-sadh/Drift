# Product Review — Cycle 1120 (2026-04-13)
Review covering cycles 1038–1120. Previous review: cycle 1038.

## Executive Summary

All four P0/P1 sprint items shipped: every AI chat action now has a visual confirmation card (supplements, sleep, glucose, biomarkers), and workout cards show muscle group icons. The app's chat experience went from "text-only responses" to "every action has structured visual feedback" — 8 card types total. TestFlight builds 108 and 109 published. Next focus: test coverage hardening and user-visible feature depth.

## Scorecard
| Goal | Status | Notes |
|------|--------|-------|
| P0: Finish supplement/sleep cards | Shipped | Cards show taken/remaining supplements, HRV/recovery/readiness for sleep |
| P0: Glucose + biomarker cards | Shipped | Glucose shows avg/range/spikes/zone; biomarkers show optimal vs out-of-range |
| P1: Exercise visual polish | Shipped | Muscle group SF Symbol chips on workout confirmation cards |
| P1: State.md + TestFlight 108 | Shipped | State.md updated, TestFlight 108 and 109 both published |
| P2: Food DB search miss analysis | Not Started | Deferred — all P0/P1 items consumed sprint capacity |

## What Shipped (user perspective)
- **Supplement cards in chat** — Ask about supplements and see a visual card showing what you've taken and what's remaining today
- **Sleep & recovery cards** — Sleep queries now show HRV, recovery score, and readiness in a structured card
- **Glucose monitoring cards** — Glucose queries show your average, range, spike count, and time-in-zone breakdown
- **Biomarker cards** — Lab results show which biomarkers are optimal vs out-of-range at a glance
- **Muscle group icons on workout cards** — Workout confirmations now show which muscles you trained with visual icons
- **Smarter AI model selection** — App automatically picks the right AI model based on your device, reducing battery impact
- **Two new TestFlight builds** — Builds 108 and 109 available for testers

## Competitive Position

MacroFactor launched Workouts with auto-progression and Apple Health write, becoming a serious all-in-one competitor at $72/year. MFP remains dominant on food DB (14M+ entries) and added AI Premium features behind paywall. Our edge: free, on-device, privacy-first, with conversational AI that no competitor matches — 8 structured card types across every health domain, entirely local. The gap: exercise presentation (text-only vs Boostcamp's videos) and food DB breadth (1,500 vs 14M).

## Designer x Engineer Discussion

### Product Designer
I'm genuinely excited about where chat is now. Eight confirmation card types means every major user action gets visual feedback — supplements, sleep, glucose, biomarkers, food, weight, workouts, and navigation. This is the "chat feels like a real app" milestone I've been pushing since Review #12. The muscle group icons are exactly the kind of small visual win that compounds — users see at a glance what they trained.

What concerns me: we've been in Phase 3c (Polish & Depth) for a while, and the remaining "Now" items on the roadmap are increasingly niche. The big user-visible gaps are food DB search quality (prefix matching for incomplete typing is still missing — "chick" should find "chicken") and exercise presentation. Food search misses are the highest-friction moment — every "not found" sends users to MFP.

Competitively, MacroFactor entering the all-in-one space at $72/year validates our positioning but they have resources. Our free + privacy moat holds if the experience quality matches. The next sprint should be about depth in what we have rather than breadth into new domains.

### Principal Engineer
The confirmation card architecture proved its extensibility. Adding glucose and biomarker cards was straightforward because the `attachToolCards` pattern from Review #30 scales cleanly. The 6 optional card fields on ChatMessage are at the threshold I flagged — if we add more card types, we should migrate to a `ConfirmationCard` enum with associated values. Not urgent yet but worth noting.

The IntentClassifier coverage gap (63.73%) that was "accepted as floor" for 4 reviews turns out to be solvable. I extracted `buildUserMessage` and `mapResponse` as pure testable functions — the LLM-dependent code stays untested but the pure logic around it can be covered. This is the right pattern: don't test the stochastic part, test the deterministic wrappers.

981 tests, all passing. Only IntentClassifier below the 80% threshold for pure logic. The dual-model cost optimization (SmolLM for simple devices, Gemma 4 for capable ones) was a good infrastructure investment — reduces battery impact without losing capability.

Risk area: food DB search quality is a product risk, not a technical one. Prefix matching is trivial to implement but choosing WHICH missing foods to add requires search miss data we don't have yet.

### What We Agreed
1. **IntentClassifier to 80%+** — finish the in-progress test coverage work (tests already written, need to verify)
2. **Food search prefix matching** — "chick" should find "chicken", highest-impact search quality fix
3. **Exercise muscle group heatmap** — visualize weekly muscle coverage, data already exists in exercise DB tags
4. **Test hardening** — boy scout coverage improvements alongside feature work
5. Sprint size: 4 items max (validated pattern from Review #25)

## Sprint Plan (next 20 cycles)
| Priority | Item | Why |
|----------|------|-----|
| P0 | IntentClassifier coverage to 80%+ | Only file below threshold, tests already written — finish and verify |
| P1 | Food search prefix matching | "chick" → "chicken" is the #1 search quality gap; every miss sends users to MFP |
| P1 | Muscle group heatmap on exercise tab | Visualize which muscles were trained this week; data exists, just needs UI |
| P2 | Food DB search miss analysis | Identify most-searched missing foods to prioritize DB additions |

## Feedback Responses
No feedback received on previous reports.

## Cost Since Last Review
| Metric | Value |
|--------|-------|
| Model | Opus |
| Sessions | 3 |
| Est. cost | $162.94 |
| Cost/cycle | $0.15 |

## Open Questions for Leadership
1. **Exercise visual direction:** Should we invest in muscle group heatmaps (unique, data-driven) or exercise images/GIFs (table stakes, storage-heavy)? Heatmaps are differentiating; images match competitors.
2. **Food DB strategy:** Continue manual enrichment (slow, 1,500 foods) or invest in making USDA API the default (faster, but sends search queries off-device)? The privacy trade-off is real.
3. **Phase transition:** Most Phase 3c "Now" items are shipped. Should we formally move to Phase 4 (Input Expansion — widgets, Apple Watch) or continue deepening Phase 3c?
