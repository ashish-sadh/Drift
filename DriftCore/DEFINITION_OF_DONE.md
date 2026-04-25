# DriftCore — Definition of Done

✅ **Done as of 2026-04-25.** Reference for future agents picking up the codebase.

## Drivers (delivered)

- **Faster iteration**: pure-logic test in **<0.1s warm**, AI eval **~5min** on macOS (was 30 min on simulator).
- **Lower bug surface**: every iOS-framework dependency goes through an explicit `DriftPlatform` adapter; tests inject stubs.
- **Better future addition**: DriftCore is a self-contained Swift package — reusable in watchOS, macOS companion, or multiple-app scenarios.
- **Less duplication**: screen→service mapping, food-verb prefix stripping consolidated; domain logic lives in one place per concern.

## Workflow — match the test command to what you touched

| Touched code | Command | Wall time |
|---|---|---|
| Pure logic in DriftCore | `cd DriftCore && swift test` | **<1s warm** (0.077s for 30 tests) |
| AI pipeline / LLM eval | `xcodebuild test -scheme DriftLLMEvalMacOS -destination 'platform=macOS'` | <30s deterministic per-stage, ~5min full LLM eval |
| iOS UI / HealthKit / Widget | `xcodebuild test -scheme Drift -destination 'iOS Simulator'` | ~10s for DriftTests |
| Pre-TestFlight | all of the above | full validation |

## Module boundaries — verified

- [x] **No iOS-framework imports in `DriftCore/Sources/DriftCore/`** — verified by `grep -lE "import (UIKit|SwiftUI|HealthKit|WidgetKit|AVFoundation|Speech|Photos|AppIntents|UserNotifications)" DriftCore/Sources/`
- [x] **No direct `*Service.shared` reach into iOS-only types from DriftCore** — services that need HealthKit/Widget go through `DriftPlatform.health` / `DriftPlatform.widget`
- [x] **iOS Drift target compiles with `import DriftCore` everywhere** — every call site uses public DriftCore API, no shadowing

## Adapter protocols (`DriftCore/Sources/DriftCore/Adapters/`)

- [x] `HealthDataProvider` — fetchRecentWorkouts, fetchRecentSleepData, fetchSleepHours, fetchSleepDetail, fetchHRV, fetchRestingHeartRate, fetchCycleHistory, fetchCaloriesBurned, fetchSteps, isAvailable
- [x] `WidgetRefresher` — `refresh()`
- [x] `DriftPlatform` registry — `DriftApp.init()` installs both impls

Future protocols (when cross-platform code starts needing them — currently no DriftCore code touches these, so no protocol exists yet):
- LocalNotifier (UserNotifications) — only iOS Views call NotificationService directly
- SpeechRecognizer (Speech) — only iOS Views
- KeychainStorage / CloudVisionProvider — only iOS Views via PhotoLog flow

## Migration scope — every file accounted for

### Models — `DriftCore/Sources/DriftCore/Models/` (24 files)
All Drift Models in Core, plus value types extracted from iOS service nested types:
- [x] All 20 original models (Food, FoodEntry, WeightEntry, Workout, Supplement, etc.)
- [x] WeightUnit, WeightGoal
- [x] RecipeItem (was QuickAddView.RecipeItem)
- [x] BodySpecParsedScan + BodySpecParsedRegion
- [x] PlantPointsFoodItem

### Persistence — `DriftCore/Sources/DriftCore/Persistence/` (5 files)
- [x] AppDatabase.swift + AppDatabase+FoodUsage + AppDatabase+LabsAndScans
- [x] Migrations.swift, Persistence.swift
- Selective public: 53 methods externally called → public; everything else internal.

