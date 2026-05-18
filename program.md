# Drift Autopilot

Single pointer doc. The Drift autopilot is implemented as Claude Code skills under `.claude/skills/`; the watchdog (`scripts/self-improve-watchdog.sh`) spawns headless `claude -p "/<skill>"` sessions per phase. Each skill owns its phase rules and reads its `Docs/signs/<role>.md` for accumulated guardrails.

Tenets, operational rules, performance budgets, and "what we do NOT do" live in `Docs/tenets.md` — read that, not this file, for product/engineering ground truth.

## Three operating modes

| Mode | Trigger | What runs | Where the logic lives |
|---|---|---|---|
| Drift Control | `echo RUN > ~/drift-control.txt && ./scripts/self-improve-watchdog.sh` | watchdog supervises planning + senior + junior + TestFlight cron | `.claude/skills/{planning,senior,junior,knowledge-curate,design-doc,testflight-publish}/SKILL.md` |
| Autopilot (standalone) | Human types "run autopilot" in a session | This session loops forever, picking the next task | Pointers below + same skills |
| Human-shepherded | Default | Human drives one feature/bug at a time | `scripts/sprint-service.sh status` for the queue |

## Standalone "run autopilot" (no watchdog)

For when the human wants a foreground loop in one session, no model switching, no respawn:

1. **Pick the next task.**
   ```bash
   TASK=$(scripts/sprint-service.sh next --senior --claim)   # or --junior
   echo "$TASK"
   ```
   - `"none"` → exit cleanly; do not backfill from your own ideas.
   - Otherwise extract the issue number from the first word.

2. **Read the issue + post a Plan comment** (within 5 min of claim — `nudge-plan-comment.sh` will nudge until it appears).
   Use the `<plan>` XML shape from `.claude/skills/senior/SKILL.md` step 7.

3. **Implement → build → test → commit.** Commit message format: `feat(#N): …` / `fix(#N): …` / `chore(#N): …`. Tier-0 tests must pass; hooks block the commit otherwise.

4. **Verifier debate** (sprint tasks that touch code): `Agent({subagent_type: "debate-moderator", participants: [qa-tester, principal-engineer], …})`. Post the returned `<verifier_verdict>` as an issue comment. `require-qa-verdict.sh` blocks the commit without a `Decision: PASS`.

5. **Mark done.**
   ```bash
   scripts/sprint-service.sh done $N $(git rev-parse HEAD)
   # OR for the 6 permanent-tasks (#782, #193, #53, #52, #51, #50, #49):
   scripts/sprint-service.sh session-done $N
   ```

6. **Loop to step 1.**

P0 bugs sit at the queue head — the router enforces it. No session is killed mid-task for a P0; current task finishes first.

## For the human

| Action | Command |
|---|---|
| Start Drift Control | `echo "RUN" > ~/drift-control.txt && ./scripts/self-improve-watchdog.sh` |
| Pause autopilot (finish current task, then stop claiming) | `echo "PAUSE" > ~/drift-control.txt` |
| Drain (finish all in-progress, then stop) | `echo "DRAIN" > ~/drift-control.txt` |
| Resume | `echo "RUN" > ~/drift-control.txt` |
| Flip to skills harness (default ON) | `echo 1 > ~/drift-state/use-skills.flag` |
| Roll back to legacy SESSION_PROMPT | `rm -f ~/drift-state/use-skills.flag` |
| Live queue snapshot | `scripts/sprint-service.sh status` |
| Top senior item | `scripts/sprint-service.sh next --senior` |
| Top junior item | `scripts/sprint-service.sh next --junior` |

**Takeover protocol** (when the human wants to work in the same repo):

1. `echo "PAUSE" > ~/drift-control.txt` — watchdog tells the current session to stop at its next claim attempt (~5 min worst case).
2. Wait until `command-center/heartbeat.json` shows the session has exited, OR until you confirm no `claude` process is mid-edit.
3. Open Claude Code normally. `session-start.sh` will mark the session as `human`, suppressing TestFlight injection and auto-publish hooks.
4. When done: `echo "RUN" > ~/drift-control.txt`. Watchdog resumes within ~60s.

## Pointers

- **Tenets, operational rules, performance budgets:** `Docs/tenets.md`
- **Per-role accumulated guardrails (append-only):** `Docs/signs/{planning,senior,junior}.md`
- **Persona files (Product Designer + Principal Engineer):** `Docs/personas/`
- **Roadmap (re-read every planning cycle):** `Docs/roadmap.md`
- **Decisions log (non-obvious calls):** `Docs/decisions.md`
- **Reports (exec + product reviews):** `Docs/reports/`
- **Skill bodies (canonical phase rules):** `.claude/skills/<role>/SKILL.md`
- **Subagents (verifier participants + persona research):** `.claude/agents/{qa-tester,principal-engineer,product-designer,debate-moderator}.md`
- **Drift Control design (state machine, watchdog supervisor):** `Docs/drift-control-design.md`
- **Harness rewrite plan (this Epic, #812):** `Docs/refactor/harness-rewrite-2026-05-18.md`
