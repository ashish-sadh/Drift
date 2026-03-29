import SwiftUI

struct ContentView: View {
    @Binding var syncComplete: Bool

    var body: some View {
        TabView {
            DashboardView(syncComplete: $syncComplete)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }

            WeightTabView(syncComplete: $syncComplete)
                .tabItem {
                    Label("Weight", systemImage: "scalemass")
                }

            FoodTabView()
                .tabItem {
                    Label("Food", systemImage: "fork.knife")
                }

            SupplementsTabView()
                .tabItem {
                    Label("Supplements", systemImage: "pill")
                }

            MoreTabView()
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
        }
    }
}

#Preview {
    ContentView(syncComplete: .constant(true))
}
