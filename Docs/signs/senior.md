# Signs — /senior role

Append-only single-sentence corrections. Loaded by `/senior` skill at startup.

When adding a sign: state the rule, then a one-line `Why:` (the incident that motivated it).

## Active signs

- **Do not invoke `/compact`. If budget tight, abandon and let planning re-split next cycle.**
  Why: context discipline — `/compact` causes context anxiety + premature wrap-up. File-based handoff via abandonment is the correct primitive.

- **Never commit to main without a `<verifier_verdict decision="PASS">` in the issue comments.**
  Why: every commit to main is a complete unit of work; TestFlight publishes off main; dirty main = dirty release.

- **Read the `<done_when>` block BEFORE writing the Plan comment.** The Plan must explicitly cover each criterion's verifier path.
  Why: Plan-without-Done-When is the rubber-stamp shape.

- **When tests fail, do not delete the test. Fix the code OR fix the test, never both at once.**
  Why: deleting the failing test masks the regression; "fix both" makes the diff irreviewable.

- **After 2 verifier REJECT/FIX cycles on the same diff, abandon the issue.**
  Why: 3+ rounds = scope mismatch with the Done-When; planning needs to re-split, not the senior to grind.

- **READ files before EDIT.** The harness blocks Edit without prior Read in the same session.
  Why: build failures from edit-without-read (cycle 8000-era hard lesson).

- **Cite real file:line in verdict reasoning.** Hallucinated test names are the rubber-stamp pattern that fails audits.
  Why: cycle 9792 audit caught a 12.5% rubber-stamp rate; the one rubber-stamp cited 5 nonexistent test names.

- **WIP patches from prior crashed sessions live at `~/drift-state/wip/{id}.patch`.** Read the diff BEFORE retry. The stall point is in the diff.
  Why: 5 consecutive analytical-tool crashes; blind retry is guaranteed to fail at the same point.

- **Tier-0 tests must pass after every change.** ~2s warm; no excuse to skip.
  Why: build and test after every change is a project rule, not a suggestion.

- **Run eval before AND after every AI change.** If accuracy drops, revert.
  Why: AI changes can silently regress; eval is the only gate.

- **Engine-without-surface is half-shipped.** Pair the engine PR with the surface task in the same sprint, or flag as not-yet-shipped.
  Why: iCloud backup engine shipped 6 issues across 2 cycles without a user-facing entry.

- **Don't register a tool until engine + tests + eval cases are in the same PR.**
  Why: routing without an engine = silent failure in production.

- **Don't bump `CURRENT_PROJECT_VERSION` when `~/drift-state/testflight-archive-failed` exists.** Silent build-counter lying = 17 dark builds.
  Why: iOS 26.4 SDK archive blocker incident.

## Recently pruned (last curation cycle)

None yet — first cycle.
