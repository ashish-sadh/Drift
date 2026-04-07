# Sprint Board

## In Progress

- [ ] **P1: SLM Tool-Calling Architecture** — Restructure AI system so each service is a tool the model invokes. Current: keyword matching + action tags. Target: model outputs tool_call JSON. See `architecture.md`.
- [ ] **P2: Conversational Workout Builder** — Three flows: (A) start template from chat, (B) build workout from conversation, (C) AI suggests based on history. CREATE_WORKOUT and START_WORKOUT action tags work. Direct template start works.

## Ready (pick up next)

- [ ] **FEAT-001: Calorie Estimation** — "How many calories in X?" DB lookup works instantly. LLM fallback for unknown foods needs testing. See `human-reported-bugs.md`.
- [ ] **P3: Eval Harness Expansion** — 63 test methods (~400 cases). Target: 200+ methods. Focus: calorie estimation, calories remaining, multi-turn, ambiguity.
- [ ] **Tool Schema Definition** — Write JSON schemas for each tool the SLM can call. Start with food + weight + workout.

## Done This Sprint

- [x] BUG-001: "Calories left" showed TDEE instead of remaining (fixed — clarified context format)
- [x] Action tags always in system prompt + all screen contexts
- [x] Removed 3 hardcoded handlers (workout prompt, food guidance, restaurant) → LLM handles
- [x] Direct template start: "start push day" matches templates instantly
- [x] Food parser: beverages (drank), snacks (snacked on), cooking (made, i'm having)
- [x] Synced multi-food parser verbs with single-food parser
- [x] Enhanced workout context: body part coverage, exercise details, suggest-don't-auto-start
- [x] CREATE_WORKOUT includes reps + weight in template notes
- [x] Few-shot examples in system prompt
- [x] Tightened 8 keyword false positives (fast, rest, press, run, doing, better, worse, energy)
- [x] Fixed action tag stripping bug (parse from raw response, not cleaned)
- [x] Instant nutrition lookup from chat for DB-matched foods
- [x] Response cleaner: markdown bullets, numbered lists, regurgitation, prompt echo detection
- [x] Bullet + numbered list regex: line-start only (preserves -300kcal, 1500. sentence)
- [x] Weight false positive: "chicken weighs 200g" no longer parsed as body weight
- [x] Glucose/biomarker keyword overlap fixed
- [x] Calorie target floored at 500 in all code paths
- [x] 41 self-improvement cycles, 63 eval tests, build 84
