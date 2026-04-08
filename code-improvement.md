# Drift Code-Improvement Loop

Autonomous loop for code quality. Follow this exactly.

## Steering notes

**Re-read before every cycle.** Human may change at any time.

_Directive:_ **Improve code quality, readability, and maintainability. Apply clean code principles, design patterns, and SwiftUI best practices. Focus on the biggest wins first — large files, duplicated logic, tangled views. Every change must compile and pass all tests.**

_Override:_ CONTINUE

---

## Starting up

**Fresh start:**
1. Read `CLAUDE.md`
2. Read this file's steering notes
3. Read `Docs/code-improvement-log.md` — see what's already done
4. Build: `xcodebuild build -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' > /tmp/drift-build.log 2>&1 && echo "OK" || echo "FAIL"`
5. Scan for targets: `wc -l Drift/**/*.swift Drift/*.swift 2>/dev/null | sort -rn | head -20`
6. Start the loop

**Recovery (interrupted mid-cycle):**
- `git status && git log --oneline -5`
- Uncommitted changes? Finish or `git checkout -- .`
- Resume the loop

---

## What to improve (priority order)

### 1. Giant Views — Extract & Decompose
Files over 400 lines are the #1 target. SwiftUI views should be small, composable, single-responsibility.

**Pattern:** Extract subviews, sections, and row types into separate files or extensions.
- WorkoutView.swift (2067 lines) — break into WorkoutListView, ExerciseRowView, WorkoutDetailView, etc.
- AIChatView.swift (964 lines) — extract ChatBubbleView, ChatInputBar, message handling into ViewModel
- FoodSearchView.swift (805 lines) — extract FoodResultRow, SearchFilterView, etc.
- FoodTabView.swift (698 lines) — extract MealSectionView, NutritionSummaryView, etc.
- DashboardView.swift (649 lines) — extract DashboardCard, MetricRow, etc.
- CycleView.swift (633 lines) — decompose into sections

**Rules:**
- Each extracted view goes in the same Views/ subfolder
- Keep the parent view as the coordinator — it owns state, children receive bindings
- Use `private struct` for tiny helpers that won't be reused

### 2. Fat Services — Single Responsibility
Services over 500 lines are doing too much.

**Pattern:** Split by responsibility. One service = one domain concept.
- HealthKitService.swift (1011 lines) — split into HealthKitWeight, HealthKitSleep, HealthKitExercise, etc. Keep a thin facade.
- StaticOverrides.swift (714 lines) — group overrides by domain (food, exercise, sleep, weight) into separate files or extensions
- AIContextBuilder.swift (683 lines) — extract context builders per domain

**Rules:**
- Use extensions to split by domain: `extension HealthKitService { // MARK: - Sleep }`
- Or extract into separate types if logic is truly independent
- Maintain the same public API — callers should not change

### 3. Repeated Patterns — DRY
Look for duplicated code across views and services.

**Common smells:**
- Same HealthKit query boilerplate in multiple places
- Repeated date formatting / range calculation
- Similar list+detail view patterns across tabs
- Duplicated styling (fonts, colors, spacing)
- Copy-pasted error handling

**Pattern:** Extract shared logic into:
- Reusable view components (e.g., `MetricCard`, `SectionHeader`, `EmptyStateView`)
- Utility extensions (e.g., `Date+Ranges`, `Color+Theme`)
- Protocol-based abstractions only when 3+ conformers exist

### 4. SwiftUI Best Practices
- `@State` / `@Binding` / `@ObservedObject` used correctly (not `@State` for reference types)
- Computed properties over inline expressions in `body`
- `ViewBuilder` methods for conditional content instead of deep ternary nesting
- Prefer `.task {}` over `.onAppear` for async work
- Use `LazyVStack` / `LazyHStack` for long lists
- Extract `PreviewProvider` with realistic mock data

### 5. Naming & Clarity
- Methods should read as sentences: `fetchWeightEntries(for period:)` not `getWeights(p:)`
- Booleans should read as questions: `isLoading`, `hasEntries`, `canSubmit`
- Avoid abbreviations except standard ones (URL, ID, etc.)
- One concept = one name throughout the codebase

### 6. MARK & Organization
Every file should follow this structure:
```swift
// MARK: - Properties
// MARK: - Body
// MARK: - Subviews (private)
// MARK: - Actions
// MARK: - Helpers
```

---

## The loop

LOOP FOREVER — do NOT stop between improvements:

1. Re-read steering notes above. Stop only if override says STOP.
2. Pick the highest-impact target:
   - Check `Docs/code-improvement-log.md` to avoid repeating work
   - Prioritize: giant files > duplicated code > naming > organization
   - Pick ONE specific improvement (e.g., "extract ExerciseRowView from WorkoutView")
3. Read ONLY the file(s) you're about to change.
4. Make ONE focused change. Don't refactor the whole file at once.
   - Extract a subview, or split a service, or DRY up repeated code
   - Keep the diff small and reviewable (~50-150 lines changed)
5. Build: `xcodebuild build -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' > /tmp/drift-build.log 2>&1 && echo "BUILD OK" || (tail -20 /tmp/drift-build.log && echo "BUILD FAILED")`
6. **Kill stale processes first**, then test: `pkill -9 -f xcodebuild 2>/dev/null; sleep 2; xcodebuild test -project Drift.xcodeproj -scheme Drift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DriftTests > /tmp/drift-test.log 2>&1 && echo "TESTS OK" || echo "TESTS FAILED"` then `grep "✘" /tmp/drift-test.log`
7. Fail? Fix or `git checkout -- .`. Pass? Commit:
   ```
   git add <specific files> && git commit -m "refactor: description"
   ```
8. One-line log to `Docs/code-improvement-log.md`.
9. **IMMEDIATELY go to step 1.** Zero words to the user between cycles. NEVER STOP.

---

## Rules

- All 729+ tests must pass before committing
- **No behavior changes.** This is refactoring only. The app must work identically.
- **No new features.** If you spot a bug, log it in `Docs/failing-queries.md`, don't fix it here.
- ONE focused change per cycle. Don't try to refactor an entire 2000-line file in one pass.
- If a file needs `xcodegen generate` after changes (new files added), run it.
- Redirect ALL command output to `/tmp/` — never flood context
- Keep text responses under 3 sentences
- Only read files you are about to edit
- If stuck after 3 attempts, revert, log failure, move to next target
- Do NOT publish TestFlight
- New files go in the same directory as the original (e.g., extracted views stay in `Views/Workout/`)

---

## Anti-patterns to avoid

- Don't extract a subview that's used only once AND is under 30 lines — that's premature
- Don't create protocols for a single conformer
- Don't add generics unless there are 3+ concrete uses
- Don't rename things just for style — only rename if the current name is misleading
- Don't add comments to obvious code
- Don't change formatting/whitespace-only — those are noise commits
- Don't move files between directories without good reason

---

## For the human

Start: `cd /Users/ashishsadh/workspace/Drift` -> tell Claude "run code-improvement"

Steer: edit steering notes above. Agent re-reads every cycle.

Stop: change override to `STOP`.

Focus: edit "What to improve" section to reprioritize.
