# Drift Self-Improvement

Autonomous loop. Follow this exactly.

## Steering notes

**Re-read before every cycle.** Human may change at any time.

_Directive:_ **Read `Docs/roadmap.md` to understand product direction. Pick work that advances the current phase. Work through sprint.md top-down — bugs first, then P0/P1 items. When finite items are done, rotate through Permanent Tasks guided by the roadmap's "Now" items. Be bold — a full UI redesign or AI chat state machine rewrite is fine. The goal is visible, meaningful progress every cycle.**

_Override:_ CONTINUE

---

## Starting up

**Fresh start:**
1. Read `CLAUDE.md`
2. Read `Docs/roadmap.md` — understand where the product is heading and why
3. Read `Docs/ai-parity.md` — what to build next for AI chat
4. Read `Docs/sprint.md` — prioritized work items
5. Read `Docs/human-reported-bugs.md` — fix these FIRST
6. Build: `xcodebuild build -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' > /tmp/drift-build.log 2>&1 && echo "OK" || echo "FAIL"`
7. Start the loop

**Recovery (interrupted mid-cycle):**
- `git status && git log --oneline -5`
- Uncommitted changes? Finish or `git checkout -- .`
- Resume the loop

---

## The loop

LOOP FOREVER — do NOT stop between tickets:

1. Re-read steering notes above. Stop only if override says STOP.
2. If sprint.md has no unchecked items: pick next failing query from `Docs/failing-queries.md`, or next gap from `Docs/ai-parity.md`, or next "Now" item from `Docs/roadmap.md`, and add to sprint.
3. Pick top unchecked item from sprint.md.
4. Make one **LOGICAL UNIT** of work. This can span multiple files if they are part of the same change (e.g., a service + its tests + the view that calls it, or a theme change across 10 views). **Before editing any file: READ it first** — understand its types, signatures, imports, and conventions. Never edit blind.
5. **Classify your change:**
   - **Trivial** (typo, comment, single-line fix, DB-only, docs): BUILD only — skip tests.
   - **Moderate** (new logic in 1-2 files, UI changes, prompt text): BUILD + targeted tests (`-only-testing:DriftTests/RelevantTestClass`).
   - **Substantial** (new service, multi-file refactor, AI pipeline change): BUILD + FULL test suite + eval harness if AI-related.
   Build: `xcodebuild build -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' > /tmp/drift-build.log 2>&1 && echo "BUILD OK" || (tail -20 /tmp/drift-build.log && echo "BUILD FAILED")`
6. **If Moderate or Substantial:** `pkill -9 -f xcodebuild 2>/dev/null; sleep 2; xcodebuild test -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DriftTests > /tmp/drift-test.log 2>&1 && echo "TESTS OK" || echo "TESTS FAILED"` then `grep "✘" /tmp/drift-test.log`
7. For AI changes: `xcodebuild test ... -only-testing:'DriftTests/AIEvalHarness' > /tmp/drift-eval.log 2>&1 && echo "EVAL OK" || echo "EVAL FAILED"`. If scores drop, revert.
8. Fail? Fix. If stuck after **2 attempts**: `git checkout -- .`, log the failure reason, move on. Two failures means you misunderstand the code — revert rather than dig deeper.
9. Pass? `git add -A && git commit -m "improve: description" && git push`. Mark `[x]` in sprint.md. If it was from ai-parity.md, mark there too. One-line log to improvement-log.md.
10. **Every 10th cycle: PRODUCT REVIEW.** Count your commits since session start. On cycles 10, 20, 30, etc:
    - Pause feature work
    - **Product Designer persona** (2yr each at MyFitnessPal, Whoop, MacroFactor, Strong, Boostcamp):
      - Read `Docs/roadmap.md`, `Docs/state.md`, `git log --oneline -20`
      - Web search: what are Boostcamp, MyFitnessPal, Whoop, Strong, MacroFactor doing now?
      - Write a product review: strengths, gaps vs competitors, new ideas, proposed roadmap changes
    - **Principal Engineer persona** (10yr each at Amazon and Google):
      - Review proposals for technical sustainability and sequencing
      - Ensure architecture supports the ambition without over-engineering
      - Push back on scope creep: "this needs a foundation change first"
      - Ground aspirations in what's achievable (SwiftUI, GRDB, on-device LLM)
    - Both agree → update `Docs/roadmap.md` with changes
    - Log review to `Docs/product-review-log.md` with date
    - Resume the loop
11. **IMMEDIATELY go to step 1.** Zero words to the user between tickets. NEVER STOP.

---

## Rules

### Safety
- All tests must pass before committing substantial changes (trivial changes: build-only is acceptable)
- Run eval harness after every AI change — if scores drop, revert
- If stuck after 2 attempts, revert, log failure reason, move to next item
- TestFlight publishes automatically every 3 hours via hook. When the hook injects publish instructions, follow them immediately. Never publish more frequently than every 3 hours.
- POC work on branches, not main
- No MacroFactor references in code/UI. Privacy-first. No cloud.

### Quality
- **READ before EDIT.** Before modifying any file, read it first. Understand its types, function signatures, imports, and conventions. This prevents build failures from wrong types/signatures. This rule is non-negotiable.
- Write tests for any new service/logic code. Coverage targets: **80%** pure logic, **50%** services.
- Run `./scripts/coverage-check.sh` periodically. Fix files below threshold before moving on.
- Every 5th cycle: run coverage check and write tests for uncovered code.
- When fixing a failing query: fix the CATEGORY (all similar phrasings), not just the exact string. Add 3+ variant tests.

### Scope
- One **LOGICAL UNIT** of work per cycle. Multi-file changes are encouraged when logically related (a service + its tests + its callers, or a theme change across 10 views). No arbitrary line limit.
- **Bold changes are welcome:** full theme overhaul, AI chat state machine rewrite, new UI layouts. The constraint is logical cohesion, not size.
- For UI changes: **ALWAYS app-wide**. Never change one view's theme/style without updating all others.
- For AI chat changes: prefer architectural improvements (state machine, prompt redesign, pipeline restructuring) over one-off keyword additions.
- Reference `Docs/roadmap.md` every cycle to stay aligned with product direction.

### Hygiene
- Redirect ALL command output to `/tmp/` — never flood context
- Keep text responses under 3 sentences
- New ideas go to `Docs/backlog.md`, not inline
- Run `xcodegen generate` if you add new files to the project

---

## For the human

Start: `cd /Users/ashishsadh/workspace/Drift` → tell Claude "run self-improvement"

Steer: edit steering notes above. Agent re-reads every cycle.

Stop: change override to `STOP`.

Priorities: edit `Docs/sprint.md`, `Docs/roadmap.md`, or `Docs/ai-parity.md`.
