# Sprint Board

Focus: **Implement Multi-Stage LLM Pipeline (Design Doc #65).** Design doc merged (PR #112). Build the 6-stage pipeline: normalize → intent classify → domain extract → Swift validate → confirm → execute. Gemma path only — SmolLM keeps current rules-first pipeline unchanged.

## Regression Gate

**55-query gold set at 100% baseline.** Every pipeline task MUST run gold set eval before AND after. If accuracy drops, the task is not done.

## In Progress

_(pick from Ready)_

## Ready

### Phase 1 — Foundation (start here)

- [ ] **#92 Stage 2: Intent classifier (classification-only prompt)** — Replace unified IntentClassifier with a focused prompt that returns `{domain, intent}` ONLY. No extraction. Domains: food/exercise/weight/supplement/health/navigation/chat. Run gold set eval before AND after. Reference: `Docs/designs/65-fix-ai-chat.md` Stage 2.
- [ ] **#129 Stage 0+1: Wire pipeline skeleton** — Create the multi-stage pipeline orchestrator in AIToolAgent for Gemma path. Stage 0 (InputNormalizer, exists) → Stage 1 (trimmed StaticOverrides, ~10 patterns: greetings, undo, help, barcode, navigation) → Stage 2 (intent classifier) → routing to Stage 3. SmolLM path unchanged.

### Phase 2 — Domain Extractors (after #92 is stable)

- [ ] **#95 Stage 3: Domain-specific extraction prompts** — One specialized prompt per domain (food, exercise, weight, supplement). Each extracts only the params relevant to its domain. Food extractor: multi-item split, portions, meal type. Exercise extractor: sets/reps/weight, duration. Run gold set eval before AND after.
- [ ] **#130 Stage 3b: Swift validation between stages** — Wire existing parseFoodIntent/regex extraction as validation fallback after LLM extraction. Reject nonsense, fix types, sanity-check extracted params before confirmation.

### Phase 3 — Cleanup (after Phase 2 passes eval)

- [ ] **#93 Prune StaticOverrides to ~10 essential patterns (Gemma path)** — Only after #92+#95 prove they handle what StaticOverrides currently catches. Keep all StaticOverrides for SmolLM path. Run gold set eval before AND after.
- [ ] **#94 Retire ToolRanker keyword scoring (Gemma path)** — Remove `tryRulePick()` for Gemma. Keep `rank()` for SmolLM and `buildPrompt()` for streaming fallback. Last cleanup step. Run gold set eval before AND after.

### Phase 4 — Stabilize

- [ ] **#96 Coverage: Pipeline refactor tests** — After pipeline changes land, ensure coverage targets hold (80% logic, 50% services). New files (intent classifier, domain extractors) need unit tests.
- [ ] **#131 Update state.md + roadmap** — Reflect new pipeline architecture, updated test counts, build number after pipeline ships.

### Design Docs (pending review — not this sprint)
- #66 Design: How to enrich images and youtube in exercises — `doc-ready`, `approved`
- #74 Feature: Improve lab reports upload + LLM parsing — `doc-ready`

---

## Dependency Chain

```
#92 (intent classifier) + #129 (pipeline skeleton)
        │
        ▼
#95 (domain extractors) + #130 (Swift validation)
        │
        ▼
#93 (prune StaticOverrides) + #94 (retire ToolRanker)
        │
        ▼
#96 (coverage) + #131 (docs)
```

Do NOT start a later phase until the previous phase passes gold set eval at 100%.

---

## Permanent Tasks (never remove — always pick from these when nothing else is queued)

**Before picking a task, read `Docs/roadmap.md` → "Now" items in the relevant domain. Work on what advances the current phase.**

### AI Chat Architecture & Quality (always ongoing)
Equally important pillar. Prefer architectural improvements over keyword additions.

- [ ] **State machine refactor** — Replace scattered pendingMealName/pendingWorkout state vars with a proper conversation state machine. States: idle -> classifying -> executing_tool -> confirming -> logging. Clear transitions, no dangling state.
- [ ] **Prompt consolidation** — Single source of truth for tool schemas, examples, context injection. Measure token count, compress.
- [ ] **Multi-turn reliability** — Eliminate bugs where context is lost between turns. Test: 3-turn meal logging, 3-turn workout building, topic switching mid-conversation.
- [ ] **Natural freeform logging** — "log for breakfast 2 eggs and spinach and bread and coffee with 2% milk with protein powder and creatine" or "log chipotle bowl with 800 calories" -> AI parses everything, asks clarifying questions, does macro calculations, logs it.
- [ ] **Meal planning** — "plan my meals for today" -> iterative suggestions based on remaining macros + history.
- [ ] **Workout split builder** — "build me a PPL split" -> multi-turn designing across sessions.
- [ ] **Navigate to screen** — "show me my weight chart", "go to food tab". Needs navigation tool.
- [ ] When no obvious gap: stress-test with real queries from `Docs/failing-queries.md` and fix what breaks.

### UI Overhaul (always ongoing)
Equally important pillar. Bold changes encouraged — a full theme redesign overnight is fine. New card styles, new color palette, new typography — go for it. The only rule: app-wide consistency.

- [ ] **Theme overhaul** — Pick a direction and execute across ALL views in one cycle. Dark+accent, light+minimal, glassmorphism — any coherent vision. Touch every view.
- [ ] **Dashboard redesign** — Better information hierarchy, scannable at a glance, clearer progress indicators.
- [ ] **Chat UI polish** — Message bubbles, typing indicators, tool execution feedback, streaming UX.
- [ ] **Food diary UX** — Faster logging flow, better meal grouping, clearer macro display.
- [ ] **Usability rough edges** — Find confusing flows, missing feedback, awkward transitions. Fix them.
- [ ] UI changes must NOT break existing functionality. Visual-layer refactoring only.

### Test Coverage Improvement (always ongoing)
Ship quality. Coverage is a forcing function for finding bugs and understanding code.

- [ ] **Run coverage-check.sh** — Identify files below 80% (logic) or 50% (services) threshold. Fix them.
- [ ] **Write tests for uncovered paths** — Focus on error paths, edge cases, empty states, boundary conditions. Not just happy paths.
- [ ] **AI eval harness expansion** — Add test cases for every new capability. Target: every tool has 10+ eval queries.
- [ ] **Integration-style tests** — Test multi-step flows (parse -> resolve -> log -> confirm) end-to-end.

### Bug Hunting (always ongoing)
Proactively find bugs before users do.

- [ ] **Find and fix bugs** — Run the app mentally through edge cases. Check error paths, empty states, boundary conditions, data corruption scenarios.
- [ ] **Regression prevention** — When fixing a bug, add a test that would have caught it.

### Food Database Enrichment (always ongoing)
Better the DB, more people will come and log. Benchmark: MyFitnessPal has 14M+ foods.

- [ ] **Correct existing entries** — Find foods with wrong macros, missing data, bad serving sizes. Fix them.
- [ ] **Add missing foods** — Indian foods, regional dishes, restaurant items, branded products. Cross-reference with USDA/reliable sources.
- [ ] **Improve search** — Better aliases, spelling corrections, partial matches. "paneer" should find all paneer dishes.

### Ongoing: Code Improvement Loop
Autonomous refactoring. Run `code-improvement.md`. Principles in `Docs/principles/`. Log in `Docs/code-improvement-log.md`.

- [x] **Continue file decomposition** — GoalSetupView, LabsAndScans, Sleep, TemplatePreviewSheet extracted. Only 3 files over 700 remain (AIChatView, FoodTabView, ActiveWorkoutView) — these need ViewModel extraction.
- [ ] **Deeper refactoring** — Extract logic from fat functions (AIChatView.sendMessage 491 lines). Move business logic out of views into ViewModels/Services.
- [ ] **DDD violations** — Direct DB calls in views, business logic in UI layer.

## Done (this sprint)

_(new sprint — nothing yet)_

## Done (previous sprint)

- [x] #121 Food confirm-first on all 5 paths (13dbfbe)
- [x] #123 state.md verified accurate: build 120, foods 1641, tests 1324+
- [x] #97 Bug hunting: 2 confirm-first bugs fixed (5fa3ce4, 0882b9b)
- [x] #120 Revised design doc #65 (PR #112) — all 3 owner comments addressed (98c06ab)
- [x] #122 Multi-stage pipeline research — documented in #65 revision
- [x] #65 Design doc merged (PR #112). Implementation unblocked.
