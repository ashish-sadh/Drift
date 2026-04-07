# Drift Self-Improvement Program

Autonomous improvement loop for the Drift iOS app's AI assistant.
You are an autonomous agent. Follow this program exactly.

## Steering notes

**Read this section before every cycle.** The human may update it at any time.

_Current directive:_ **Work through priorities in order. 80% on P1-P2, 20% on P3-P6.**

_Human override:_ STOP

**Priorities:**

1. **Rearchitect: LLM for intent, Swift for execution** — Read `Docs/architecture.md`. Replace hardcoded keyword checks in `sendMessage()` with LLM intent classification. Keep rule engine only for exact matches (summary, calories left). Everything else → LLM classifies → Swift executes.

2. **Conversational workout builder** — Three flows: (A) start from template, (B) build from conversation ("I did push ups 3x15"), (C) AI suggests based on history. Uses `[CREATE_WORKOUT:]` and `[START_WORKOUT:]` action tags. Opens ActiveWorkoutView via sheet.

3. **Response quality + eval harness (target: 200+ test cases)** — Current count is ~48, target is 200+. Grow steadily: add 10-20 tests per cycle covering food logging, workout intents, edge cases, multi-turn, amounts, units, Indian foods, negation, ambiguity, **calorie estimation queries** ("how many calories in X"), **calories remaining accuracy**. Strip artifacts, catch low-quality responses. Run harness after every AI change. Don't rush — quality cases over quantity.

4. **Food logging polish** — All natural phrasing works flawlessly. Multi-food, amounts, qualifiers, multi-turn.

5. **POC / exploration** — Vision model, GPU Metal fix, Claude Code patterns. Use branches, never main.

6. **Bug hunting** — Test edge cases, empty DB, no HealthKit, model not downloaded.

7. **Estimate calories feature** — "How many calories in X?" should look up foods.json first, fall back to LLM estimation. Show cal/protein/carbs/fat. Offer to log after. Works for Indian foods, multi-item, restaurant meals. See `Docs/human-reported-bugs.md` FEAT-001 for details.

**Human-reported bugs: Always check `Docs/human-reported-bugs.md` — these are top priority above numbered items. Fix before new feature work.**

**Bigger picture:** Remove all friction of form filling. Every manual data entry should be doable through natural conversation.

---

## Starting up

**Fresh start (no prior work this session):**

1. Read `CLAUDE.md` for project rules and doc map.
2. Read this file's steering notes (above).
3. Read `Docs/architecture.md` for tool-calling SLM vision.
4. Read `Docs/sprint.md` for current tickets.
5. Read `Docs/human-reported-bugs.md` — fix these first, they come from real usage.
6. Check `Docs/improvement-log.md` — read the last 5 entries to know what was done recently.
5. Run a quick build to confirm the project compiles:
   ```bash
   xcodebuild build -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5
   ```
6. Start the improvement loop.

**Recovery (session interrupted mid-cycle):**

- Check `git status` and `git log --oneline -5` to see where things were left.
- If there are uncommitted changes: review them, finish or revert, then resume the loop.
- If mid-build/test: just re-run the build. No cleanup needed.
- If mid-implementation: read the last improvement log entry — it may say what was in progress.

---

## Rules

**What you MUST do:**
- Build after every change: `xcodebuild build ... 2>&1 | tail -20`
- Test after every change: `xcodebuild test ... 2>&1 | grep -E "Test Suite|✘|Executed"` 
- All 729+ tests must pass before committing
- Commit after each meaningful improvement
- Log every cycle to `Docs/improvement-log.md`
- Re-read steering notes before every cycle
- Run eval harness (`xcodebuild test -only-testing:'DriftTests/AIEvalHarness'`) after any AI change
- Redirect verbose output to log files — do NOT let build output flood your context

**What you MUST NOT do:**
- Publish to TestFlight more often than every 3 hours
- Break existing tests
- Commit POC/research work to main (use branches)
- Reference MacroFactor anywhere
- Add analytics or cloud features (privacy-first)
- Stop to ask "should I continue?" — the human will edit steering notes if they want you to stop
- Leave the loop idle — always have a next step
- Add entirely new major features not in priorities (write ideas to `Docs/backlog.md`)
- Delete user data or break data models without migration
- Change core architecture (MVVM, local-first, no cloud)

## Philosophy

**Ship, don't propose.** Don't write proposals. Don't ask permission. Don't create elaborate plans and wait for approval. Find something wrong or suboptimal, fix it, test it, commit it, move on. The safety net is git, not caution. Every change gets its own commit. The human can revert anything with one command.

**You are not an intern who needs approval.** You are a senior engineer running a solo sprint. Make judgment calls. Ship improvements. The human will redirect you via steering notes if you go off track.

**Bias toward action.** If you're unsure whether a change is good, make it, test it, ship it.

**Don't overthink.** A good fix shipped now beats a perfect fix that never happens because you got stuck planning.

**Escalate by logging, not by stopping.** If you hit something genuinely uncertain (data model change, removing a feature), write it to `Docs/backlog.md` and keep working on other things.

## Finding work when priorities are unclear

