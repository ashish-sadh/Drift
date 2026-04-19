# Drift Control — Sprint System Design

> Source of truth for how the autonomous sprint system works.  
> Derived from alignment session: 2026-04-18.  
> Update this doc when any behavior changes — do not let it drift from the code.

---

## Actors

| Actor | Model | Role |
|-------|-------|------|
| **Watchdog** | (shell) | Orchestrates sessions, detects stalls, routes work |
| **Planning session** | Opus | Sprint planning, FR triage, report generation, impl task creation |
| **Senior session** | Opus | SENIOR sprint tasks, P1/P2 bugs, design doc writing |
| **Junior session** | Sonnet | Regular sprint tasks, P1/P2 bugs, permanent task loops |
| **Human/Admin** | — | Approves non-admin issues, reviews design docs, controls start/stop/pause |

---

## Session Routing (Watchdog)

Priority order for deciding which session to start next:

1. **Planning overdue** (6+ hours since last planning) → planning session
2. **Planning crash recovery** — open planning issue found → resume planning
3. **SENIOR work exists** (P0 bugs, SENIOR sprint tasks, P1/P2 bugs without sprint-task) → senior session
4. **Otherwise** → junior session (runs continuously)

**Junior runs continuously** until planning is overdue. No alternating with senior. Senior is only spun up when SENIOR-class work exists; when it finishes, watchdog routes back to junior.

---

## Priority Queues

### Senior (`sprint-service next --senior`)

| Priority | Work |
|----------|------|
| 1 | Admin P0 bugs (any with `bug` + `P0` + `sprint-task`) |
| 2 | SENIOR sprint tasks (`sprint-task` + `SENIOR` label) |
| 3 | Admin P1/P2 bugs (`bug` + `P1`/`P2` + `sprint-task`) |
| 4 | SENIOR permanent tasks (`permanent-task` + `SENIOR`) — **once per sprint** |

### Junior (`sprint-service next --junior`)

| Priority | Work |
|----------|------|
| 1 | Admin P0 bugs (any with `bug` + `P0` + `sprint-task`) |
| 2 | Regular sprint tasks (`sprint-task`, no `SENIOR`) |
| 3 | Admin P1/P2 bugs (`bug` + `P1`/`P2` + `sprint-task`) |
| 4 | Permanent tasks (`permanent-task`, no `SENIOR`) — **loops indefinitely** |

**Key difference**: Junior loops on permanent tasks indefinitely (updating progress each cycle). Senior works each permanent task **once per sprint**, then it's locked until next planning cycle resets it.

---

## Bug Lifecycle

### Admin-filed bug (any priority P0/P1/P2)

```
Filed (admin via Command Center)
  → auto-labeled: bug + priority + sprint-task
  → enters sprint queue at correct priority tier
  → session claims it
  → posts plan as comment on issue
  → implements fix
  → commits to main
  → closes issue with comment summarizing fix
```

**No approval needed.** Admin filing = approval. Any session (senior or junior) can handle it.

### Non-admin-filed bug (any priority P0/P1/P2)

```
Filed (anyone via GitHub)
  → session picks it up during heartbeat scan
  → posts plan as comment on issue
  → adds needs-review label
  → moves on to next task (does NOT implement)
  → human reviews plan, clicks "Approve → Sprint" in Command Center
  → sprint-task label added, needs-review removed
  → enters sprint queue at correct priority tier
  → session claims, posts plan (again if needed), implements, closes
```

**All priorities including P0 require admin approval if non-admin filed.** P0 does NOT override the approval gate.

### P0 behavior

P0 is **first in queue**, not an interrupt. The current session finishes its task, then P0 is the next thing returned by `sprint-service next`. No session is killed for P0. Planning is never interrupted for P0.

---

## Feature Request Lifecycle

### Admin-filed feature request

Admin has two options in Command Center at filing time:
- **"Add to Sprint now"** — adds `sprint-task` immediately, enters queue
- **"Send to Planning"** — planning session triages it next cycle

### Non-admin feature request

```
Filed → sits untriaged
  → planning session picks it up next cycle
  → planning posts plan/recommendation as comment
  → planning adds needs-review label
  → human reviews, approves via Command Center (adds sprint-task)
  → enters sprint queue
```

Untriaged FRs (no `sprint-task` AND no `deferred` label) block planning exit — planning must triage all of them.

---

## Design Doc Lifecycle

```
Senior writes design doc
  → opens PR with design-doc label
  → adds doc-ready label to issue
  → any session reviews PR, leaves comments
  → human can also leave comments
  → human adds approved label (FINAL APPROVAL — always human)
  → planning session (next cycle) creates implementation tasks as GitHub issues + sprint-task labels
  → sprint-service refresh picks them up
  → sessions implement them as regular sprint tasks
```

**Ownership rules:**
- Writing design doc: **senior only**
- Reviewing design doc PR: **any session** (reads full doc + context first)
- Replying to PR comments: **any session** (reads full doc + context first)
- Approving: **human only**
- Creating impl tasks: **planning session**

---

## Planning Session Responsibilities

Runs every 6+ hours (watchdog triggers when overdue). Every planning cycle:

