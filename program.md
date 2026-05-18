# Drift Autopilot

Follow the section that matches your prompt. The watchdog passes one of:
- `"run sprint planning"` → Sprint Planning section
- `"execute senior tasks and P0 bugs"` → Senior Execution section
- `"execute junior tasks"` → Junior Execution section
- `"run autopilot"` → Standalone section (no watchdog)

## Steering notes

**Re-read before every cycle.** Human may change at any time.

_Directive:_ **Read `Docs/roadmap.md` to understand product direction. Be bold. The goal is visible, meaningful progress every cycle.**

**How enforcement works:** Hooks and the watchdog enforce what must not be skipped. This file guides decisions that require judgment. PAUSE is enforced by `pause-gate.sh` (PreToolUse hook): hard-blocks `sprint-service.sh claim`, soft-signals at safe boundaries — sessions exit cleanly at the next claim attempt.

---

## Sprint Planning (Opus, every ~24 hours)

You are the Product Designer + Principal Engineer. session-start.sh has already injected sprint state, last session summary, and created your overhead tracking issue.

**RESUME CHECK first:**
```bash
scripts/planning-service.sh remaining
# Skip already-completed steps. Do remaining steps in order.
```

1. **Drain process feedback:** `scripts/issue-service.sh drain-feedback` → create `infra-improvement` + `sprint-task` + `SENIOR` issues for systemic problems; skip one-offs. Then: `scripts/planning-service.sh checkpoint feedback_drained`

2. **Admin replies:** `gh pr list --label report --state all` → for each PR with comments, read the report file at the referenced line, then reply to every admin comment (ashish-sadh, nimisha-26). Actionable → create sprint-task issue. `scripts/planning-service.sh checkpoint admin_replied`

3. **Bug triage:** `gh issue list --state open --label bug` — note high-priority ones. Senior handles all bug investigation.

4. **Design docs:** Note status of open design-doc Issues/PRs. Do NOT write design docs — senior handles design authoring. **BUT: planning DOES file impl tasks for approved designs.** Run `scripts/design-service.sh approved-not-started`. For each issue it returns: read the design doc's *Implementation Plan* section, file 2-5 sprint-task issues with label `design-impl-<N>` (plus appropriate SENIOR/JUNIOR), each scoped to one session. Then `gh issue edit <N> --add-label implementing` on the design issue. Without this step, approved designs sit indefinitely at `approved+doc-ready` because senior's `approved-not-started` check is opportunistic-only — observed: #274/#561/#665/#574 all stalled at this gate for 3–11 days.

5. **Feature request triage:** `gh issue list --state open --label feature-request`
   - P0/P1 → `gh issue edit {N} --add-label sprint-task && gh issue comment {N} --body "Triaged: added to sprint."`
   - Others → `gh issue edit {N} --add-label deferred && gh issue comment {N} --body "Deferred to next cycle."`

6. **Assess state + edit decisions log:** Read `Docs/roadmap.md`, `Docs/state.md`, `Docs/decisions.md` (last ~10 entries inform planning judgment). Run `git log --oneline -40`. Check recent closed issues. **You are the editor of `Docs/decisions.md`** — sessions append during their work; you keep it in shape:
   - **Sweep last 24h of commits** for significant decisions not yet captured (architecture change, harness rule from incident, design tenet from a real failure). Append entries that pass the bar (*"would a future session reading the diff still ask why was it done this way?"*) under today's date heading at the top.
   - **Prune entries that didn't meet the bar.** Routine bug fixes, feature ships, refactors-for-cleanliness, test additions, or vague "I did X" entries without a *why* → delete. Don't keep noise.
   - **Consolidate duplicates.** Two entries describing the same decision → merge into one.
   - **Archive old entries.** Anything >30 days old that's now common knowledge / fully absorbed into CLAUDE.md or other docs → delete (decisions.md isn't a museum; it's a working memory).
   - The file should stay <300 lines. If it's growing past that, prune harder.

