# Domain-Driven Design — Eric Evans

## Philosophy

Software should model the problem domain, not the database schema or the UI layout. When code speaks the same language as the people who use it, bugs become obvious and features become natural extensions. The biggest wins come from getting the model right — the right names, the right boundaries, the right responsibilities.

## Principles

1. **Ubiquitous language.** Code names must match how the team talks about the domain. If the team says "meal" the code says `Meal`, not `FoodEntryGroup`. If the team says "log weight" the method is `logWeight(_:)`, not `insertWeightRecord(_:)`.
2. **Rich models, not anemic ones.** A model with only stored properties and no methods is a data bag. Domain logic belongs ON the model. `FoodEntry.totalCalories` is good. `CalorieCalculator.calculate(for: entry)` is suspicious.
3. **Domain logic stays in the domain layer.** Views format and display. ViewModels coordinate and hold state. Models and Services own the rules. If a View is doing calorie math or trend calculation, that logic leaked.
4. **Repositories abstract persistence.** The domain layer says `weightRepository.recent(7)`. It never says `db.read { db in try WeightEntry.order(...).limit(7).fetchAll(db) }`. The query lives in the repository.
5. **Bounded contexts.** Each module owns its vocabulary. The "Food" context has FoodEntry, Meal, Recipe. The "Exercise" context has Workout, Exercise, Set. They share data through well-defined interfaces, not by reaching into each other's types.
6. **Validate at the boundary, trust inside.** Parse and validate user input when it enters the system. Once it's a domain type, it's valid by construction. Don't re-validate deep inside services.

## When you see X, do Y

- **Business logic in a View** (calorie math, streak calculation, trend analysis) → Move to the Model (if it's about one entity) or a Service (if it crosses entities). The View calls a computed property or method.
- **ViewModel calling raw database queries** (`db.read`, `db.write`, SQL) → Introduce or use a Repository. The ViewModel calls `repository.fetchRecent()`. The repository owns the query.
- **Anemic model** (struct with 8 properties and zero methods, all logic in a separate service) → Add methods to the model. `weightEntry.bmiAt(height:)` is better than `BMIService.calculate(weight:height:)` when BMI is a property of the weight entry.
- **Names that don't match the domain** (code says `item` but domain says `supplement`, code says `entry` but user says `meal`) → Rename. Alignment prevents miscommunication between code and conversation.
- **Two modules sharing a mutable type** (Food and Exercise both importing and mutating the same HealthData struct) → Each context gets its own type. Map at the boundary.
- **Scattered validation** (same nil-check or range-check in 3 places) → Centralize in the model or a factory. `WeightEntry(kg:)` should reject negatives at construction, so callers never wonder.