### Domain — `DriftCore/Sources/DriftCore/Domain/`
- [x] Food/ (8): FoodService, USDAFoodService, OpenFoodFactsService, DefaultFoods, PlantPointsService, ComposedFoodParser, FoodEntryRefResolver, SpellCorrectService
- [x] Weight/ (4): WeightTrendCalculator, WeightTrendService, TDEEEstimator, WeightServiceAPI
- [x] Workout/ (4): WorkoutService, ExerciseService, ExerciseDatabase, DefaultTemplates
- [x] Health/ (11): SupplementService, GlucoseService, BiomarkerService, BiomarkerKnowledgeBase, DEXAService, SleepRecoveryService, RecoveryEstimator, CycleCalculations, CGMImportService, LabReportStorage, BehaviorInsightService

### AI — `DriftCore/Sources/DriftCore/AI/`
- [x] Parsing/ (6): InputNormalizer, AIActionParser, AIActionExecutor + Lookup, PronounResolver, VoiceTranscriptionPostFixer
- [x] Classification/ (5): IntentClassifier + Live, IntentThresholds, AIResponseCleaner, ClarificationBuilder
- [x] Tools/ (9): ToolSchema, ToolRegistry+Execute, ToolRanker, ToolRegistration, AIScreen, AIScreenTracker, PromptUtils, CrossDomainInsightTool, WeightTrendPredictionTool
- [x] Pipeline/ (12): AIContextBuilder + Health, AIChainOfThought, AIToolAgent, StaticOverrides, AIRuleEngine, ConversationState, ConversationStatePersistence, ConversationHistoryBuilder, AIDataCache, Features, ChatTelemetryService
- [x] LLM/ (4): AIBackend protocol, LlamaCppBackend, LocalAIService, AIModelManager (DriftCore/Package.swift links the llama xcframework)

### Utilities — `DriftCore/Sources/DriftCore/Utilities/`
- [x] DateFormatters, Log, MacroFormatters
- [x] Preferences (split — photoLog accessors stay in iOS extension)
- [x] CSVParser

### iOS-only — stays in `Drift/Services/` (~12 files)
HealthKitService + extensions, WidgetDataProvider, NotificationService, SpeechRecognitionService, BodySpecPDFParser, LabReportOCR + Biomarkers, NutritionLabelOCR, CloudVision/*, PhotoLogTool, FoodService+Logging.

## Test coverage

- [x] **macOS DriftCoreTests**: 30 gold-set tests pass via `cd DriftCore && swift test`, 0.077s
- [x] **macOS DriftLLMEvalMacOS**: builds + runs llama.cpp natively (Gemma 4 model loads from ~/drift-state/models)
- [x] **iOS DriftTests**: 729-test unit suite passes
- [x] **iOS DriftRegressionTests**: 26 gold-set tests still pass on iOS too

## Duplication / clean code

- [x] Screen→service mapping → single source on `AIScreen.serviceName` / `AIScreen.defaultTools`
- [x] Food-verb prefix stripping → `stripFoodLead(_:)` shared helper
- [x] Health value types (SleepDetail, CycleEntry, HealthWorkout, SleepNight, CaloriesBurned) extracted from HealthKitService nested types into `Adapters/HealthValueTypes.swift`
- [x] Output-only DTOs (WeightTrend, MacroTargets, Estimate, ChatTurnRow) have public properties for reading but `internal` init — only DriftCore constructs
- [x] Selective public surface — every `public` is intentional, scoped to actual external callers (no blanket awk public-ification on permanent files)

## Reorganization

- [x] DriftCore directory structure as documented above
- [x] CLAUDE.md updated with the test workflow

## Lessons saved to memory

- `feedback_no_blanket_public.md` — public only methods externally called; never sed/awk-blanket
- `feedback_files_belong_in_core_if_no_ios_deps.md` — bridge / extension files without iOS framework imports go in DriftCore, not iOS Drift

---

**Final state:**
- DriftCore: ~110 files across 6 well-named subdirs
- Drift app: ~12 service files, all iOS-bound (HealthKit, WidgetKit, Vision, etc.) + Views/ViewModels/Resources
- Both builds green; macOS gold-set 30/30 in 0.077s; iOS unit suite green
