# SwiftUI Best Practices — WWDC, "Thinking in SwiftUI" (Eidhof & Smith)

## Philosophy

A SwiftUI View is a lightweight, disposable description of UI — not an object that manages its own lifecycle. State is the single source of truth; the view is a pure function of that state. Build UIs by composing many small views, not by writing few large ones. Trust the framework: SwiftUI handles diffing, animation, layout. Fight it and you lose.

## Principles

1. **Views are cheap. Make many small ones.** A 300-line view is doing too much. Extract logical sections into private structs. The parent becomes a composition of named parts — readable at a glance.
2. **State ownership is everything.** `@State` = this view owns it, it's private. `@Binding` = a parent owns it, child can read/write. `@Observable` class = shared state, injected via environment or init. Wrong ownership = stale UI, double renders, impossible debugging.
3. **`body` is a pure function.** No side effects in `body`. No network calls, no database writes, no print statements. If you need async work, use `.task {}`. If you need to react to changes, use `.onChange(of:)`.
4. **`.task {}` over `.onAppear` for async.** `.task` ties the work's lifetime to the view — it cancels automatically on disappear. `.onAppear { Task { ... } }` leaks fire-and-forget tasks.
5. **Lazy containers for dynamic content.** `ScrollView { LazyVStack { ... } }` for any list that could grow. Eager `VStack` loads everything upfront — fine for 5 items, disaster for 500.
6. **Extract `@ViewBuilder` methods for conditional blocks.** Deep `if/else` or `switch` in `body` makes the view tree unreadable. Pull branches into named methods: `@ViewBuilder private func emptyState() -> some View`.
7. **Previews with realistic data.** Previews that show "Lorem ipsum" or empty state don't catch real layout issues. Use mock data that resembles production: long names, edge-case numbers, multiple items.

## When you see X, do Y

- **View file over 300 lines** → Identify 2-3 logical sections (header, list, detail, input area). Extract each as a `private struct` that takes `@Binding` or the @Observable model. Parent view reads like a storyboard.
- **@State explosion (10+ @State vars in one view)** → Group related state into an @Observable ViewModel or a plain struct. `@State private var form = MealForm()` replaces 6 scattered @State vars. The view gets simpler, the state gets testable.
- **`.onAppear { Task { await ... } }`** → Replace with `.task { await ... }`. One line, automatic cancellation, no memory leaks.
- **Complex inline expressions in `body`** → Extract as computed properties. `private var calorieColor: Color { remaining > 0 ? .green : .red }` is clearer than inlining the ternary.
- **`if condition { ViewA() } else { ViewB() }`** spanning 30+ lines → Extract into `@ViewBuilder private func contentView() -> some View`. The `body` stays flat.
- **Direct database/service call inside a View** → Move to ViewModel. Views describe UI; ViewModels fetch and transform data. `view.task { await viewModel.load() }` not `view.task { entries = try await db.read { ... } }`.
- **Force unwrap (`!`) in a View** → Use `if let`, `guard let`, or provide a default. Views should never crash from unexpected nil.
- **Hardcoded sizes** (`frame(width: 375)`) → Use relative sizing (`.frame(maxWidth: .infinity)`, `GeometryReader`, `padding`). Hardcoded sizes break on different devices.
