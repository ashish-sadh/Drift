# drift-product-review — routine template

To register, run interactively:

```
/schedule add drift-product-review
```

Then paste this template.

---

**Name:** `drift-product-review`

**Cadence:** Weekly on Sunday at 10:00 PT, OR every 20 cycles (whichever comes first).

**Goal:** Write `Docs/reports/review-cycle-{N}.md` for the current cycle, debate with engineer + designer + qa-tester subagents (via /ultrareview if available), file every finding as a sprint-task with `<done_when>` block, open PR with `report` label.

**Prompt:**

You are the Drift product review routine. Current cycle: {cycle_n}.

Read:
- `Docs/roadmap.md` (Now/Later tiers)
- `Docs/decisions.md` (last 20 entries)
- `Docs/tenets.md`
- Recent exec briefings: `ls -t Docs/reports/exec-*.md | head -7`
- Recent commits to main: `git log --since="14 days ago" --pretty=format:'%h %s' --reverse | head -50`
- Open queue: `gh issue list --state open --label sprint-task --json number,title,labels,createdAt`

Invoke /ultrareview if available; otherwise spawn the three subagents in parallel via the Agent tool:
- `principal-engineer`: architecture/code-quality concerns over the 14-day diff
- `product-designer`: activation, friction, competitive positioning
- `qa-tester`: regression risk surface

Each returns a structured judgment. Synthesize into `Docs/reports/review-cycle-{N}.md`:

```markdown
# Drift Product Review — Cycle {N} ({YYYY-MM-DD})

## Headline (1 sentence what this cycle was about)

## What shipped (user-visible, last 14 days)

## What slipped (deferred 3+ cycles)

## Surface review (per-domain)

### AI Chat
### Food logging
### Workouts
### Biomarkers / Weight
### Activation / Feedback

## Findings (file each as sprint-task)

- [ ] **Finding 1**: <one-sentence summary>. Source: review-cycle-{N}. (engineer/designer/qa-tester)
- [ ] **Finding 2**: ...

## Tenets check

- Tenet 1 (AI chat showstopper): <evidence we're holding the line>
- Tenet 12 (TestFlight reach): <evidence>
- ...

## Recommendations for next cycle

1. <one-sentence rec>
2. ...
```

For each finding, file a sprint-task issue with a `<done_when>` block. Add `Source: review-cycle-{N}` to body.

Branch: `review/cycle-{N}`. Open PR with label `report,review`. Do NOT merge.

**Constraints:**
- Cloud routine — no Xcode, no local file mutations beyond the report file.
- If a review for cycle {N} already exists, exit 0.

**Goal completion:** PR open + all findings filed as sprint-tasks; exit 0.
