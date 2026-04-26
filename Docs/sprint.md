# Sprint Board

Focus: **AI Chat Quality (highest priority every sprint).** Cycle 7485: close remaining 2 failing-query categories (macro goals #440→#441, micronutrients #442), run FoodLoggingGoldSetTests + fix failures, prompt quality audit from telemetry, weight_trend_prediction analytical tool. Build 175 on TestFlight.

## Regression Gate

**All pipeline gold sets at 100% baseline.** Any AI change MUST run BOTH before AND after:
1. `cd DriftCore && swift test` (deterministic, ~0.1s warm — FoodLoggingGoldSetTests, IntentClassifierGoldSetTests, etc.)
2. `xcodebuild test -scheme DriftLLMEvalMacOS -destination 'platform=macOS'` (LLM-loaded, ~5min — requires models at `~/drift-state/models/`)

## In Progress

_(pick from Ready)_

## Ready

### P0 — AI Chat Quality (Senior)

- [ ] **#457 FoodLoggingGoldSetTests run cycle 7485 + fix failures** — Run `cd DriftCore && swift test -filter FoodLoggingGoldSetTests`. Fix any failures via prompt improvement (never StaticOverrides as first response). Report: cases run, failures fixed, final pass rate.

- [ ] **#440 Non-weight goal setting** — "set my calorie goal to 2000" / "set protein target to 150g". Adds `calorieGoal` and `proteinGoal` to UserPrefs + DB migration + set_goal tool extension. **Must ship before #441 — #441 reads these columns.** Do NOT add carbGoal/fatGoal in same migration (scope strictly).

- [ ] **#441 Macro goal progress queries** — "am I hitting my protein goal?" compares food_info intake vs UserPrefs.proteinGoal. **Depends on #440 migration landing first.** Do not claim this until #440 is committed and tests pass.

- [ ] **#442 Micronutrient per-entry tracking** — DB migration v35: add nullable `fiber_g REAL`, `sodium_mg REAL`, `sugar_g REAL` to FoodEntry. All aggregation via `COALESCE(fiber_g, 0)`. Populate at log-time from Food table. No backfill of historical rows.

### P1 — Senior

- [ ] **#458 LLM prompt quality audit cycle 7485** — Read telemetry failures, cluster by failure mode, update Stage 1/3 prompt examples (2-3 per cluster), add 5+ eval cases. Run eval before and after. Report: cases added, failures fixed.

- [ ] **#463 weight_trend_prediction analytical tool** — "at this rate, when will I hit 75kg?" Linear regression on 30-day weight history → slope + projected goal date. Edge cases: <7 entries → "not enough data", goal already reached, slope ≈ 0. Return `{ trend_kg_per_week, days_to_goal?, predicted_date?, r2, insufficient_data }`. 6 Tier-0 unit tests required.

- [ ] **#449 IntentClassifier tie-break v2** — Context-aware: read ConversationState.phase as a copied value before LLM inference (thread safety). Only escalate to clarification when phase context genuinely can't resolve the tie.

- [ ] **#447 /debug last-failures chat command** — Surface recent AI pipeline failures from telemetry. Gate to `#if DEBUG` builds. XCTest verifying DebugCommandService unreachable from release scheme.

### P1 — Junior

- [ ] **#459 State.md refresh to build 175** — Update build, test counts, food DB count, tools count, context window, AI system stats to reflect actual current state.

- [ ] **#460 failing-queries.md refresh cycle 5965→7485** — Promote fixed items (historical dates ✓, calorie goals ✓). Document any new failing patterns observed. Keep "Failing" section current.

- [ ] **#464 FoodLoggingGoldSet +10 — Indian meal combinations** — Add 10 eval cases: dal chawal, rajma chawal, chole bhature, biryani with raita, idli sambar, dosa with chutney, roti with sabzi, poha, upma, khichdi. All cases assert: correct tool (`log_food`), ≥1 food item identified, no empty result.

- [ ] **#461 Food DB +30 — German/Austrian/Swiss cuisine** — Schnitzel, bratwurst, pretzels, sauerbraten, käsespätzle, strudel, rösti, fondue, Zürcher geschnetzeltes, Black Forest cake. Verify macros via USDA/reliable source.

- [ ] **#462 Food DB +30 — Greek & Balkan cuisine** — Moussaka, spanakopita, souvlaki, tzatziki, dolmades, baklava, börek, ćevapi, burek, ajvar. Verify macros.

---

## Permanent Tasks (never remove — always pick from these when nothing else is queued)

**AI chat quality is the product's core value. Every session must improve it. No sprint is complete without AI chat being better than when it started.**

**Before picking a task, read `Docs/roadmap.md` → "Now" items in the relevant domain. Work on what advances the current phase.**

### LLM Eval Quality Loop (60% of every sprint — non-negotiable)

- [ ] **Every sprint: run → fix → expand → audit**
  1. **Run** `cd DriftCore && swift test` — any failure is a P0, fix it now
  2. **Fix via prompt first** — change an example, reorder, tighten the RULES line. StaticOverride only if prompt tuning fails twice
  3. **Expand** — add 3+ new test cases from real user phrasings (not keywords). Pick a domain with <5 cases and add variants
  4. **Audit** — pick one domain and add 3 edge-case variants: messy spelling, implicit intent, slang
  5. **Retire** — check if any StaticOverride is now handled by the LLM at 100%. Remove it if so

### AI Chat Architecture & Quality (always ongoing)

- [ ] **Multi-turn reliability** — 3-turn meal logging, 3-turn workout building, topic switching mid-conversation.
- [ ] **Conversation memory** — Cross-session context: persist last 5 turns to disk, inject at session start (#436).
- [ ] **USDA API Phase 2** — Proactive food DB source from USDA FoodData Central (400k+ foods, free API, Phase 1 infra live). (#345)
- [ ] When no obvious gap: stress-test with 10 real-world queries per domain in IntentRoutingEval.swift, run eval, fix what fails.

### UI Overhaul (always ongoing)

- [ ] **Theme overhaul** — Bold changes encouraged. App-wide consistency required.
- [ ] **Chat UI polish** — Per-stage elapsed time indicator (#309), streaming UX improvements.
- [ ] **Food diary UX** — Faster logging, meal grouping, clearer macro display.

### Test Coverage Improvement (always ongoing)

- [ ] **Run `cd DriftCore && swift test`** — All Tier-0 tests must pass.
- [ ] **Run coverage-check.sh** — Fix files below 80% logic / 50% services threshold.
- [ ] **AI eval harness expansion** — Every tool needs 10+ eval queries.

### Bug Hunting (always ongoing)

- [ ] **Find and fix bugs** — Run the app mentally through edge cases. Check error paths, empty states, boundary conditions.
- [ ] **Regression prevention** — When fixing a bug, add a test that would have caught it.

### Food Database Enrichment (always ongoing)

- [ ] **Add missing foods** — Indian foods, regional dishes, restaurant items, branded products. Cross-reference with USDA/reliable sources.
- [ ] **Correct existing entries** — Find foods with wrong macros, missing data, bad serving sizes.

---

## Done (cycle 7485 planning — tasks queued this cycle)

- [x] Sprint tasks created: #457–464 (8 tasks: 3 SENIOR, 5 JUNIOR)
- [x] Product review PRs: #455 (cycle 7410), #456 (cycle 7448)
- [x] Personas updated (product-designer.md, principal-engineer.md)
- [x] Roadmap updated

## Done (build 175 — cycle 7448 review)

- [x] **Historical weekday queries fixed** — "last Tuesday" / "on Monday" → correct date via `weekdayDateString()` + `historicalDaySummary()`. Two query variants supported.
- [x] **Calorie goal setting fixed** — "set my calorie goal to 2000" → sets `WeightGoal.calorieTargetOverride` via StaticOverrides, reflected in `resolvedCalorieTarget()`.
- [x] **DriftCore pure-logic test migration** — Waves 2–6 moved to DriftCoreTests. `swift test` runs in ~0.1s. DriftRegressionTests target retired.
- [x] **5-tier test map documented** — CLAUDE.md decision tree prevents future test misplacement.
- [x] **Harness reliability** — Sessions reach task loop; `gh` errors surface; commit scoping prevents cross-agent pollution.
- [x] **TestFlight build 175**

## Done (cycle 5965 sprint — closed failing-query categories)

Tasks #439–452: historical dates, calorie goals, East Asian/Caribbean/Southeast Asian food DB, debug command, PhotoLog eval, tie-break v2, prompt audit, failing-queries refresh.

## Done (earlier sprints)

Sprint history archived. See git log for commit-level detail.
