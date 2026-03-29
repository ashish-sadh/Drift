import SwiftUI

@main
struct DriftApp: App {
    @State private var hasRequestedHealthKit = false
    @State private var syncComplete = false

    var body: some Scene {
        WindowGroup {
            ContentView(syncComplete: $syncComplete)
                .preferredColorScheme(.dark)
                .task {
                    if !hasRequestedHealthKit {
                        hasRequestedHealthKit = true
                        do {
                            try await HealthKitService.shared.requestAuthorization()
                            let count = try await HealthKitService.shared.syncWeight()
                            Log.app.info("Initial sync: \(count) weight entries")
                            syncComplete = true
                        } catch {
                            Log.app.error("Initial sync failed: \(error.localizedDescription)")
                            syncComplete = true
                        }
                    }
                }
        }
    }
}
