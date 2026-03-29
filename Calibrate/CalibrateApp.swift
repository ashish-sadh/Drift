import SwiftUI

@main
struct CalibrateApp: App {
    @State private var hasRequestedHealthKit = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .task {
                    if !hasRequestedHealthKit {
                        hasRequestedHealthKit = true
                        try? await HealthKitService.shared.requestAuthorization()
                        _ = try? await HealthKitService.shared.syncWeight()
                    }
                }
        }
    }
}