1. Open the planning issue (creates one if none exists)
2. Check `blocked` issues — discuss with PE/product personas, update acceptance criteria, remove `blocked` label
3. Drain process feedback log (`issue-service drain-feedback`) — file `infra-improvement` issues for systemic problems
4. Triage untriaged feature requests — post plan comment, add `needs-review` or `sprint-task`
5. Triage untriaged non-admin bugs — post plan comment, add `needs-review`
6. Check approved design docs — create implementation tasks as sprint issues
7. Check product focus / roadmap — set direction for sprint
8. Generate daily exec report (if 24h+ since last report) — posts as GitHub PR
9. Product review (every cycle) — reflect on last sprint, set direction for next
10. Reset senior permanent task "done-this-sprint" flags
11. Close planning issue

---

## Permanent Tasks

- `permanent-task` label — never closed on GitHub
- **Junior**: picks up after all sprint tasks done, loops indefinitely updating progress, no per-sprint budget
- **Senior**: picks up after SENIOR sprint tasks done, works each task **once per sprint**, locked until planning resets
- **SENIOR permanent tasks**: `permanent-task` + `SENIOR` → senior only
- **Regular permanent tasks**: `permanent-task` (no SENIOR) → junior (and senior if no other work)
- `session-done <N>`: marks done locally without GitHub close — used by both senior (per-sprint budget) and when discovering stale closed issues

---

## Stale State Handling

State refresh runs every ~1 minute. Despite this, a session may discover a mismatch between local state and GitHub (e.g. issue already closed but state says open).

**When session discovers GitHub issue is already closed:**
1. Call `sprint-service session-done <N>` — fixes local cache
2. Log "stale state corrected for #N — moving on"
3. Pick next task

This prevents the deadlock where `sprint-service next` keeps returning a closed issue.

---

## Stall Detection & Recovery

| Session type | Stall threshold | Nudge wait | Action |
|-------------|----------------|-----------|--------|
| Planning | 1 hour | 5 min | Kill + resume via open planning issue |
| Senior | 30 min | 5 min | Kill + unclaim task + start fresh |
| Junior | 30 min | 5 min | Kill + unclaim task + start fresh |

**Nudge before kill**: Watchdog sends a message to the running session ("are you alive? what are you doing?"), waits 5 minutes. If no progress (no new commits, no log output), kills and restarts.

**After kill**: `cleanup_dirty_state` runs — discards uncommitted changes, unclaims in-progress task. Next session picks up the task from the beginning.

---

## Pause / Resume

**Pause** (`echo "PAUSE" > ~/drift-control.txt`):
- Watchdog stops launching new sessions
- Current session finishes its current task, then exits cleanly

**Resume** (human sets control back to RUN):
- Watchdog presents a summary of the current queue (next session type, pending tasks)
- Human confirms (via CLI/session, not Command Center)
- Watchdog starts the next session

---

## Crash Recovery

**Session crash mid-task:**
- Watchdog detects (process gone or no output)
- Runs `cleanup_dirty_state` — discards changes, unclaims task
- Next session picks up the task from the beginning

**Planning crash:**
- Open planning issue remains on GitHub
- Watchdog detects open planning issue → routes next session to resume planning
- Resuming session continues from the open issue, works through remaining checklist

---

## Heartbeat (Watchdog Loop)

Every ~1 minute:
1. `sprint-service refresh` — sync GitHub → local state
2. Check for unanswered comments on open issues → any session can reply
3. Check session health (still running? log updated recently?)
4. If stall threshold exceeded → send nudge → wait 5min → kill if needed
5. If session exited → route next session per routing rules

Compliance cache (P0 bug list, product focus) also refreshed every minute.

---

## Commit & Close Rules

- All commits go directly to `main` (no PRs from sessions)
- Issue close: always `gh issue close <N> --comment "<summary>"` — comment required
- Before risky operations (delete, major refactor): session posts a comment explaining what it's about to do, then proceeds
- Tests run after every commit — session fixes regressions before moving on
- TestFlight: auto-published every 3h if new commits exist

---

## Blocked Tasks

When a session cannot complete an acceptance criterion:
1. Posts a comment on the issue explaining what's blocked and why
2. Adds `blocked` label
3. Moves on to the next task

Planning session (next cycle) picks up all `blocked` issues, discusses with PE/product personas, clarifies acceptance criteria, removes `blocked` label, and reintroduces to sprint.

---

## Issue Comment Scanning

Any session (junior or senior) scans for unanswered human comments on open issues during its heartbeat. It reads the full issue context before replying. This applies to:
- Open issues (active tasks)
- Closed issues (follow-up questions after fix)

Not tied to task ownership — any free session handles comments.

---

## Process Improvements

When a session discovers a broken script, unclear instruction, or process problem:
- Files a `infra-improvement` sprint issue
- Planning session triages it next cycle

Sessions do NOT modify `program.md` — human only.

---

## State Files

| File | Purpose |
|------|---------|
| `~/drift-state/sprint-state.json` | Task queue, in-progress tracking, per-sprint done flags |
| `~/drift-state/planning-issue` | Number of the open planning issue (crash recovery) |
| `~/drift-state/last-planning-time` | Timestamp of last planning session start |
| `~/drift-state/last-report-time` | Timestamp of last daily report |
| `~/drift-state/cache-p0-bugs` | Live P0 bug list (refreshed every ~1min) |
| `~/drift-state/cache-product-focus` | Current product focus from roadmap |
| `~/drift-state/process-feedback.log` | Session hiccup log (drained by planning) |
| `~/drift-state/model-config` | Per-session-type model overrides |
| `~/drift-control.txt` | RUN / PAUSE / STOP / DRAIN |
