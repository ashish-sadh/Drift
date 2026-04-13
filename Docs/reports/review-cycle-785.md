# Product Review — Cycle 785 (2026-04-12)
Review covering cycles 759–785. Previous review: cycle 739 (Review #22).

## Executive Summary

Since the last review, we shipped proactive workout consistency and logging gap alerts — the app now watches for 6 distinct behavioral patterns and nudges users back on track. Chat-based screen navigation ("show me my weight chart" switches tabs) is in active development. The product continues its transition from passive data logger to proactive health coach, with on-device privacy as our competitive moat.

## Scorecard
| Goal | Status | Notes |
|------|--------|-------|
| P0: Proactive Alerts (workout + logging gaps) | Shipped | 6 alert types, 948 tests |
| P1: Navigate to Screen from Chat | In Progress | Core architecture done, wiring up |
| P1: Wire USDA into AI Chat | Not Started | Deferred to focus on navigation |
| P1: Systematic Bug Hunting | Not Started | Planned for next sprint |
| P2: IntentClassifier Coverage | Not Started | |
| P2: AIChatView ViewModel Extraction | Not Started | |

## What Shipped (user perspective)
- **Workout consistency alerts** — If you haven't worked out in 5+ days, the dashboard tells you
- **Food logging gap alerts** — If you haven't logged food in 2+ days, the app nudges you
- **6 proactive alert types total** — Protein streaks, supplement gaps, workout gaps, logging gaps, and more on the dashboard
- **Chat navigation in progress** — Users will soon be able to say "show me my weight chart" and the app switches to that screen
- **TestFlight build 106 published** — Latest features available to testers

## Competitive Position

Our proactive health coaching pattern (alerts across nutrition, exercise, and supplements on one dashboard) remains unique — Whoop does recovery coaching but behind a $30/month paywall, and MFP focuses on food logging without cross-domain insights. Our gap is still food DB breadth (1,500 vs MFP's 20M+, partially addressed by USDA API) and exercise content (text-only vs Boostcamp's video library). The on-device privacy moat becomes more valuable as MFP and Whoop add cloud AI features that require sending user data off-device.

## Designer × Engineer Discussion

### Product Designer

I'm excited about the proactive alerts — they fundamentally change how the app feels on open. Instead of "here's your empty dashboard, go log something," it's "hey, you haven't trained in 6 days, and you missed logging yesterday." That's the health coach pattern I've been pushing since Review #19, and it's now live across 6 behavioral signals.

Chat navigation is the right next investment. It's the biggest remaining gap in our AI-first story: you can log food, check progress, plan meals, and ask about workouts through chat, but you can't say "show me my weight chart." Every time a user has to manually tap a tab for something the AI could navigate to, it breaks the conversational illusion. The implementation I'm seeing — static overrides for common phrases plus an LLM tool for natural variations — is the right layered approach.

What concerns me is sprint velocity. We shipped 1 of 6 planned items this sprint. The P0 was impactful and well-executed, but five items slipping is a pattern now — Reviews #20 and #22 both had similar rates. I want to see the next sprint scoped to 4 items max with clear priority.

### Principal Engineer

The proactive alerts implementation is architecturally clean — it reuses existing service queries and just adds a presentation layer on the dashboard. No new infrastructure debt. The 948 test count (+2 from last review) confirms we're maintaining quality.

The chat navigation implementation uses NotificationCenter for cross-component communication between the chat overlay and the tab view. This is pragmatic — the alternative (passing bindings through 3 layers or adding an Observable coordinator) would over-engineer what's fundamentally a one-way "change tab" signal. The static override layer handles common phrases deterministically, and the LLM tool handles natural language variations. Both paths converge on the same ToolAction.navigate case.

One concern: we added an `openBarcodeScanner` case to ToolAction to fix a pre-existing hack where barcode scanning was using `.navigate(tab: 0)` as a placeholder. This was necessary to make real navigation work correctly, but it means any code that exhaustively switches on ToolAction needs updating. The compiler catches this, so the risk is low.

Sprint velocity is an engineering planning issue, not a technical one. The USDA API sprint (Review #22) was honestly a full-sprint item that we tried to pair with 4 other tasks. Scoping needs to be more honest.

### What We Agreed
1. **Finish chat navigation this sprint** — it's half-done, complete it with tests and the IntentClassifier integration
2. **Scope sprints to 4 items max** — the velocity pattern is clear: one large P0 displaces everything else
3. **Wire USDA into chat** — the API exists behind a toggle, but chat doesn't use it yet. Quick win.
4. **Systematic bug hunting every sprint** — it keeps slipping. Make it a named P1, not an afterthought.

## Sprint Plan (next 20 cycles)
| Priority | Item | Why |
|----------|------|-----|
| P0 | Chat navigation ("show me my weight chart" switches tabs) | Half-done, biggest remaining AI parity gap |
| P1 | Wire USDA into AI chat food logging | API exists but chat doesn't use it — quick integration |
| P1 | Systematic bug hunting on new code paths | Found 3 P0 bugs last time. Skipping this is risky. |
| P2 | IntentClassifier coverage toward 80% | Only file below threshold |

## Feedback Responses

No feedback received on previous reports (Review #22, PR #17 — 0 comments).

## Open Questions for Leadership
1. **Should chat navigation close the chat panel when switching tabs?** Current implementation collapses the chat overlay so the user sees the target screen. Alternative: keep chat open and navigate in background. Which feels more natural?
2. **USDA API: should we register for a dedicated API key before App Store launch?** Currently using DEMO_KEY with lower rate limits. Fine for TestFlight but will hit limits with more users.
3. **Are proactive alerts the right direction for differentiation, or should we invest more in food DB breadth?** We're betting on "smart coach" over "comprehensive database" — is that the right trade-off?