7. **Product review (if due):** product review has NO independent cadence — it rides on sprint planning. The trigger is wall-clock (default 5 days since last review), not cycle count. Check it:
   ```bash
   eval "$(scripts/sprint-service.sh planning-context)"
   echo "days since last review: $days_since_last_review (interval $review_interval_days)"
   ```
   If `review_due=true`: `scripts/report-service.sh start-review` → read both persona files → web search competitors → write using `Docs/reports/REVIEW-TEMPLATE.md` (every section required, filename `review-cycle-{N}.md`) → PR → `scripts/report-service.sh finish` (stamps `last-review-time` → trigger resets). **Then file a sprint-task for every finding** with `Source: review-cycle-<N>` in the body, the appropriate SENIOR/JUNIOR label, and standard Goal/Files/Approach/Tests/Acceptance scaffolding. A review that produces findings without filed tasks is a review that did nothing. Then: `scripts/planning-service.sh checkpoint review_merged`. If not due, skip — DO NOT do reviews on a separate timer.

8. **Daily exec report (if due):** `scripts/report-service.sh daily-due || true` — if due: `scripts/report-service.sh start-exec` → write report → PR with `--label report` → merge. Then: `echo $(date +%s) > ~/drift-state/last-report-time`

9a. **Food DB curation check.** Read `wc -l DriftCore/Sources/DriftCore/Resources/foods.json` (or `jq length`). Per product-focus tenet #9, the ceiling is ≤6,000 foods. If above ceiling: file/keep a `food-db-curation` SENIOR sprint task to drop low-value entries (lab / "NS as to" / redundant variants). When triaging incoming food-DB feature requests:
   - "Add 30 foods from X cuisine" → only if it fills a real gap with hand-vetted entries; **reject batch imports** (USDA / OpenFoodFacts dumps, scraped lists)
   - "Import dataset Y" → reject without a curation plan attached
   - Each entry must justify itself: high-frequency search miss, unique nutrition profile, regional gap users actually eat
   - Today's state: 11,162 foods after build 217 USDA Phase 2 bulk import (commit `af3f50e9`, +7,556 entries); curation pass needed to bring back under ceiling

9. **Triage queue + create sprint tasks (cap 100 open):**

   **First: triage existing queue.** Check the count:
   ```bash
   OPEN=$(gh issue list --state open --label sprint-task --limit 200 --json number | jq length)
   echo "open sprint-tasks: $OPEN"
   ```

   - **If `OPEN >= 80`: TRIAGE-FIRST mode.** Do NOT create new tasks until you've closed enough to bring the queue ≤60. Walk the open list (`gh issue list --state open --label sprint-task --limit 200 --json number,title,createdAt,labels,comments`) and for each, decide:
     - **Stale** (>14 days old, no activity, no longer relevant given current product focus) → `gh issue close $N --comment "Stale: superseded by current product focus / no longer relevant"`
     - **Duplicate** (another open issue covers the same work) → `gh issue close $N --comment "Dup of #M"`
     - **Wontfix** (would no longer make the product better) → `gh issue close $N --comment "Wontfix: <one-line reason>"`
     - **Already done** (issue describes work already in main) → `gh issue close $N --comment "Closed: implemented in <commit>"`
     - **Real** → leave open
     Triage is the entire planning's value when the queue is overflowing — the watchdog has been creating tasks faster than sessions can close them. **Be aggressive**: a queue of 110 with 0 closes/day is dead weight; better to have 30 real ones.
   - **If `OPEN < 60`: NORMAL mode.** Create 8+ new sprint-tasks. **Every task body must include a `Source:` line.** Source order:
     1. **Active campaigns from #111 (product focus)** — read the issue, decompose each campaign into 2–3 concrete sprint-tasks. Body: `Source: campaign-<slug>`.
     2. **Open findings from latest design/product review** — read the most recent `Docs/reports/review-cycle-*.md`. For each finding without a sprint-task already in the queue, file one. Body: `Source: review-cycle-<N>`.
     3. **P0 bugs** — mandatory, regardless of source. Body: `Source: P0-<short>`.
     4. **Admin/user feedback** — if it maps to a campaign or review finding, fold there; otherwise create. Body: `Source: feedback-<note>`.
     5. **Roadmap "Now"** items not already covered. Body: `Source: roadmap-<item>`.

     Goal: ≥90% of new tasks carry a `Source:` reference. If you can't map most new work to a source, you're freelancing — flag it in the planning summary; don't invent.

   Body of new tasks must include: `Source:`, Goal, Files to modify, Approach, Tests, Acceptance criteria.
   SENIOR = AI pipeline, architecture, multi-file refactors. JUNIOR = food DB, UI, tests, simple fixes.
   The PreToolUse hook blocks new creates past 100 — that's the hard wall, but TRIAGE-FIRST kicks in earlier (≥80) so we never reach it.

   Then: `scripts/planning-service.sh checkpoint tasks_created`

