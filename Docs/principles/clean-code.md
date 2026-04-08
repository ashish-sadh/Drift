# Clean Code — Robert C. Martin

## Philosophy

Code is read far more than it is written. Every choice should optimize for the reader — the person maintaining this at 2am, six months from now. Clear beats clever. Simple beats smart. If you need a comment to explain what code does, the code isn't clean enough.

## Principles

1. **Functions do one thing.** If you can extract a meaningful chunk, the function was doing more than one thing. In Swift: a method body should sit at one level of abstraction — either orchestrating calls or doing leaf work, not both.
2. **Names reveal intent.** A reader should never wonder "what does this hold?" Variables, functions, types — all named so the code reads like prose. `remainingCalories` not `rem`. `fetchWeightEntries(for:)` not `getW(p:)`.
3. **Small functions, few arguments.** Under 30-40 lines. Three parameters max. More arguments = the function wants to be a type.
4. **No hidden side effects.** A function named `getX` must not modify state. Computed properties must not trigger network calls or writes.
5. **Guard and return early.** Flatten nested logic. Handle the unhappy path at the top, let the happy path flow unindented.
6. **DRY — but only when the duplication is real.** Three identical blocks = extract. Two similar blocks that might diverge = leave alone.
7. **Boy Scout Rule.** Leave every file a little cleaner than you found it. Not a rewrite — one small improvement per touch.

## When you see X, do Y

- **Function over 40 lines** → Find the chunks that form a coherent thought. Extract as private methods with descriptive names. The original should read like a table of contents.
- **3+ levels of nesting** → Invert conditions with `guard`/early `return`. The deepest logic should be the mainline, not an afterthought.
- **Boolean flag parameter** → Split into two methods. `loadData(forceRefresh: Bool)` → `loadData()` and `refreshData()`. Callers become self-documenting.
- **Dead code (commented out blocks, unused private methods)** → Delete. Git remembers. Dead code misleads readers into thinking it matters.
- **Magic numbers / hardcoded strings** → Named constants or enums. `let maxRetries = 3` not bare `3`. Exception: 0, 1, and obvious math.
- **Misleading name** → Rename. A Bool property should read as a question: `isLoading`, `hasEntries`. A function should read as a verb: `calculateTDEE()`, `formatWeight(_:)`.
- **try? swallowing errors silently** → At minimum, log. Better: let the caller decide how to handle failure. `try?` is acceptable only when the failure truly doesn't matter.
