# Product Review — Cycle 1483 (2026-04-13)
Review covering cycles 1424–1483. Previous review: cycle 1380 (Review #36).

## Executive Summary

Push notifications finally shipped after being deferred across 4 consecutive reviews — Drift now actively nudges users about missed protein, supplements, and workouts. Exercise coaching landed in chat ("How do I deadlift?"), and a systematic bug hunt caught and fixed query parsing issues that were silently breaking plural and natural-language exercise lookups. Tests grew from 981 to 1,037. The app is transitioning from passive data tracker to proactive health coach.

## Scorecard
| Goal | Status | Notes |
|------|--------|-------|
| P0: Push notifications | **Shipped** | Protein, supplement, and workout gap alerts via local notifications. 6pm daily, settings toggle, permission flow. |
| P1: Exercise instructions via chat | **Shipped** | "How do I deadlift?" returns form tips, muscles, equipment from 873-exercise database. |
| P1: Systematic bug hunt | **Shipped** | Found and fixed exercise query parsing bugs (plurals, trailing punctuation). 4 regression tests. |
| P2: sendMessage decomposition | Not Started | Deferred — not blocking any features. |

## What Shipped (user perspective)

- **Health nudge notifications** — If you miss protein 3+ days, skip supplements, or haven't worked out in 5 days, the app sends a timely evening reminder. All on-device, no cloud.
- **Exercise form coaching in chat** — Ask "How do I do a bench press?" and get form tips, target muscles, and equipment info instantly from the built-in exercise database.
- **Smarter exercise lookups** — Asking about "deadlifts" (plural) or "squat, please?" now works correctly. Previously these natural phrasing variants silently returned no results.
- **Muscle group heatmap with volume shading** — The muscle recovery card now visually shows training volume through opacity intensity, not just numbers. Overtrained groups glow brighter.
- **Sprint board in Command Center** — Sprint plan status is now visible in the web dashboard, synced from the repo.
- **TestFlight build 112** — All features above available to testers.

## Competitive Position

Push notifications close a critical gap — Whoop's AI Coach and MFP's premium tools both use proactive nudges, but they're cloud-dependent and behind paywalls ($20-30/mo). Drift does it free, on-device, with zero data leaving the phone. Our exercise coaching via chat leans into the AI-first identity that competitors can't easily replicate on-device. The remaining gap is visual exercise content (images, videos) where Boostcamp still leads, and food database breadth where MFP's 20M entries dwarf our 1,500.

## Designer × Engineer Discussion

### Product Designer

I'm genuinely excited about this sprint. Push notifications were my #1 ask for four consecutive reviews, and the implementation nails the user experience — permission is requested only after the first food log (not on launch), alerts combine into one evening notification instead of spamming, and the settings toggle is clean. This is what separates a health coach from a data logger.

Exercise instructions in chat reinforces our AI-first positioning. When a user asks "How do I squat?" and gets instant form tips, it feels like having a personal trainer in your pocket. The bug fix for plurals and trailing phrases was important — real people say "deadlifts" not "deadlift," and silently failing on natural language undermines trust in an AI-first product.

My concern: we're at a crossroads between depth and breadth. All the "Now" items on the roadmap are done. We need to decide what Phase 3c "Polish & Depth" means in the next 20 cycles. I think the answer is daily-use refinement — the features people touch every single day (food diary, workout logging, dashboard) should feel faster and more polished than any competitor. Not new features, but making existing features feel effortless.

### Principal Engineer

Sound sprint from a technical standpoint. Push notifications via UserNotifications framework is the right architecture — local-only, no background fetch dependency, graceful degradation when permission is denied. The BehaviorInsightService reuse for condition detection was clean; no new alert logic needed.

The exercise instruction pipeline (regex capture → ExerciseDatabase.search → formatted response) is solid but the plural/punctuation bug showed the regex approach has a natural ceiling for natural language. The retry-with-singular-fallback is pragmatic — it handles 95% of cases without adding NLP complexity. If we see more edge cases, the long-term answer is routing exercise queries through the LLM intent classifier instead of regex.

Test count at 1,037 (+56 from last review) is healthy. Coverage gaps: NotificationService has zero unit tests (it's all integration with UNUserNotificationCenter). The BehaviorInsightService alert detection logic should have dedicated edge-case tests. Neither is blocking, but both should be addressed this sprint.

sendMessage at 491 lines continues to be the largest technical debt item. It's not blocking features today, but every AI chat feature makes it worse. I'd prefer to tackle it when the next chat feature requires touching that code.

### What We Agreed

1. **All P0/P1 roadmap "Now" items are done.** Next sprint focuses on daily-use polish and reliability, not new features.
2. **sendMessage decomposition** moves to P1 — it's been deferred twice and the 491-line method is a maintainability risk. Do it as a pure refactor with no behavior change.
3. **Food search quality** is the highest-friction user moment. Search miss analysis and targeted additions should be a sprint item.
4. **NotificationService and BehaviorInsightService tests** to harden the new push notification feature.
5. **State.md update** — test count, build number, and capabilities list are stale.

## Sprint Plan (next 20 cycles)
| Priority | Item | Why |
|----------|------|-----|
| P0 | sendMessage decomposition | 491-line method deferred twice. Pure refactor, no behavior change. Prevents future AI chat work from becoming painful. |
| P1 | Food search miss analysis + targeted additions | Every "not found" sends users to MFP. Identify top-searched missing foods, cross-reference USDA, add them. |
| P1 | Notification + behavior alert test coverage | New push notification feature has zero unit tests. Add edge-case tests for alert detection logic. |
| P1 | Systematic bug hunt | Quarterly practice. Focus on notification scheduling, food diary edge cases. |
| P2 | State.md refresh | Stale — tests at 1,037 not 981, build 112, capabilities list needs update. |

## Feedback Responses

No feedback received on Review #36 (PR #38, cycle 1404). PR has zero comments.

## Cost Since Last Review
| Metric | Value |
|--------|-------|
| Model | Opus |
| Sessions | 3 |
| Est. cost | $162.94 |
| Cost/cycle | $0.11 |

## Open Questions for Leadership

1. **Phase 3c wrap-up or Phase 4?** All "Now" roadmap items are shipped. Should we declare Phase 3c complete and move to Phase 4 (iOS widgets, Apple Watch), or spend another sprint cycle on polish and reliability?
2. **Food DB strategy:** Manual enrichment (slow, curated) vs. USDA API default-on (fast, privacy tradeoff)? The toggle is shipped but defaulted OFF. Should we change the default for new users?
3. **TestFlight expansion:** We're at build 112 with a stable feature set. Is it time to expand the TestFlight group beyond friends/family for broader feedback?
