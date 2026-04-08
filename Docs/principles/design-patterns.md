# Design Patterns — Head First Design Patterns (GoF)

## Philosophy

Identify what varies and encapsulate it separately from what stays the same. Favor composition over inheritance — build behavior by combining small pieces, not by extending a deep class hierarchy. Program to protocols, not concrete types. Most GoF patterns map naturally to Swift: Strategy is a protocol, Observer is @Observable, Facade is a thin struct wrapping complexity.

## Principles

1. **Encapsulate what varies.** If a piece of logic changes for different cases (food vs exercise vs sleep), pull it behind a protocol. The rest of the code stays stable.
2. **Composition over inheritance.** Swift structs can't inherit. That's a feature. Compose behavior by holding references to collaborators, not by subclassing.
3. **Program to protocols.** Depend on `WeightRepository` (protocol), not `GRDBWeightStore` (concrete). This makes testing trivial and swapping implementations painless.
4. **Single Responsibility.** A type should have one reason to change. A service that handles both HealthKit queries and data formatting has two.
5. **Open/Closed.** Adding a new tool, a new chart type, or a new food source should mean adding a new conformer — not modifying existing code.
6. **Dependency Injection.** Pass collaborators in via init, not `ServiceX.shared` inside the body. Singletons are global mutable state wearing a trench coat.

## When you see X, do Y

- **Switch/if-else chain on a type or enum to pick behavior** → Strategy pattern. Define a protocol for the behavior. Each case becomes a conformer. The switch becomes a single `strategy.execute()` call.
- **God class: one type with 10+ public methods across multiple domains** → Facade + domain types. Extract domain-specific logic into focused types. Keep the original as a thin facade that delegates.
- **`ServiceX.shared` called inside another type** → Inject via init parameter. `init(weightService: WeightService = .shared)` — production code unchanged, tests pass in mocks.
- **Notification spaghetti: 3+ NotificationCenter observers in one type** → Replace with direct protocol-based delegation or @Observable. Notifications are useful for truly decoupled cross-cutting events, not for component-to-component communication.
- **Duplicated algorithm with minor variation** → Template Method or Strategy. Extract the common skeleton, let the variation be a closure or protocol method.
- **Type doing its own construction of complex dependencies** → Factory. Move construction logic to a factory method or a dedicated builder. The type receives ready-made collaborators.

## Patterns especially relevant to SwiftUI apps

- **Strategy** → Service protocols. Different data sources (HealthKit, local DB, mock) behind one protocol.
- **Facade** → Simplify complex subsystems. One `HealthKitFacade` with `fetchWeight()`, `fetchSleep()` hiding the HKQuery boilerplate.
- **Observer** → Already built into SwiftUI via @Observable. Don't reinvent it with NotificationCenter.
- **Repository** → Abstract persistence. Views and ViewModels never see GRDB/CoreData/SQLite directly.