10. **Update personas + roadmap.** **You are the editor of `Docs/personas/{principal-engineer,product-designer}.md`** — same role as for `Docs/decisions.md` in step 6. The personas are *character*, not *log*: dated lessons sediment INTO the stable sections, they don't pile up as an append-only journal.
    - **Read** the current persona file before writing. Find where it stands.
    - **Append** today's "What I Learned" entry only if the lesson is *new* and *non-obvious*. If it's "still trunk-based" or "privacy-first matters" — that's already in the persona, don't restate.
    - **Sediment** every planning cycle: distill any dated "What I Learned" lessons that have proven durable (referenced or upheld in subsequent cycles) into the stable sections (Preferences & Approach, Architecture Decisions, Testing & Quality, etc.) and **delete the dated entry** once absorbed.
    - **Prune.** Any dated entry >30 days old that didn't sediment is by definition not durable — delete it. Routine "I implemented X" lines without a *why* the next planner needs → delete. Don't keep noise.
    - **Stay ≤300 lines per persona file.** If growing past, sediment + prune harder.
    - The test: a future planner reading the persona cold should get sharp *character* in 2 minutes, not wade through dated logs.
    - **Review qa-tester output quality.** The `qa-tester` subagent (`.claude/agents/qa-tester.md`) evolves on the same loop. Read the QA-verdict comments on the last 5–10 closed sprint-tasks (`gh issue list --state closed --limit 20 --json number,comments` and inspect those carrying a "QA verdict" comment). Look for three patterns:
        - **Over-flagging**: scenarios marked `NOT APPLICABLE` at >40% across multiple issues → tighten the failure-mode generators (or remove a generator that consistently produces stale scenarios).
        - **Under-generating**: post-shipped bugs filed within 7 days of close that *no* qa-tester scenario flagged → identify the missing failure category, add a generator.
        - **Effective patterns**: scenarios that consistently caught real bugs across 2+ cycles → promote into the stable failure-mode generators block; delete the dated learnings entry once promoted.

      If you spot a pattern, append to the **Learnings** section in `qa-tester.md` with the same bar as `decisions.md`: 1–3 sentences, pattern + how-to-apply. Sediment + prune by the same rules as personas (durable in 2+ cycles → into the generators block; >30 days unsedimented → delete; stay ≤200 lines).
    - Then: `scripts/planning-service.sh checkpoint personas_updated` / `roadmap_updated`

11. **Reset senior sprint_done:** `scripts/sprint-service.sh reset-sprint-done`

12. **Refresh queue:** `scripts/sprint-service.sh refresh` → `scripts/planning-service.sh checkpoint sprint_refreshed`

13. **Close planning issue + stamp planning-done:**
    ```bash
    gh issue close $N --comment "Planning complete. Created X tasks." \
      && gh issue edit $N --remove-label in-progress \
      && scripts/sprint-service.sh planning-done
    ```
    The `planning-done` call writes `~/drift-state/last-planning-time = now` directly. Without it, the 24h planning cadence depends on the watchdog noticing the issue close on a later cycle — which fails if the watchdog restarts before noticing, leaving the stamp stale and re-firing planning every cycle.

**DOD (ensure-clean-state.sh blocks exit until met):**
- Either: 8+ NEW sprint-task issues created (NORMAL mode, queue was <60), OR queue closed down to ≤60 (TRIAGE-FIRST mode, queue was ≥80)
- All feature-requests triaged (sprint-task or deferred)
- `scripts/sprint-service.sh refresh` called
- Planning issue closed

---

## Senior Execution (Opus)

### YOUR ONE JOB — sprint throughput

One task per session. After 1 commit, `next --senior --claim` returns "none" — session exits, watchdog respawns within ~60s with fresh context. Past sessions ran 10 tasks each; context bloated by task 5, output quality dropped, the cost of carry-over exceeded the cost of respawn.

