# DriftCore — Definition of Done

The contract. Don't stop until every box is checked.

## Drivers

- **Faster iteration**: pure-logic test in <1s, AI eval in <5min, on macOS native — no simulator boot tax.
- **Lower bug surface**: explicit module seams, no hidden iOS dependencies in domain code, every adapter testable with stubs.
- **Better future addition**: reusable core for future watchOS / macOS / multiple-app scenarios.
- **Less duplication**: domain logic lives in one place, screen mappings / keyword taxonomies / parsing prefixes consolidated.

## Workflow goals

| Touched code | Test command | Expected wall time |
|---|---|---|
| Pure logic (parsers, math, services) | `cd DriftCore && swift test` | <1s warm |
| AI pipeline / LLM eval | `xcodebuild test -scheme DriftLLMEvalMacOS -destination 'platform=macOS'` | <5min full, <30s for deterministic per-stage |
| iOS UI / HealthKit / Widget integration | `xcodebuild test -scheme Drift -destination 'iOS Simulator'` | reserved for actual iOS-specific work |
| Pre-TestFlight | run everything | full validation |

## Module boundaries

- [ ] **No iOS-framework imports anywhere in `DriftCore/Sources/DriftCore/`**: UIKit, SwiftUI, HealthKit, WidgetKit, AVFoundation, Speech, Photos, AppIntents, UserNotifications
- [ ] **No direct call to `*Service.shared` of an iOS-only service from DriftCore** — all such calls go through a `DriftPlatform.*` adapter
- [ ] **iOS Drift target compiles with `import DriftCore` everywhere** — no fallback "old internal" types

## Adapter protocols (in `DriftCore/Sources/DriftCore/Adapters/`)

- [x] `HealthDataProvider` — HealthKit reads (sleep, HRV, workouts, steps, glucose, biomarkers, body comp)
- [x] `WidgetRefresher` — `refresh()`
- [ ] `LocalNotifier` — schedule + cancel local notifications
- [ ] `SpeechRecognizer` — voice transcription
- [ ] `KeychainStorage` — read/write secrets (used by CloudVisionKey)
- [ ] `CloudVisionProvider` — Photo Log OCR via Anthropic / OpenAI / Gemini
- [ ] `AppIntentsBridge` — if any cross-platform code touches AppIntents

iOS Drift app provides concrete impls for all of the above and registers them in `DriftApp.init()` via a single `DriftPlatform.boot()` call.

## Migration scope — every file accounted for

### Models — all in DriftCore
- [x] 19 existing models migrated
- [ ] `WeightGoal` migrated (last model)

### Persistence — `DriftCore/Sources/DriftCore/Persistence/`
- [ ] `AppDatabase.swift` (845 lines)
- [ ] `AppDatabase+FoodUsage.swift` (431)
- [ ] `AppDatabase+LabsAndScans.swift` (183)
- [ ] `Migrations.swift` (558)
- [ ] `Persistence.swift` (71)

### Cross-platform services — `DriftCore/Sources/DriftCore/Services/`
Already moved (10): `InputNormalizer`, `AIScreen`, `AIActionParser`, `AIActionExecutor` (parsers), `IntentClassifier` (parsers), `ToolSchema`, `ToolRanker`, `PromptUtils`, `IntentThresholds`, `AIResponseCleaner`, `BiomarkerKnowledgeBase`, `SpellCorrectService`.

