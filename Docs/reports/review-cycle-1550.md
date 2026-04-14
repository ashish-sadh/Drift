# Product Review — Cycle 1550 (2026-04-13)
Review covering cycles 1525–1550. Previous review: cycle 1483 (Review #37).

## Executive Summary
This sprint fixed a user-reported calorie accuracy bug in barcode scanning, expanded the food database with 20 fitness-focused items, and added test coverage for health notifications. Two new P0 bugs surfaced from real-world testing — recovery score inconsistency and progressive overload taking excessive space. Next sprint focuses on these UX bugs plus the remaining state.md refresh and systematic bug hunt.

## Scorecard
| Goal | Status | Notes |
|------|--------|-------|
| sendMessage decomposition | Shipped | Was already at 128 lines with 21 extracted methods — sprint plan had stale info |
| Food search miss analysis + targeted additions | Shipped | 20 high-value foods added (protein snacks, supplements, fitness staples). DB at 1,520 |
| Notification + behavior alert test coverage | Shipped | 5 dedicated tests for alert detection edge cases |
| Systematic bug hunt | Not Started | Displaced by P0 barcode calorie bug (#40) |
| State.md refresh | Not Started | Deferred — will carry into next sprint |

## What Shipped (user perspective)
- **Barcode scanning now shows correct calories for multi-piece products** — scanning a "3 pieces (85g)" product shows per-piece calories instead of full-package calories
- **20 new foods findable in search** — protein cookies, creatine, electrolyte drinks, shirataki noodles, protein ice cream, and more fitness staples
- **Exercise chat handles natural language better** — "how do I do deadlifts?" and "tell me about bench press, please" now work (plurals, trailing phrases)
- **Health notification system has stronger reliability** — edge cases for protein streaks, supplement gaps, and workout consistency alerts verified
- **Command Center improvements** — Feedback Trail links to source reports, Sprint is its own tab, bug filing works with sign-in prompt
- **TestFlight build 113 published** with all fixes above

## Competitive Position
MyFitnessPal launched a redesigned "Today" tab prioritizing the food diary as the landing screen, plus Workout Routines for strength tracking and calorie credit. They also launched an advertising media network (MyFitnessPal Ads). MacroFactor continues gaining recognition as the leader in food logging speed. Our edge remains: free, private, AI-first chat interface covering nutrition + exercise + supplements in one app. Our gap: visual polish on data-heavy screens (progressive overload, recovery scores) needs work to match premium competitors.

## Designer x Engineer Discussion

### Product Designer
I'm encouraged that the barcode calorie fix shipped quickly after user report — this is the kind of data accuracy issue that silently erodes trust. The food DB additions target the right audience (fitness-focused users who log protein shakes and creatine).

What concerns me are the two new P0 bugs. Recovery score showing 77 on the dashboard but 58 on the detail page is exactly the kind of inconsistency that makes users question all our data. And the progressive overload list (screenshot shows 14+ exercises, all with suggestions) is visually overwhelming — it looks like a wall of warnings rather than actionable coaching.

MFP's new Today tab is interesting. They moved the diary to the first screen because that's where users spend time. We already have this right with our dashboard — but their Streaks view and Healthy Habits section are ideas worth borrowing. Logging streaks are a proven engagement mechanic.

The progressive overload UI needs a rethink. Show top 3-5 most stalling exercises with a "Show more" expand, not a flat list of every exercise. Coaching should feel curated, not exhausting.

### Principal Engineer
The barcode fix was architecturally clean — `parsePieceCount` extracts piece multiplier from serving strings, divides in the two consumption points. No DB migration needed since we re-derive from the cached serving description string.

The recovery score mismatch (Bug #41) is likely a timing issue — dashboard reads from Apple Health at one point, Body Rhythm page reads at another, or they're using different calculation methods. Need to trace both data paths to find the divergence.

Progressive overload space issue (Bug #42) is a pure UI problem. The current implementation renders every stalling/declining exercise in a flat list. The fix is straightforward: cap at 3-5 items with expand/collapse. Low-risk change.

State.md is stale — shows build 108 (actual 113), tests 981 (actual 1,037+), foods 1,500 (actual 1,520). This should be a quick refresh.

The sprint had 60% completion (3/5 items). The systematic bug hunt was correctly displaced by a real P0 bug, but state.md refresh could have been squeezed in. The pattern of P2s slipping continues — keep sprints tight.

### What We Agreed
1. Fix both P0 bugs immediately (recovery mismatch, progressive overload space)
2. Cap progressive overload to top 5 most stalling exercises with "Show more"
3. Complete the carried-over state.md refresh
4. Run the deferred systematic bug hunt, focused on recent changes
5. Keep sprint to 5 items max — proven to work

## Sprint Plan (next 20 cycles)
| Priority | Item | Why |
|----------|------|-----|
| P0 | Fix recovery score mismatch between dashboard and detail page (#41) | Owner-reported. Data inconsistency destroys trust |
| P0 | Fix progressive overload taking too much space (#42) | Owner-reported. Cap to top 5 with expand/collapse |
| P1 | State.md refresh | Carried from last sprint. Stale numbers mislead planning |
| P1 | Systematic bug hunt (notification scheduling, food diary edge cases) | Carried from last sprint. Quarterly practice |
| P2 | Progressive overload UI polish — add exercise name highlighting, clearer weight suggestions | Improve coaching feel after fixing the space issue |

## Feedback Responses
No feedback received on Review #37 (PR #39). PR has zero comments.

## Cost Since Last Review
| Metric | Value |
|--------|-------|
| Model | Opus |
| Sessions | 3 |
| Est. cost | $162.94 |
| Cost/cycle | $0.10 |

## Open Questions for Leadership
1. **Progressive overload display:** Should we show top 3 or top 5 stalling exercises by default? Fewer feels more curated, more feels more complete.
2. **Recovery score source of truth:** Dashboard and Body Rhythm page may compute recovery differently. Should we standardize on Apple Health's value or our own calculation?
3. **MFP-style logging streaks:** MFP's new Today tab highlights logging streaks prominently. Should we add a streak counter to the dashboard to drive daily engagement?
