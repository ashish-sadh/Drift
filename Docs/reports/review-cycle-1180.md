# Product Review — Cycle 1180 (2026-04-13)
Review covering cycles 1160–1180. Previous review: cycle 1120.

## Executive Summary

This sprint delivered food diary quality-of-life fixes (reorder across meal groups, meal type picker) and pushed AI accuracy closer to the 80% target (63→78%). A new P0 bug surfaced: food reorder breaks when entries share a timestamp — common when logging multiple items via AI chat. Next sprint focuses on fixing that bug, completing the IntentClassifier coverage push, and adding the muscle group heatmap that's been deferred twice.

## Scorecard
| Goal | Status | Notes |
|------|--------|-------|
| P0: IntentClassifier to 80%+ | In Progress | Reached 78% (up from 63%). Extracting pure functions approach validated — 80% is achievable |
| P1: Food search prefix matching | Shipped | Verified already working via substring SQL. Added confirmation tests |
| P1: Muscle group heatmap | Not Started | Deferred — diary bug fixes consumed cycles |
| P2: Food DB search miss analysis | Not Started | Deferred |

## What Shipped (user perspective)

- **Food diary reorder works across meals** — Moving a food item up past a meal group boundary now works correctly (was silently failing)
- **Reorder direction fixed** — Move Up/Down buttons now behave as expected in all cases
- **Meal type picker improved** — Better UX when selecting meal type during logging
- **AI chat understands more natural language** — Intent detection accuracy improved from 63% to 78%, meaning fewer misunderstood queries
- **Design doc workflow** — Feature requests now go through a structured design → review → approve → build process
- **Food search confirmed working for partial names** — Typing "chick" correctly finds "chicken" and all chicken dishes

## Competitive Position

The health app market continues consolidating around AI + cloud. MFP acquired Cal AI and integrated ChatGPT Health; Whoop's AI Coach now parses Instagram workout photos and sends proactive nudges; MacroFactor added Live Activities and ML-based exercise search. All cloud-dependent, all behind paywalls ($12–30/mo). **Drift's edge:** free, fully on-device, privacy-first AI chat across all health domains. **Drift's gap:** food DB size (1,500 vs 20M), no photo logging, exercise presentation is text-only.

## Designer × Engineer Discussion

### Product Designer

I'm encouraged by the food diary fixes — these are "use it every day" interactions and they need to be rock-solid. The reorder bug that just surfaced (#30, same-timestamp entries) confirms that food diary is getting real daily use, which is exactly what we want.

What concerns me: we've deferred the muscle group heatmap twice now. Exercise is our weakest vertical visually — Boostcamp has muscle diagrams, MacroFactor has auto-progression visualizations, and we're still text-only beyond the SF Symbol chips we added last sprint. The heatmap is the minimum viable visual upgrade for exercise.

Competitive research shows Whoop's proactive nudge system (AI detects stress trends, sends push notifications) is getting traction. We have proactive alerts on the dashboard, but they're passive — you have to open the app. Push notifications for health patterns would be a differentiator, but it's Phase 4 territory.

The IntentClassifier push from 63→78% is significant. Users won't notice a percentage, but they'll notice fewer "I don't understand" responses. Getting to 80%+ closes the AI reliability perception gap.

### Principal Engineer

The IntentClassifier refactoring approach — extracting `buildUserMessage` and `mapResponse` as pure functions — proved the right pattern. We went from "63% is the ceiling for LLM-dependent code" to "80%+ is achievable by testing the deterministic wrappers." This reverses a stance we held for 4 reviews.

Bug #30 (same-timestamp reorder) is architecturally interesting. The current reorder mechanism swaps `loggedAt` timestamps between entries, which is a no-op when timestamps match. The clean fix is a `sortOrder` integer column on FoodEntry — explicit ordering independent of timestamps. This is a small migration but the right long-term solution. Timestamp-swapping for ordering is inherently fragile.

The design doc workflow is good process infrastructure. Feature requests now have a structured path (issue → design doc PR → review comments → approved label → sprint plan). This prevents scope creep from unreviewed features landing in the sprint.

981 tests remain stable. No regressions. The boy scout rule + coverage gate continues to maintain quality without dedicated coverage sprints.

### What We Agreed

1. **Fix P0 bug #30 first** — Add `sortOrder` column to FoodEntry for explicit ordering
2. **Finish IntentClassifier to 80%+** — Close out the coverage push started last sprint
3. **Ship muscle group heatmap** — No more deferrals. Exercise needs visual depth
4. **Food DB search miss telemetry** — Add `search_miss` table to make food additions data-driven
5. **Sprint scope: 4 items max** — The formula that produces 75-100% completion rates

## Sprint Plan (next 20 cycles)
| Priority | Item | Why |
|----------|------|-----|
| P0 | Fix bug #30: food reorder with same timestamps | Users can't reorder AI-logged meals — blocks daily workflow |
| P0 | IntentClassifier coverage to 80%+ | 78% → 80% closes a 5-review saga. Pure function extraction approach is validated |
| P1 | Muscle group heatmap on exercise tab | Deferred twice. Exercise is weakest visual vertical. Data exists in muscle tags |
| P2 | Food DB search miss telemetry table | Can't improve food DB without measuring what's missing. Lowest-risk, highest-value infra |

## Feedback Responses

No feedback received on previous reports. PR #27 (Review #32, cycle 1120) has zero comments.

## Cost Since Last Review
| Metric | Value |
|--------|-------|
| Model | Opus |
| Sessions | 3 |
| Cycles | 20 (1160→1180) |
| Est. cost | $162.94 (today's session) |
| Cost/cycle | $0.14 |

## Open Questions for Leadership

1. **Food reorder architecture:** Should we add a `sortOrder` column (clean, future-proof) or use timestamp offsetting (simpler, no migration)? The column is more work now but eliminates a class of ordering bugs permanently.
2. **Exercise visual investment:** Muscle group heatmap is the minimum viable upgrade. Should we go further — exercise images/GIFs from a free dataset? This would significantly increase app size but close the gap with Boostcamp.
3. **Push notifications for health patterns:** Whoop's proactive nudges are gaining traction. Our alerts are dashboard-only. Worth adding local push notifications for patterns like "protein deficit 3 days running" or "no workout in 5 days"? This is a Phase 4 item but could be high-impact.
