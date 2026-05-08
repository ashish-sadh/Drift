import SwiftUI
import DriftCore
import WidgetKit

@main
struct DriftApp: App {
    @State private var hasRequestedHealthKit = false
    @State private var syncComplete = false
    @State private var launchStage: LaunchStage = .starting
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Wire DriftCore adapter seams so cross-platform services can reach
        // HealthKit / WidgetKit through protocols instead of direct singletons.
        DriftPlatform.health = HealthKitService.shared
        DriftPlatform.widget = WidgetCenterRefresher()
        // Register all AI tools in ToolRegistry. Was previously called from
        // LocalAIService.init(); moved out during DriftCore migration
        // (96e3173) and the caller wiring was lost — every tool call has
        // been returning "unknown tool" since. PhotoLog tool registers
        // separately because it depends on iOS-only Keychain + gating.
        ToolRegistration.registerAll()
        PhotoLogTool.syncRegistration()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(syncComplete: $syncComplete, launchStage: launchStage)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, newPhase in
                    // Broadcast to any listening AIChatViewModel so it can snapshot state.
                    // Listener-based so the singleton doesn't need a VM reference.
                    if newPhase == .background || newPhase == .inactive {
                        NotificationCenter.default.post(name: .saveConversationState, object: nil)
                    }
                }
                .task {
                    if !hasRequestedHealthKit {
                        hasRequestedHealthKit = true
#if targetEnvironment(simulator)
                        // 🧪 Uncomment ONE to test on simulator:
                        // DebugSeedData.seedWeightGoalBug()    // reproduces "gain 14.1 kg" bug
                        // DebugSeedData.seedNormalGoal()        // normal losing goal (correct)
                        // DebugSeedData.seedGainingGoal()       // gaining goal scenario
                        #endif
                        // Stage transitions ALWAYS fire (even on simulator where the
                        // HealthKit calls are #if'd out) so the splash shows the same
                        // sequence in dev and prod — otherwise the simulator skips
                        // ".syncingHealth" and we'd never visually rehearse that frame.
                        launchStage = .syncingHealth
                        #if !targetEnvironment(simulator)
                        do {
                            try await HealthKitService.shared.requestAuthorization()
                            let count = try await HealthKitService.shared.syncWeight()
                            Log.app.info("Initial sync: \(count) weight entries")
                            let bodyComp = try await HealthKitService.shared.syncBodyComposition()
                            Log.app.info("Initial sync: \(bodyComp) body composition entries")
                        } catch {
                            Log.app.error("Initial sync failed: \(error.localizedDescription)")
                        }
                        #endif
                        // Recalculate weight trend from DB so latestWeightKg + trend are
                        // populated for any view or AI tool (weight_info, etc.) before
                        // the user navigates anywhere. Was previously initialized lazily
                        // by Dashboard's onAppear — non-Dashboard launch paths got stale
                        // values. Must run before TDEEEstimator.refresh() since TDEE
                        // reads WeightTrendService.shared.latestWeightKg.
                        launchStage = .calculatingTrends
                        WeightTrendService.shared.refresh()
                        // Refresh TDEE estimate (uses Apple Health + weight trend + food data)
                        launchStage = .estimatingEnergy
                        await TDEEEstimator.shared.refresh()
                        // ".almostThere" sticks on the splash through the 0.25s crossfade
                        // — both state changes commit in one MainActor tick so the user
                        // sees the final stage text fading out with the splash. Don't add
                        // a ".complete" assignment after — it'd race the crossfade.
                        launchStage = .almostThere
                        syncComplete = true

                        // Notifications + widget — fire-and-forget. iOS has a ~20s
                        // launch-watchdog kill; refreshScheduledAlerts() does ~35 DB
                        // reads (5 alerts × 7-day fetches in BehaviorInsightService
                        // plus medication + GLP-1 slot computation) and was blocking
                        // syncComplete inside that budget. The schedule registers
                        // asynchronously regardless of when this finishes — there is
                        // no UI affordance waiting on it. Same for widget data.
                        // Both services are @MainActor so we use Task (not detached)
                        // — they yield between awaits so UI stays responsive.
                        Task { @MainActor in
                            await NotificationService.refreshScheduledAlerts()
                        }
                        Task { @MainActor in
                            WidgetDataProvider.refreshWidgetData()
                        }
                    }
                }
        }
    }
}
