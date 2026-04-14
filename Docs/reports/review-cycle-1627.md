# Product Review — Cycle 1627 (2026-04-14)
Review covering cycles 1601–1627. Previous review: cycle 1601 (Review #38).

## Executive Summary

Short sprint (26 cycles). The TestFlight archive timeout that blocked builds since last review is resolved — build 115 is now available to testers. The sendMessage decomposition (491-line function) was scoped and analysis completed before this review paused feature work. Three sprint items carried forward unstarted due to the short interval. Next sprint focuses on chat architecture cleanup and expanding to new surfaces (iOS widgets).

## Scorecard
| Goal | Status | Notes |
|------|--------|-------|
| TestFlight build (archive timeout) | Shipped | Build 115 archived and uploaded successfully. Timeout was likely stale DerivedData. |
| sendMessage decomposition | In Progress | Full analysis complete (9 logical phases identified), code changes not yet started |
| Systematic bug hunt | Not Started | Carried third time — short sprint interval is the cause |
| iOS widget exploration | Not Started | Carried forward |
| Food search miss analysis | Not Started | Carried forward |

## What Shipped (user perspective)
- **New TestFlight build available** — Build 115 includes all fixes from recent cycles (recovery score consistency, cleaner exercise recommendations, barcode accuracy)
- **Build pipeline restored** — TestFlight publishing was broken last sprint; now working reliably again

## Competitive Position

WHOOP's AI Strength Trainer now builds workouts from text prompts and auto-detects exercises for muscular load breakdown — cloud-based but raising the bar for AI-powered fitness coaching. MacroFactor Workouts is adding Apple Health write-back and better exercise search. Boostcamp added bodyweight tracking and muscle engagement visualization across its 130+ programs. The industry blog consensus is that "most serious fitness people run three apps that don't talk to each other" — Drift's all-in-one + free + on-device privacy positioning directly addresses this pain point, but we need to expand our surface area (widgets, Watch) to match the convenience of dedicated apps.

## Designer x Engineer Discussion

### Product Designer

I'm glad the build pipeline is restored — users can't benefit from fixes they can't install. But this was a maintenance sprint, not a product sprint. One item shipped in 26 cycles is below our bar, even accounting for the short interval.

What concerns me is the three-time carry on the systematic bug hunt. We've proven (Reviews #17, #20) that proactive bug hunting finds real data-accuracy issues in production. Every sprint without it is a sprint where silent bugs accumulate. I want it scoped as a named P0 this time — not something that gets displaced by infrastructure.

Competitively, WHOOP's exercise auto-detection (AI identifies what you did and maps muscular load) is the next frontier. We can't match their hardware sensors, but our text-based logging + exercise database can do intelligent exercise recognition from chat descriptions. That's a future sprint item, not immediate.

The Vora Blog comparison piece calling out "three apps that don't talk to each other" validates our all-in-one positioning. But we need to be *visible* — iOS widgets showing calories remaining or recovery score would make Drift present throughout the user's day without opening the app. This is the #1 stickiness feature we're missing.

### Principal Engineer

The TestFlight archive timeout was resolved by a clean build. No underlying compilation issue was found — likely stale DerivedData or resource contention. Worth monitoring but not worth build system investment yet.

The sendMessage analysis is promising. The function is actually 128 lines of dispatcher logic calling into 25+ handler functions spread across 1,168 lines in the message handling extension. The sprint plan's "491 lines" was the old measurement. The real decomposition opportunity is organizing the handlers into phase-based groups with clearer ownership. ConversationState phase transitions are the critical sequential dependency — they must not be parallelized or reordered.

For widgets: WidgetKit + App Groups is low risk. GRDB supports read-only access from extensions. The main engineering concern is timeline refresh frequency vs. battery — we should start with a static timeline that refreshes on app foreground, not a live-updating widget.

Test suite at 996 is healthy. No open bugs, no open issues. Architecture is sound for the next phase of work.

### What We Agreed
1. **sendMessage decomposition is the top priority** — finish the analysis-to-code step. Organize handlers into phase groups. All 996 tests must pass.
2. **Systematic bug hunt ships this sprint** — scoped as P0 alongside sendMessage. Focus on notification scheduling edge cases and recent AI pipeline changes.
3. **iOS widget prototype** — Begin Phase 4 surface expansion. Start with a static "calories remaining" widget.
4. **Sprint scope stays at 4 items** — the formula works when we follow it.

## Sprint Plan (next 20 cycles)
| Priority | Item | Why |
|----------|------|-----|
| P0 | sendMessage decomposition — organize 25+ handlers into phase groups | Every AI feature makes this harder; finish now while analysis is fresh |
| P0 | Systematic bug hunt — notifications, AI edge cases, food diary boundaries | Carried 3x; proactive quality catches silent data bugs before users hit them |
| P1 | iOS widget prototype — "calories remaining" on home screen | Phase 4 surface expansion; makes Drift visible all day without opening the app |
| P2 | Food search miss analysis — track zero-result queries | Data-driven food DB improvement; every "not found" loses a user to MFP |

## Feedback Responses
No feedback received on previous reports. PR #43 (Review #37, Cycle 1550) had zero comments.

## Cost Since Last Review
| Metric | Value |
|--------|-------|
| Model | Opus |
| Sessions | Token usage tracking not available for this session |
| Est. cost | N/A |
| Cost/cycle | ~$0.06 (historical average) |

## Open Questions for Leadership
1. **Widget scope:** Should the first iOS widget show just calories remaining, or include recovery score / macro rings? Simpler = ships faster, but a richer widget is more compelling.
2. **Bug hunt frequency:** Should systematic bug hunting be a permanent every-sprint P0, or rotate it as a P1 that ships when time allows?
3. **Surface expansion priority:** After widgets, should we invest in Apple Watch (high effort, high stickiness) or Live Activities on lock screen (lower effort, moderate stickiness)?
