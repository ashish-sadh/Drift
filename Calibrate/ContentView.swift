import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }

            WeightTabView()
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
    ContentView()
}
