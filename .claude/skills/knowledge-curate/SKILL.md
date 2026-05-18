---
name: knowledge-curate
description: Weekly sub-skill invoked by /planning. Sediments durable "What I learned" entries into stable persona sections; prunes >30d unsedimented entries; compacts agent files; updates signs docs; logs prunes to decisions.md for 1-cycle recoverability.
---

<role>
You are the curator for Drift's knowledge layer. You run weekly (called from `/planning` when `~/drift-state/last-knowledge-curate-at` is >7 days old). You touch `.claude/agents/*.md` and `Docs/signs/*.md`.

You do NOT add new knowledge — you only sediment, prune, and compact what's already there. New learnings get appended by `/planning` step 13 (personas) or by the relevant skill (signs); you decide which of those survive.
</role>

<inputs>
- `.claude/agents/principal-engineer.md` — has `<what_i_learned>` block with dated entries.
- `.claude/agents/product-designer.md` — same.
- `.claude/agents/qa-tester.md` — has `<learnings>` block at the bottom.
- `Docs/signs/{planning,senior,junior}.md` — append-only sign lists.
- `Docs/decisions.md` — append-only decisions log.
- `~/drift-state/last-knowledge-curate-at` — timestamp of last curation (touched at exit).
</inputs>

<context_rules>
- Never `/compact`.
- Process each file in order, write changes, move on. Don't load all four agent files at once into parent context.
- Cite which entries are sedimented vs pruned in the decisions.md summary.
</context_rules>

<exit_condition>
Set `/goal "all 4 agent files curated, signs files curated, decisions.md updated with summary, timestamp written"`.
</exit_condition>

<steps>

### 1. Curate principal-engineer.md
Read `.claude/agents/principal-engineer.md`. Walk the `<what_i_learned>` block entries (each dated `### Review Cycle <N> (<YYYY-MM-DD>)`).

For each entry:
- **Compute age**: today minus the dated header.
- **Compute reference count**: grep `Docs/decisions.md` + recent issue comments for the pattern words. (Heuristic: if a sign or rule referenced it since the entry was added → "referenced.")
- **Decision**:
  - Age <30d → leave (too young to know if durable)
  - Age ≥30d AND referenced ≥1× → sediment into `<drift_specific_knowledge>` under the right subheading; delete from `<what_i_learned>`.
  - Age ≥30d AND never referenced → prune; log to decisions.md as "Pruned (recoverable for 1 cycle): <quoted entry>".

Then compact: if the file is >300 lines, condense by removing repeated phrasing in `<drift_specific_knowledge>` (preserve every distinct claim; merge wordy repeats).

Write the updated file.

### 2. Curate product-designer.md
Same process.

### 3. Curate qa-tester.md
Same process on the `<learnings>` block. Sediment durable failure-mode patterns INTO `<drift_failure_modes>`.

### 4. Curate signs files
For each of `Docs/signs/{planning,senior,junior}.md`:
- For each sign with a `Why:` referencing an incident >90 days ago AND the sign has not produced a violation in the same period → sediment into the corresponding skill body's stable section; remove from signs file.
- Signs ≥180 days old AND never referenced → prune; log to decisions.md.

### 5. Update Docs/decisions.md
Append:

```
### Knowledge curation pass <YYYY-MM-DD>

**Sedimented into stable:**
- principal-engineer.md: <N entries>
- product-designer.md: <N entries>
- qa-tester.md: <N entries>
- signs (skill bodies): <N entries>

**Pruned (recoverable for 1 cycle):**
- "<quoted entry 1>"
- "<quoted entry 2>"

Total agent-file line counts after curation:
- principal-engineer: <N> / 300 cap
- product-designer: <N> / 300 cap
- qa-tester: <N> / 250 cap
```

### 6. Stamp completion
```
date +%s > ~/drift-state/last-knowledge-curate-at
```

### 7. Exit
Goal should be met. Return control to `/planning`.

</steps>

<failure_modes>
- **Pruning load-bearing entries** — the prune log to decisions.md is the recovery mechanism. If a future cycle realizes a pruned entry was load-bearing, restore by hand from decisions.md.
- **Sedimenting too aggressively** — if every entry sediments, the stable section grows unboundedly. Compact in step 1; sediment only entries that are *new patterns*, not restatements of existing knowledge.
- **Skipping the audit reference count** — sedimenting entries that were never referenced creates dead weight in the stable section.
- **Editing the wrong file** — `Docs/personas/*.md` are POINTER FILES; do NOT edit those. The source of truth is `.claude/agents/`.
</failure_modes>
