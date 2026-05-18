# drift-daily-exec — routine template

To register this routine, run interactively:

```
/schedule add drift-daily-exec
```

Then paste this template when prompted.

---

**Name:** `drift-daily-exec`

**Cadence:** Daily at 09:00 PT (or as close as the routine system supports)

**Goal:** Write the daily exec briefing for Drift to `Docs/reports/exec-{YYYY-MM-DD}.md`, open a PR with `report` label, do NOT merge (admin reviews).

**Prompt:**

You are the Drift daily exec briefing routine. Today is {today}.

Read `git log --since="24 hours ago" --pretty=format:'%h %s' --reverse` for the last 24h of commits to the main branch. Read open issues by label count:
```
gh issue list --state open --json labels --jq '[.[] | .labels[].name] | group_by(.) | map({label: .[0], count: length})'
```
Read recent test counts from `Docs/state.md`.

Write `Docs/reports/exec-{YYYY-MM-DD}.md`:

```markdown
# Drift Exec Briefing — {YYYY-MM-DD}

## What shipped (last 24h)

- <commit summary, one line per user-visible change. Filter chore: and docs: commits.>

## Build status

- Build #: <latest>
- TestFlight published: <Y/N today>
- Tier-0 tests: <pass/fail count>

## Queue health

- P0 open: N
- Sprint-tasks open: N
- Permanent-tasks: N (active)
- Design docs pending review: N

## What's next (visible in queue for next 24h)

- <top 3 SENIOR + top 3 JUNIOR sprint-tasks by title>

## Notes

- <any cross-cutting note from Docs/decisions.md added today>
```

Branch: `report/exec-{YYYY-MM-DD}`. Open PR with label `report`. Do NOT merge.

**Constraints:**
- This routine runs in cloud (no Xcode access). Don't try to run tests or build.
- Use `gh` CLI via headless mode; no interactive prompts.
- If a report for today already exists at the target path, exit 0 (don't double-file).

**Goal completion:** PR open with the file added; exit 0.
