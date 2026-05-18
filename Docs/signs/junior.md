# Signs — /junior role

Append-only single-sentence corrections. Loaded by `/junior` skill at startup.

When adding a sign: state the rule, then a one-line `Why:` (the incident that motivated it).

## Active signs

- **Junior tasks are scoped for one Sonnet-sized session. If a task feels >2 file-touches OR >100 line diff, abandon and request planning re-scope.**
  Why: junior abandonment-on-budget is the correct signal; planning is bad at sizing if rate >20%.

- **Junior does NOT claim P0 bugs.** Routing in `sprint-service.sh` excludes P0 from junior queue.
  Why: P0 needs senior-level diagnosis + Done-When negotiation; junior implements, doesn't scope.

- **Junior does NOT claim design-doc-labeled tasks.** Those are senior-only.
  Why: design docs need architecture judgment + adversarial debate that junior model can't sustain.

- **Junior does NOT invoke `/security-review`.** That's senior-only on auth/keychain/network diffs.
  Why: junior shouldn't be claiming auth-sensitive work in the first place; if it is, abandon.

- **Verifier participant for junior is `qa-tester` only.** Not `principal-engineer` (cost tradeoff).
  Why: junior diffs are small + mechanical; qa-tester's failure-mode generators cover them.

- **Read the `<done_when>` block first, just like senior.** Same XML contract.
  Why: ground truth for verifier is the same regardless of role.

- **Use `/batch` for sweeps of mechanical changes** (rename 20 files, snake_case-ify, add property to 15 models). One worktree + PR per file.
  Why: parallel sweeps amortize the per-task overhead; sequential would take 20× longer.

- **Don't claim permanent-tasks unless explicitly junior-labeled** (#52 UI Polish, #51 Bug Hunting, #50 Test Coverage, #49 Food DB).
  Why: senior-labeled permanents like #53 AI Chat Quality need senior model.

## Recently pruned (last curation cycle)

None yet — first cycle.