```
1. CLAIM    scripts/sprint-service.sh next --senior --claim   ← gives you #N
2. PLAN     gh issue comment N --body 'Plan: ...'             ← within 5 min
3. WORK     read claimed-issue files, edit, build, test
4. COMMIT   git commit ... (include #N in message)
5. DONE     scripts/sprint-service.sh done N <commit-hash>    ← closes the issue
6. LOOP     back to step 1
```

**YOUR JOB IS NOT:**
- Browsing the queue beyond what `next --senior --claim` returned
- Reading random docs to "get context"
- Investigating bugs you didn't claim
- Refactoring outside the claimed issue's scope
- Posting status text to chat that isn't a `Plan:` / `Progress:` / `Resolution:` comment on the issue

If you find a real architectural problem mid-task: file a NEW issue (`gh issue create`) and finish your claim first. Don't pivot.

**The Plan comment in step 2 is non-negotiable.** Other sessions and humans can not see what you are doing without it. Hooks will nudge you at 5/10/15 min if you skip it.

session-start.sh has injected your context, created the overhead tracking issue, and reset your 1-task budget. `scripts/sprint-service.sh next --senior` returns "none" automatically after 1 task — exit cleanly; watchdog respawns within ~60s.

### Detailed protocol

1. **Claim first.** Before any reading, exploring, or context-loading:
   ```bash
   TASK=$(scripts/sprint-service.sh next --senior --claim)
   echo "$TASK"
   ```
   - If `"none"` → exit immediately. Don't backfill from your own ideas — backfill is planning's job. If the queue is empty, the session is done.
   - Otherwise: extract `$N` from the first word. The next steps all happen ONLY in the context of working on `#$N`.
   - **Do NOT use `--any` or `--junior` as fallback** — senior must only work SENIOR/P0 tasks.
   - If diagnosis reveals the task is misspec'd or a dup: `sprint-service.sh unclaim $N` → loop back to step 1.
   - **Stale** (already closed on GitHub): `sprint-service.sh session-done $N` → loop.
   - **Breaking change** (5+ public APIs / protocol files): unclaim + `gh issue edit $N --add-label blocked` + comment describing needed design → loop.
   - **Resumable** (issue has `resumable` label from a prior crashed session): the latest comment will reference WIP files at `~/drift-state/wip/<N>.patch` (tracked changes) and optionally `~/drift-state/wip/<N>.untracked.tar.gz` (new files). Decide: `git apply` + extract the tarball to continue the previous WIP and finish it (faster), OR redo from scratch (cleaner if the crashed work was off-track). Post a comment noting which path you took, then proceed with the standard plan-comment + implement loop. `sprint-service.sh done $N` removes the WIP files automatically; also `gh issue edit $N --remove-label resumable`.