To move:
- [ ] `Preferences` (split: photo-log parts stay in Drift as extension)
- [ ] `ConversationState` + `ConversationStatePersistence` (split: persisted snapshot's iOS-only fields stay in Drift extension)
- [ ] `WeightTrendCalculator`
- [ ] `WeightTrendService`
- [ ] `TDEEEstimator`
- [ ] `WeightServiceAPI`
- [ ] `AIDataCache` (refactored to use `HealthDataProvider`)
- [ ] `FoodService` (refactored to use `WidgetRefresher`)
- [ ] `WorkoutService`
- [ ] `ExerciseService`
- [ ] `ExerciseDatabase`
- [ ] `SupplementService`
- [ ] `GlucoseService`
- [ ] `BiomarkerService`
- [ ] `DEXAService`
- [ ] `SleepRecoveryService` (refactored to use `HealthDataProvider`)
- [ ] `BehaviorInsightService`
- [ ] `ChatTelemetryService`
- [ ] `AIRuleEngine`
- [ ] `USDAFoodService`
- [ ] `OpenFoodFactsService`
- [ ] `CGMImportService`
- [ ] `LabReportStorage`
- [ ] `LabReportOCR` + `LabReportOCR+Biomarkers` (decide: cross-platform via Vision-protocol shim, or keep iOS)
- [ ] `BarcodeCache+OFF` extension (currently iOS, may stay)
- [ ] `DefaultFoods`
- [ ] `DefaultTemplates`
- [ ] `PronounResolver`
- [ ] `FoodEntryRefResolver`
- [ ] `RecoveryEstimator`
- [ ] `ComposedFoodParser`
- [ ] `VoiceTranscriptionPostFixer` (or delete if dead)
- [ ] `Features` (feature flags)
- [ ] `CycleCalculations`
- [ ] `AIContextBuilder` + `AIContextBuilder+Health` (refactored to use `HealthDataProvider`)
- [ ] `AIChainOfThought`
- [ ] `AIToolAgent`
- [ ] `StaticOverrides` (refactored to use `WidgetRefresher`)
- [ ] `ToolRegistration` (refactored to use `HealthDataProvider`)
- [ ] `LocalAIService`
- [ ] `LlamaCppBackend` + `AIBackend` protocol (requires adding `llama` binaryTarget to `DriftCore/Package.swift`)
- [ ] `AIModelManager`

### iOS-only services — stay in `Drift/Services/`
- [ ] `HealthKitService` + `HealthKitService+Cycle` + `HealthKitService+Sleep` — conforms to `HealthDataProvider`
- [ ] `WidgetDataProvider` — wrapped by `WidgetCenterRefresher`
- [ ] `NotificationService` — conforms to `LocalNotifier`
- [ ] `SpeechRecognitionService` — conforms to `SpeechRecognizer`
- [ ] `CloudVision/*` — conforms to `CloudVisionProvider`
- [ ] `BodySpecPDFParser` — keep iOS or move (PDFKit is cross-platform)
- [ ] `NutritionLabelOCR` — likely stays iOS (Vision framework)
- [ ] `Tools/PhotoLogTool` — uses CloudVision

## Test runtime — every suite passes where it should

- [ ] **macOS DriftCoreTests**: all 26+ gold-set tests pass via `cd DriftCore && swift test`, <1s warm, <5s cold
- [ ] **macOS DriftLLMEvalMacOS deterministic**: NormalizerEval, IntentClassifierEval, ToolRouterEval, DomainExtractorEval (per-stage) — all pass, <30s wall combined
- [ ] **macOS DriftLLMEvalMacOS LLM**: IntentRoutingEval, MultiTurnRegressionTests, MultiStageEval, etc. — all build + run with real Gemma 4 (current test failures are LLM regressions, not infra)
- [ ] **iOS DriftRegressionTests**: all 26 gold-set tests still pass on iOS simulator (no regression from the moves)
- [ ] **iOS DriftTests**: 729-test unit suite still passes on iOS simulator
- [ ] **Pure-logic DriftTests subset migrated** to `DriftCore/Tests/DriftCoreTests/` (services that no longer need iOS Sim — calculator tests, parser tests, normalizer tests, etc.)

## Duplication / clean code

- [x] Screen→service mapping → single source on `AIScreen`
- [x] Food-verb prefix stripping → `stripFoodLead`
- [ ] **Domain keyword classification** — explicit decision documented: kept per-service (different concerns) OR consolidated into a `DomainKeywords` taxonomy
- [ ] **Tool-name → service mapping** — single source (similar to AIScreen.serviceName)
- [ ] **No `// removed` / `// legacy` / `// TODO migrate` comments** in DriftCore code
- [ ] **No `// see also xxx` cross-references** that would rot — kill or fix
- [ ] **No bulk-public-ified noise** — every `public` is intentional, scoped to what crosses the module boundary
- [ ] **Naming consistency** — settle the `XXXService` vs `XXXAPI` vs bare-noun mix in services

## Build verification — final state

- [ ] `cd DriftCore && swift build` ✅
- [ ] `cd DriftCore && swift test` ✅ all pass
- [ ] `xcodebuild build -scheme Drift -destination 'iOS Simulator,name=iPhone 17 Pro'` ✅
- [ ] `xcodebuild test -scheme Drift -destination 'iOS Simulator,name=iPhone 17 Pro' -only-testing:DriftTests` ✅ all pass
- [ ] `xcodebuild test -scheme DriftRegressionTests -destination 'iOS Simulator,name=iPhone 17 Pro'` ✅ all pass
- [ ] `xcodebuild test -scheme DriftLLMEvalMacOS -destination 'platform=macOS' -only-testing:'DriftLLMEvalMacOS/NormalizerEval'` ✅ all pass
- [ ] `xcodebuild build -scheme DriftLLMEvalMacOS -destination 'platform=macOS'` ✅
- [ ] TestFlight archive builds clean (when next attempted)

## Reorganization (after migration completes)

- [ ] DriftCore directory structure:
  ```
  DriftCore/Sources/DriftCore/
    Models/        (19 + WeightUnit + WeightGoal)
    Persistence/   (AppDatabase + 4 extensions)
    Adapters/      (5-7 platform protocols + DriftPlatform registry)
    Domain/
      Food/        (FoodService, ComposedFoodParser, FoodEntryRefResolver, USDAFoodService, OpenFoodFactsService, ...)
      Weight/      (WeightTrendCalculator, WeightTrendService, TDEEEstimator, WeightServiceAPI, ...)
      Workout/     (WorkoutService, ExerciseService, ExerciseDatabase, ...)
      Health/      (SupplementService, GlucoseService, BiomarkerService, DEXAService, SleepRecoveryService, BiomarkerKnowledgeBase, CycleCalculations, ...)
    AI/
      Parsing/     (InputNormalizer, AIActionParser, AIActionExecutor)
      Classification/ (IntentClassifier, IntentThresholds, AIResponseCleaner)
      Tools/       (ToolSchema, ToolRanker, ToolRegistration, AIScreen, PromptUtils)
      Pipeline/    (AIContextBuilder, AIChainOfThought, AIToolAgent, StaticOverrides, AIRuleEngine, ConversationState, AIDataCache)
      LLM/         (LocalAIService, LlamaCppBackend, AIBackend, AIModelManager)
    Utilities/     (DateFormatters, Log, MacroFormatters, Preferences)
  ```
- [ ] Drift/ directory mirrors:
  ```
  Drift/
    Adapters/      (HealthKitService, WidgetCenterRefresher, NotificationCenterImpl, SpeechRecognizerImpl, KeychainStorageImpl, CloudVisionImpl)
    Views/
    ViewModels/
    Resources/
    DriftApp.swift
  ```
- [ ] CLAUDE.md updated with the new dev workflow (which command for which kind of change)

---

When the file has every box checked, the work is done.
