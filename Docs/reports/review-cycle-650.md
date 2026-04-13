# Product Review — Cycle 650 (2026-04-12)
Review covering cycles 630–650. Previous review: cycle 620.

## Executive Summary

This sprint delivered 4 of 6 planned items with 67% completion — a strong velocity for features that directly improve daily-use experience. Food diary editing, meal re-logging, chat data accuracy, and workout display bugs were all fixed. The food tracking experience now rivals MyFitnessPal for editable logging, and the meal re-log feature addresses the #1 friction point for returning users. Next sprint should focus on progressive overload (our weakest vertical vs Strong/MacroFactor) and USDA API integration to close the food database gap.

## Scorecard
| Goal | Status | Notes |
|------|--------|-------|
| P0: Food diary inline editing | Shipped | DB food macros now editable via override toggle |
| P0: AI chat bug hardening | Shipped | Found and fixed meal categorization bug ("log eggs for lunch" → wrong meal type) |
| P1: Saved meals / quick re-log | Shipped | Long-press meal header → "Log All Again" or "Copy All to Today" |
| P1: Food search partial matching | Not needed | Already works via existing substring matching — verified, no code change needed |
| P2: Workout history polish | Shipped | Weight units (lb/kg) now respect user preference in history cards |
| P2: Coverage maintenance | Ongoing | 936 tests (+1), boy scout rule active |

## What Shipped (user perspective)

- **Edit macros on any food** — Tap a logged food from the database, hit "Edit macros" to override the calculated values. No more deleting and re-adding to fix portion sizes.
- **Re-log an entire meal at once** — Long-press a meal header (Breakfast, Lunch, etc.) to log all items again, or copy them all to today from a past day.
- **"Log eggs for lunch" actually logs as lunch** — Previously, saying "for lunch" in the morning would still categorize as breakfast. Now the AI respects your meal specification regardless of time of day.
- **Workout history shows correct units** — If you use kg, workout volume and best sets now display in kg instead of always showing lbs.
- **936 automated tests** — One new regression test for the meal categorization fix.

## Competitive Position

The health app market continues consolidating around AI + data density. MFP acquired Cal AI for photo scanning, Whoop raised $575M for AI coaching, Boostcamp added AI-generated programs, and MacroFactor launched a Workouts app with progressive overload automation. Our differentiation — fully on-device, no cloud, no accounts — is increasingly rare and valuable as competitors funnel user data through cloud AI. Our weakest vertical is exercise (text-only, no progressive overload automation vs MacroFactor/Strong), and food DB size (1,500 vs MFP's 20M). The meal planning dialogue and inline editing features keep our food logging UX competitive despite the DB gap.

## Designer × Engineer Discussion

### Product Designer

I'm genuinely excited about the meal re-log feature. It's the kind of "I do this every day" feature that turns an app from something you use sometimes into a habit. The food diary now has a complete editing story — you can edit macros, re-log meals, copy from past days. That's table stakes and we finally have it.

What concerns me: our exercise experience is falling further behind. MacroFactor's Workouts app launched with Jeff Nippard videos, progressive overload automation, and 300+ exercises with demos. Strong just introduced a $100 lifetime purchase — making premium workout logging accessible. Our 873 exercises are text-only with no visual guidance. We can't compete on content volume, but we could compete on AI-powered workout intelligence (smart sessions, progressive overload alerts, form tips in chat). That's our angle.

The food DB gap is less concerning now. Our 1,500 foods cover the meals our users actually eat, and the chat-first logging means users don't browse a catalog — they type "chicken biryani 300g" and it works. USDA API integration would be the right next investment if we pursue it — automated, not manual.

### Principal Engineer

The codebase is in excellent shape. The meal hint fix was a real data accuracy bug that could have caused users to see wrong macro totals per meal — glad we caught it systematically rather than from a user report. The pattern of adding `initialMealType` to FoodSearchView was clean and non-invasive.

The workout unit hardcoding was another instance of the stale preference pattern from Review #12 — we fixed it in weight views months ago but missed workout cards. I'd recommend one final audit: grep for hardcoded "lb" or "lbs" across all views and fix any remaining instances.

Coverage at 936 tests is healthy. The boy scout rule is maintaining quality without dedicated coverage sprints. The only remaining gap is IntentClassifier at 63%, but that's LLM-dependent and hard to test deterministically.

For next sprint, I'd flag that USDA API integration would be the first external network call in the entire app. It needs careful design: offline-first cache, rate limiting, privacy implications (search queries leave the device). This is architecturally significant and should be designed before implemented.

### What We Agreed

1. **Progressive overload improvements (P0)** — Our weakest competitive vertical. Add overload alerts ("you've been at 135 lbs for 3 weeks — try 140") and trend visualization to workout history.
2. **Hardcoded unit audit (P0)** — One pass to grep and fix any remaining "lb"/"lbs" hardcoding across all views.
3. **AI chat: workout intelligence (P1)** — "How's my bench progress?" should show trend data. Leverage existing progressive overload service.
4. **USDA API design doc (P1)** — Design the integration (caching, offline, privacy) before implementing. No network calls until design is reviewed.
5. **Continue boy scout coverage** — No dedicated coverage sprint; fix gaps as you touch files.

## Sprint Plan (next 20 cycles)
| Priority | Item | Why |
|----------|------|-----|
| P0 | Progressive overload alerts in workout history | Weakest vertical vs MacroFactor/Strong — users need to see progress |
| P0 | Hardcoded unit audit (grep "lb"/"lbs" across all views) | Stale preference pattern — fix remaining instances |
| P1 | AI chat workout intelligence ("how's my bench?") | Leverage existing overload service through chat — low effort, high value |
| P1 | USDA API design document | First external API — needs architecture design before code |
| P1 | Systematic bug hunting (every 5 cycles) | Meal hint bug was found via analysis — keep this cadence |
| P2 | Exercise presentation (muscle group icons on cards) | Visual polish, moves toward Boostcamp parity |
| P2 | Coverage maintenance via boy scout rule | 936 tests, maintain quality organically |

## Feedback Responses

No feedback received on previous reports (PR #10, Review #17 at cycle 620 — zero comments).

## Open Questions for Leadership

1. **USDA API priority** — Should we invest in external food database integration this quarter, or keep manual enrichment + chat-first logging? USDA adds breadth but introduces network dependency and privacy considerations.
2. **Exercise content investment** — Competitors have exercise videos and muscle diagrams. Should we invest in visual exercise content (images, muscle group maps) or double down on AI-powered workout intelligence as our differentiator?
3. **TestFlight feedback cadence** — Zero open bugs and zero user-reported issues. Should we actively solicit feedback from TestFlight testers, or let it come organically?