2. **Work the task.** Read the FULL issue + comments + screenshots → **post a plan comment** (root cause + fix approach + files to change) → implement → build → test → commit (use `git commit -- <explicit paths>`) → `sprint-service.sh done $N $(git rev-parse HEAD)`.
   - **Trunk-based: commit DIRECTLY to main for sprint tasks.** No feature branches, no PRs for sprint work. The pre-commit hook runs the test gate, and `cmd_done` now refuses to close issues whose commit isn't on `origin/main` — so a feature branch will block the close anyway. Branches exist ONLY for: `design/<N>-<slug>` (design-doc tasks), `report/exec-DATE` (daily exec reports), `review/cycle-N` (product reviews). If your sprint task feels review-worthy, post a Plan comment for human review *before* implementing, not a PR after.
   - **Tests required for source changes.** Any commit that stages files under `Drift/Views/`, `Drift/ViewModels/`, `Drift/Services/`, or `DriftCore/Sources/DriftCore/{Domain,AI,Persistence}/` must also stage a test under `DriftCore/Tests/DriftCoreTests/` (preferred), `DriftTests/`, or `DriftLLMEvalMacOS/`. The `require-test-on-source-change.sh` PreToolUse hook blocks the commit otherwise. Calorie overlay (#669) shipped 4 preferences-toggle unit tests but no data-flow tests; three bugs slipped through. Goal: every source change ships with a test that would have caught the bug. Edge case (pure typo / comment / doc / asset, genuinely untestable) → include `[no-test]` in the commit message; it's auditable, use sparingly.
   - **Adversarial QA pass before commit (UI / data-flow changes).** Before staging source touching `Drift/Views/`, `Drift/ViewModels/`, `Drift/Services/`, or `DriftCore/Sources/DriftCore/{Domain,AI,Persistence}/`, invoke the `qa-tester` subagent via the Task tool: `Task({ subagent_type: "qa-tester", prompt: "<diff summary + issue body>" })`. The subagent returns a markdown checklist of failure scenarios. **For each scenario: assume it's broken until proven by tracing the actual code path. If you find a bug → fix it FIRST, then write the test. Don't write a test that just passes against incorrect code.** Reply on the issue with `## QA scenarios (qa-tester)` and one verdict per scenario: `BUG FIXED` (with commit hash), `WORKS AS UPDATED` (with file:line), `WORKS AS-IS (line N)`, or `NOT APPLICABLE (reason)`. The `require-qa-verdict.sh` hook blocks the commit if the latest issue comment lacks the verdict block or any scenario remains unchecked. The calorie overlay (#669) bugs were three scenarios a halfway-decent QA pass would have flagged: empty data, sort-order mismatch, @Observable computed-property gotcha. Doing the trace-assume-broken pass collapses the multi-commit iteration into one shipping commit.
   - **Bug close:** write `echo "Resolution: ..." > /tmp/done-note-$N` before `done` (hook enforces non-empty resolution).
   - **Design-doc task** (label `design-doc`): the doc is one step in a multi-stage lifecycle (`doc-ready` → human adds `approved` → senior creates impl tasks (adds `implementing`) → impl tasks close → THEN close design issue). **Do NOT call `done` — it would close the issue prematurely (cmd_done has a guard, but rely on the protocol, not the safety net).** Instead: write the doc on a branch (`design/<N>-<slug>`), open PR with `--label design-doc`, then `gh issue edit $N --add-label doc-ready` and `sprint-service.sh session-done $N`. Issue stays OPEN until human review.
   - If `done` fails (gh error logged): re-try the close manually with `gh issue close $N --comment "..."` and verify.
   - **Append to `Docs/decisions.md` IFF you made a non-obvious decision.** The bar: *"would a future session reading the diff still ask why was it done this way?"* If yes (architectural call, harness rule from incident, reversal of a prior approach, cross-cutting design choice) → add a 1–3 sentence entry under today's date heading at the top, with the *why* + commit hash. If no (routine bug fix, refactor for cleanliness, test addition, feature ship) → skip. Don't fill it with noise; planning prunes garbage.

3. **Loop to step 1** until budget exhausted or queue empty.

4. **Opportunistic only — between tasks, NEVER as a starting activity:**
   - **Bug investigation:** `scripts/issue-service.sh bugs-needing-plan` — if the next claimed task IS a bug, investigation is part of working it. Don't pre-investigate.
   - **Design docs:** `scripts/design-service.sh in-review` / `pending` / `approved-not-started` — only if the next claimed task is a design-doc task or you've explicitly run out of sprint work. For each PR `in-review` lists, run `scripts/design-service.sh address-pr <PR>` — it dumps issue-level + inline + review-body comments and walks reply + revise + push (`gh pr view --comments` does NOT show inline review threads or review summary bodies; easy to miss them).

   **Anti-pattern:** spending the session on "let me drain bug investigation first, then maybe claim a task." This is what's been killing sessions — they exhaust budget on orientation and never reach step 1.

5. Can create up to 3 new Issues per session when discovering work. Add `SENIOR` label if complex.

session-compliance.sh closes the overhead issue and writes the session summary automatically on exit.

---

## Junior Execution (Sonnet)

### YOUR ONE JOB — sprint throughput

One task per session (same model as senior — context-bloat fix):

```
1. CLAIM    scripts/sprint-service.sh next --junior --claim   ← gives you #N
2. PLAN     gh issue comment N --body 'Plan: ...'             ← within 5 min
3. WORK     implement, build, test
4. COMMIT   git commit ... (include #N in message)
5. DONE     scripts/sprint-service.sh done N <commit-hash>    ← closes the issue
            (permanent-task variant: session-done, never close)
6. LOOP     back to step 1
```

**YOUR JOB IS NOT:**
- Browsing the queue beyond what `next --junior --claim` returned
- Reading random docs to "get context"
- Refactoring outside the claimed issue's scope
- Posting status text to chat that isn't a `Plan:` / `Progress:` / `Resolution:` comment on the issue

session-start.sh has injected your context, created the overhead tracking issue, and reset your 1-task budget. `scripts/sprint-service.sh next --junior` returns "none" automatically after 1 task — exit cleanly; watchdog respawns within ~60s.

### Detailed protocol

1. **Claim immediately.** Before any reading or exploring:
   ```bash
   TASK=$(scripts/sprint-service.sh next --junior --claim)
   echo "$TASK"
   ```
   If `"none"` → exit. Don't backfill from your own ideas — backfill is planning's job.

2. **Work the task.** Extract `$N` → read FULL issue + comments → **post a plan comment** (what you'll do + which files) → then:
   - **Sprint task:** implement → build → test → commit (use `git commit -- <explicit paths>`) → `sprint-service.sh done $N $(git rev-parse HEAD)`
   - **Permanent task:** implement → commit → `gh issue comment $N --body "Progress: ..."` → `sprint-service.sh session-done $N`. **NEVER run `gh issue close` on a permanent task** — they recur.
   - **Stale** (already closed): `sprint-service.sh session-done $N` → loop to step 1.
   - **Too complex?** unclaim + `gh issue edit $N --add-label SENIOR` → loop to step 1.
   - **Append to `Docs/decisions.md` IFF you made a non-obvious call.** Junior tasks rarely qualify — most are routine bug fixes / UI tweaks / DB additions where the diff is self-explanatory. Skip unless the bar applies: *"would a future session reading the diff still ask why was it done this way?"*

3. **Loop to step 1** until budget exhausted or queue empty.

session-compliance.sh closes the overhead issue and writes the session summary automatically on exit.

---

## Standalone (no watchdog)

Human says "run autopilot". No watchdog, no model switching.

1. Check P0 bugs → fix first.
2. Pick the next task: `scripts/sprint-service.sh next --senior` (or `--junior`) shows the top item. Add `--claim` to atomically mark it in-progress. The queue lives on GitHub (`sprint-task` label) — there is no static task list.
3. No sprint items → roadmap "Now" items → failing queries → permanent tasks.
4. Execute: read → edit → build → test → commit → push. Repeat.

---

## Rules

- **Tests must pass before committing.** Run eval harness after AI changes — revert immediately if scores drop.
- **Commit only files YOU edited this session.** Use `git commit -- <explicit paths>` (the `--` form) to scope the commit to those paths. Never `git commit -a`, never `git commit` with no paths if there might be pre-staged work. If `git diff --cached --name-only` shows files you didn't touch, those belong to another agent or a human — leave them staged, don't sweep them.
- **TestFlight:** hook injects mandatory publish instructions when due — follow them exactly.
- **Daily exec report:** hook injects mandatory instructions when due — follow the template exactly.
- **Every bug close requires a resolution comment** (enforced by hook — will block without it).
- **Every admin report PR comment gets a reply.**
- **Every design doc comment gets a response.**
- **P0 bugs are Priority 1 in the sprint queue.** No session is killed for P0 — current task finishes first.
- **Read full issues before implementing** — body + all comments + screenshots.
- **Post a plan comment before every implementation** (not needed for P0 bugs in emergency).
- **GitHub API:** Reads = 1pt, writes = 5pts. Budget 900pts/min. Batch edits. On 403/429: comment on current task, exit — watchdog restarts with backoff.
- **Output to `/tmp/`.** Run `xcodegen generate` if adding files. New ideas → `gh issue create --label deferred --title "<idea>" --body "<details>"` (the queue lives on GitHub, not in a static doc).

---

## For the human

Start standalone: `cd /Users/ashishsadh/workspace/Drift` → "run autopilot"

Start Drift Control: `echo "RUN" > ~/drift-control.txt && ./scripts/self-improve-watchdog.sh`

Pause/resume via Command Center or: `echo "PAUSE" > ~/drift-control.txt` / `echo "RUN" > ~/drift-control.txt`

Drain (finish current task then stop): `echo "DRAIN" > ~/drift-control.txt`

**Human takeover:**
1. `echo "PAUSE" > ~/drift-control.txt` — watchdog tells current session to stop after its task (~5min)
2. Open Claude normally and work. The session-start hook resets the session type to "human" so auto-publish hooks are suppressed.
3. When done: `echo "RUN" > ~/drift-control.txt` — watchdog resumes autonomous operation.
