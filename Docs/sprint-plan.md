# Sprint Plan — Review #38 (Cycles 1550–1570)

Created: 2026-04-13

---

## Task 1: Fix recovery score mismatch (#41)
**Priority:** P0
**Classification:** JUNIOR (Sonnet + advisor)
**Status:** [ ] pending

**Goal:** Dashboard shows recovery 77 but Body Rhythm page shows 58. Trace both data paths, find divergence, make consistent.

**Files:**
- Dashboard recovery display
- Body Rhythm / Sleep & Recovery page

**Approach:**
1. Read both views to find where recovery score is computed/fetched
2. Identify if one uses a different HealthKit query, time window, or calculation
3. Unify to single source of truth
4. Add regression test

**Acceptance:** Dashboard and detail page show same recovery score for same data.

---

## Task 2: Fix progressive overload space (#42)
**Priority:** P0
**Classification:** JUNIOR (Sonnet + advisor)
**Status:** [ ] pending

**Goal:** Progressive overload list shows all 14+ exercises, overwhelming the screen. Cap to top 5 with "Show more" expand.

**Files:**
- Exercise tab view (progressive overload section)

**Approach:**
1. Read current progressive overload rendering
2. Sort by staleness (longest plateau first)
3. Show top 5 by default with "Show all N exercises" expand button
4. Collapsed state persists across visits

**Acceptance:** Progressive overload shows max 5 items by default. Expand reveals all. Less visual noise.

---

## Task 3: State.md refresh
**Priority:** P1
**Classification:** JUNIOR (Sonnet + advisor)
**Status:** [ ] pending

**Goal:** State.md is stale — build 108 (actual: 113), tests 981 (actual: 1,037+), foods 1,500 (actual: 1,520).

**Files:**
- `Docs/state.md`

**Approach:**
1. Update all numbers: tests, build, foods, exercises, tools, card types
2. Update AI chat capabilities list
3. Update tech stack notes if changed

**Acceptance:** State.md accurately reflects current build.

---

## Task 4: Systematic bug hunt
**Priority:** P1
**Classification:** JUNIOR (Sonnet + advisor)
**Status:** [ ] pending

**Goal:** Quarterly practice. Focus on notification scheduling, food diary edge cases, recent AI changes.

**Approach:**
1. Review NotificationService for edge cases (permission revoked mid-session, toggle race)
2. Review food diary copy/reorder for timestamp edge cases
3. Trace data paths through recent features
4. Add regression tests for anything found

**Acceptance:** Analysis complete, any bugs found are fixed with regression tests.

---

## Task 5: Progressive overload UI polish
**Priority:** P2
**Classification:** JUNIOR (Sonnet + advisor)
**Status:** [ ] pending

**Goal:** After fixing the space issue, improve coaching feel of progressive overload suggestions.

**Approach:**
1. Add exercise name highlighting or bold styling
2. Make weight suggestions more prominent
3. Consider grouping by body part or priority

**Acceptance:** Progressive overload section feels like curated coaching, not a warning list.
