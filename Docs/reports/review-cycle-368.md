# Product Review — Cycle 368 (2026-04-18)

## Executive Summary
TestFlight build 137 published with drift-control infrastructure hardening (no user-visible app changes since build 136). Sprint queue stands at 15 pending items (4 P0 bugs, 1 SENIOR, 11 junior). Per-component AI eval (#161), AIChatView ViewModel extraction (#162), and intent routing expansion to ~130 cases continue from prior cycles. Next sprint focus: end-to-end multi-turn integration tests, food DB +20, and food-logging-to-edit reliability bugs (#191, #192).

## Scorecard

| Metric | Value | Trend |
|--------|-------|-------|
| Build | 137 | +1 |
| Tests | 1564+ | flat |
| Food DB | 2,187 | flat |
| AI Tools | 20 | flat |
| Coverage | est. ~55% | flat |
| P0 Bugs Fixed (last cycle) | #170, #171, #182 | + |
| Sprint Velocity | 4 P0 + 1 SENIOR + 11 junior open | steady |

## What Shipped Since Last Review
- TestFlight build 137 — drift-control infra (no user-facing changes)
- Watchdog reliability: planning-issue file resilience, persona check uses git timestamp not file mtime, TestFlight 3h timer fix
- Role-specific session-start output for senior/junior/planning sessions
- Sprint planning system: GitHub-native checkpoint via planning-service.sh, infra-improvement label

## Competitive Analysis
- **MyFitnessPal:** Cal AI integration continues to dominate photo-logging space; we remain on-device privacy-first.
- **Boostcamp:** Still gold standard for exercise visuals; our 873-exercise text-only DB is an open gap.
- **Whoop:** Behavior insights tied to Recovery scores remain mature; our cross-domain insights remain shallower.
- **Strong:** Logging speed parity is achievable but not yet measured.
- **MacroFactor:** Workouts app rolling out personalized progression; our progressive-overload alert (P0) shipped earlier sprints.

## Product Designer Assessment

*Speaking as the Product Designer persona (read Docs/personas/product-designer.md first):*

### What's Working
- AI chat reliability gates (FoodLoggingGoldSetTests + IntentRoutingEval) protect daily-use queries from regressions.
- Per-component eval (IntentClassifier, FoodSearch, SmartUnits) makes AI changes safe to merge.

### What Concerns Me
- Recipe builder reliability: bugs #191 (Done doesn't log) and #192 (cannot edit ingredients) directly hurt food-logging trust. P0.
- Multi-select for re-logging previous foods (#187) — without this, daily users redo 5+ taps for repeat meals.
- Fiber treated as 4th macro (#186) — semantic confusion that misleads users about goal alignment.

### My Recommendation
Fix the 4 P0 food-logging bugs this cycle. Every other AI improvement is undermined if a logged food can't be edited or finalized.

## Principal Engineer Assessment

*Speaking as the Principal Engineer persona (read Docs/personas/principal-engineer.md first):*

### Technical Health
- Drift-control infra now stable across 4 stall paths + crash recovery; auto-research optimizer running per spec.
- AI eval harness gates every AI merge; gold sets are deterministic and <1s.

### Technical Debt
- Cycle counter / last-review-cycle drift: review_merged validation false-positives when cycle is reset (this very cycle hit it).
- AIChatViewModel grew ~20 handlers post #162 extraction — may need sub-domain splitting if it crosses 800 lines.
- Test count claim (1564+) is from a stale state.md write — needs verification this cycle.

### My Recommendation
Add E2E multi-turn integration test that drives the full pipeline (input → normalize → classify → tool → present) over a 5-turn conversation. This catches state-machine regressions that per-component gold sets miss.

## The Debate

**Designer:** P0 bugs first — recipe builder and multi-select. Users tell us the same thing every cycle: "logging food is too slow."

**Engineer:** Agreed on P0 bugs. But we also need the E2E multi-turn integration test before #163 (multi-stage prompt experiment) lands — that refactor will silently break dialogue state without it.

**Designer:** Multi-stage prompt is your concern; my concern is the user can't edit a recipe they just built. Both ship this sprint?

**Engineer:** Both. P0 bugs are 1-2 day work each. E2E test is 1 day. Multi-stage prompt slips one cycle if needed.

**Agreed Direction:** P0 food-logging bugs (#187, #186, #191, #192) ship this cycle. E2E multi-turn integration test added as SENIOR sprint task. Multi-stage prompt experiment remains queued.

## Decisions for Human

1. **Recipe builder UX (post-fix):** Should "Done" auto-log the recipe, or remain as "save without logging"? (#191 ambiguity)
2. **Fiber treatment (#186):** Track fiber as a 4th macro on dashboard, or as a sub-metric inside carbs? Affects ring layout.
3. **South Indian cuisine expansion (#188):** Should this be human-curated (slower, higher quality) or USDA-pulled (faster, mixed quality)?

---
*Comment on any line for strategic feedback. @ashish-sadh @nimisha-26*