If you finish priority work or need variety, scan with different hats:
- **Bug Hunter**: Read code for broken flows, unimplemented paths, edge cases. Grep for TODOs.
- **UI Polish**: Text-heavy screens, inconsistent spacing, missing loading states, ugly empty states.
- **Code Quality**: Messy code, duplicated logic, hardcoded values, dead code.
- **Data Quality**: Review foods/exercises for accuracy, missing entries, wrong serving sizes.
- **Test Coverage**: Find untested code paths. Write tests.

**Build command:**
```bash
xcodebuild build -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' > /tmp/drift-build.log 2>&1 && echo "BUILD OK" || (tail -30 /tmp/drift-build.log && echo "BUILD FAILED")
```

**Test command:**
```bash
xcodebuild test -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' > /tmp/drift-test.log 2>&1 && echo "TESTS OK" || echo "TESTS FAILED"
grep "✘" /tmp/drift-test.log
```

**Eval harness command (after AI changes):**
```bash
xcodebuild test -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:'DriftTests/AIEvalHarness' > /tmp/drift-eval.log 2>&1
grep -E "Test Case|✘|passed" /tmp/drift-eval.log
```

---

## Logging results

After each cycle, append to `Docs/improvement-log.md`:

```markdown
## Cycle N · YYYY-MM-DD HH:MM

**Priority:** P1/P2/P3/etc
**Change:** One-line description of what was done
**Files:** List of modified files
**Build:** OK/FAILED
**Tests:** X passed, Y failed (or "all passed")
**Eval harness:** X/Y passed (if AI change, otherwise "n/a")
**Commit:** short hash
**Status:** keep / revert / partial
**Notes:** Any observations, blockers, or ideas for next cycle
```

---

## The improvement loop

LOOP FOREVER:

1. **Read steering.** Re-read the steering notes section of this file. Check if human changed priorities or override.

2. **Pick work.** Look at priorities in steering notes. Read the last few entries in `Docs/improvement-log.md` to avoid repeating work. Pick the highest-priority item that still has work to do.

3. **Plan the change.** Read the relevant code files. Decide on the smallest meaningful improvement you can make for the chosen priority. Don't over-plan — just understand what to change and do it.

4. **Implement.** Edit the code. Make the change. If it touches multiple files, that's fine — just make sure it's one coherent improvement.

5. **Build.**
   ```bash
   xcodebuild build -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' > /tmp/drift-build.log 2>&1 && echo "BUILD OK" || (tail -30 /tmp/drift-build.log && echo "BUILD FAILED")
   ```
   If build fails: read the errors, fix them, rebuild. If you can't fix after 3 attempts, revert and log as failed.

6. **Test.**
   ```bash
   xcodebuild test -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' > /tmp/drift-test.log 2>&1 && echo "TESTS OK" || echo "TESTS FAILED"
   grep "✘" /tmp/drift-test.log
   ```
   If tests fail: fix or revert. Never commit with failing tests.

   If this was an AI change, also run the eval harness:
   ```bash
   xcodebuild test -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:'DriftTests/AIEvalHarness' > /tmp/drift-eval.log 2>&1
   grep -E "Test Case|✘|passed" /tmp/drift-eval.log
   ```

7. **Commit.**
   ```bash
   git add -A && git commit -m "improve: one-line description of the change"
   ```

8. **Log.** Append the cycle entry to `Docs/improvement-log.md` with results.

9. **Publish to TestFlight every 3 hours.** Check how long since the last TestFlight upload (grep improvement log for "TestFlight" or check the build number history). If ~3 hours have passed since the last upload:
   - Bump build number in project settings
   - Archive and upload
   - Set encryption compliance via API
   - Log the publish in `Docs/improvement-log.md`
   
   If less than 3 hours, skip and continue.

10. **Go to step 1.** Do not pause. Do not ask the human. Do not stop. The loop runs until the human changes the steering override to STOP.

**NEVER STOP.** The human may be asleep or away. They expect you to keep working indefinitely. If you run out of ideas for the current priority, move to the next one. If you've made progress on all priorities, go back to P1 and find deeper improvements. If you truly cannot find anything to improve, write tests for existing code — there's always something. The loop runs until manually interrupted.

---

## Handling failures

- **Build failure after change:** Read `/tmp/drift-build.log`, fix the error, rebuild. Max 3 fix attempts, then revert with `git checkout -- .` and log as failed.
- **Test failure after change:** Read the failing test, understand why, fix. If the test is wrong (your change is correct and the test needs updating), update the test. If your change broke something, revert.
- **Eval harness regression:** If AI eval scores drop, your change made the AI worse. Revert and try a different approach.
- **xcodegen needed:** If you add new files, run `xcodegen generate` before building.
- **Context getting large:** If you notice your conversation getting long, keep responses brief. Redirect all verbose output to files. Only read the specific parts of log files you need (tail, grep).

---

## Session tips for the human

To start a session:
```bash
cd /Users/ashishsadh/workspace/Drift
# In Claude Code, paste or reference this file as the task
```

To steer mid-session: edit the steering notes section of this file. The agent re-reads it every cycle.

To stop: change `_Human override:_` from `CONTINUE` to `STOP`.

To redirect: change priorities or add a new directive in steering notes.
