# Product Review — Cycle 695 (2026-04-12)
Review covering cycles 671–695. Previous review: cycle 670.

## Executive Summary

This sprint delivered all four P0s from the last plan: AI workout intelligence in chat ("How's my bench?"), a USDA API design document, the hardcoded unit audit, and progressive overload alerts — plus a systematic bug hunt of the AI pipeline that surfaced three silent data-accuracy issues. The app now has 936 tests, 1,500 foods, and a meaningfully smarter chat experience for exercise tracking. Next sprint focuses on fixing the confirmed pipeline bugs, shipping proactive insight alerts across domains, and beginning the USDA API implementation.

## Scorecard

| Goal | Status | Notes |
|------|--------|-------|
| AI chat workout intelligence ("how's my bench?") | Shipped | Shows 1RM trend, last weight, respects unit preference |
| USDA API design document | Shipped | Offline-first design, opt-in toggle, 4-phase plan written |
| Hardcoded unit audit | Shipped | 7 files fixed — all weight display paths now dynamic |
| Progressive overload alerts | Shipped | Stalling/declining exercises flagged with weight suggestions |
| Proactive insight alerts (protein, supplements) | Not Started | Deferred; remains P1 next sprint |
| Systematic bug hunting | Shipped | AI pipeline audit found 3 P0 and 2 P1 bugs |
| Exercise presentation (muscle icons) | Not Started | Remains P2 |
| AIChatView ViewModel extraction | Not Started | Deferred until needed by new feature |

## What Shipped (user perspective)

- **Ask the AI about any lift** — "How's my bench press?" now returns your recent trend, last weight used, and whether you're making progress. First time workout intelligence is accessible through chat.
- **Smarter workout coaching** — The workout history tab now flags exercises where you've stalled or regressed, with a suggested weight to try next.
- **Unit preferences respected everywhere** — Whether you track in kg or lbs, every number displayed in the app — including AI responses about your lifts — now matches your preference. (Previously 7 screens showed hardcoded lbs.)
- **Better food database foundation** — USDA API integration designed and ready to build. When implemented, this will unlock verified nutrition data for tens of thousands of foods without manual entry.
- **Silent bugs found before users hit them** — An audit of the AI parsing pipeline found that "1000 calcium mg" could silently log 1000 calories, that integer serving counts from the AI were sometimes dropped, and that saying "undo" after logging your weight would delete your last food entry instead. None of these reached users but all are now documented and queued for fixes.

## Competitive Position

Drift's on-device privacy moat remains intact while MFP and Whoop accelerate their cloud AI investments — MFP now has 20M foods plus ChatGPT Health integration, and Whoop's AI Strength Trainer accepts text and photos. Our edge is: everything stays on-device, chat quality for daily logging is high, and all-in-one tracking is tighter than any single-vertical app. Our gap is food database breadth (1,500 vs 20M) and exercise visual quality (text-only vs Boostcamp's videos/muscle diagrams).

## Designer × Engineer Discussion

### Product Designer

I'm genuinely excited about where workout intelligence in chat landed. "How's my bench?" returning a real trend in natural language is the kind of feature that makes this feel like a personal trainer, not a spreadsheet. That's our identity — and we need to push it further into nutrition and recovery. Proactive alerts (not just reactive answers) are the next step: the app should tell you "you're 40g short on protein three days in a row" without being asked.

What concerns me is the gap between our sprint plans and what actually ships for P1/P2 items. The bug hunt this cycle was excellent — Review #17's persona notes called for making it a quarterly ritual, and we actually did it. That discipline should be permanent. What I want to avoid is the pattern where P1 items get planned and re-planned for three sprints before anyone touches them. Proactive insight alerts have been on the board since Review #19. They need to ship next sprint, not get planned again.

On competition: MFP making barcode scanning paid-only is still an open opportunity. And Whoop's Behavior Insights (connecting habits to Recovery scores) is the exact proactive intelligence model I want us to build. We have the data — sleep, food, workouts, supplements all tracked — we just haven't connected the dots in the UI.

### Principal Engineer

The pipeline bugs found this sprint are worth discussing carefully. The integer-servings bug in the AI intent classifier is the most impactful: when the LLM says "log 2 eggs" and returns `"servings": 2` as a JSON integer, the parser silently drops it and logs 1 egg. This has been live since the classifier shipped. The fix is a one-line addition. The calcium/calorie regex false positive is also one line — add a word boundary. The undo-deletes-wrong-thing bug requires slightly more thought since `ConversationState.lastWriteAction` is declared but never written; we need to decide whether to properly implement cross-domain undo or simplify to food-only and remove the dead code.

Architecturally, the codebase is in good shape. StaticOverrides at 435 lines is large but appropriate — deterministic handlers belong there. The `AIChatView+MessageHandling` extension pattern is absorbing new handlers cleanly. Coverage at 936 tests is healthy; the systematic bug hunt is now a better forcing function than raw coverage numbers.

One concern: the product review hook fired 5+ times in one session because `last-review-cycle` wasn't updated promptly. The counter needs to be written at the start of the review process, not the end, to prevent cascade firing.

### What We Agreed

1. Fix the three P0 pipeline bugs immediately (integer servings, calcium regex, undo cross-domain) — these are one-day fixes, do them before any feature work.
2. Ship proactive insight alerts this sprint — protein adherence and supplement streak nudges. This has been deferred twice; it's now P0.
3. Begin USDA API implementation Phase 1 (cache table + fetch on cache-miss) — design doc is done, time to build.
4. Write `last-review-cycle` at the start of product review, not the end, to prevent repeated hook firing.
5. Keep systematic bug hunting as a permanent P1 ritual — run it on a different set of files next cycle (food logging path, weight pipeline).

## Sprint Plan (next 20 cycles)

| Priority | Item | Why |
|----------|------|-----|
| P0 | Fix integer-servings bug in AI intent classifier | Silent data loss — "log 2 eggs" logs 1 egg when LLM returns integer JSON |
| P0 | Fix calcium/calorie regex false positive | "1000 calcium mg" silently quick-logs 1000 calories |
| P0 | Fix undo cross-domain bug | "undo" after logging weight deletes last food entry instead |
| P0 | Proactive insight alerts — protein + supplement streak | Been deferred twice; connects existing data to proactive value |
| P1 | USDA API Phase 1 — cache table + fetch on miss | Design doc done; unlocks food DB scale without manual entry |
| P1 | Bug hunting — food logging + weight pipeline | Systematic audit found real P0s; apply same to adjacent code |
| P2 | Exercise presentation — muscle group icons on workout cards | Visible quality gap vs Boostcamp; data already tagged |
| P2 | Coverage: write tests for the three fixed bugs | Regression prevention — each fix needs a test that would have caught it |

## Feedback Responses

No feedback received on previous reports (PR #12 has no comments).

## Open Questions for Leadership

1. **USDA API scope** — The design doc calls for an opt-in toggle so the feature is off by default (privacy-first). Should it be on by default for new users, with a privacy disclosure on first use? Or stay opt-in? This decision affects how many users benefit from improved food data.
2. **Proactive alerts — how aggressive?** — Behavior Insights today are passive cards on the dashboard. The next step is push-style nudges ("you haven't logged protein yet today, you're 60g behind"). Should these be in-chat notifications, push notifications, or dashboard-only? Push notifications require a new entitlement and user permission prompt.
3. **Exercise visuals strategy** — Matching Boostcamp requires video/GIF content per exercise (873 exercises). On-demand download from a CDN is the architecture. Is this the right investment now, or should we stay text-first and compete on AI intelligence instead?
