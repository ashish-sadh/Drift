import SwiftUI
import Charts

struct WeightTabView: View {
    @Binding var syncComplete: Bool
    @State private var viewModel = WeightViewModel()
    @State private var showingAddWeight = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Time range
                    Picker("Range", selection: $viewModel.selectedTimeRange) {
                        ForEach(WeightViewModel.TimeRange.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.selectedTimeRange) { _, _ in viewModel.loadEntries() }

                    if let trend = viewModel.trend {
                        WeightChartView(trend: trend, unit: viewModel.weightUnit)
                            .frame(height: 220)

                        WeightInsightsView(trend: trend, unit: viewModel.weightUnit)

                        WeightLogListView(
                            entries: viewModel.entries,
                            unit: viewModel.weightUnit,
                            onDelete: { viewModel.deleteWeight(id: $0) }
                        )
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "scalemass")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.accent.opacity(0.5))
                            Text("No Weight Data")
                                .font(.headline)
                            Text("Log your first weight or connect Apple Health.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Sync from Apple Health") {
                                Task {
                                    _ = try? await HealthKitService.shared.syncWeight()
                                    viewModel.loadEntries()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)

                            Button("Log Weight Manually") { showingAddWeight = true }
                                .buttonStyle(.bordered)
                        }
                        .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Weight")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddWeight = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAddWeight) {
                WeightEntryView(unit: viewModel.weightUnit) { viewModel.addWeight(value: $0) }
            }
            .onAppear { viewModel.loadEntries() }
            .onChange(of: syncComplete) { _, done in
                if done { viewModel.loadEntries() }
            }
        }
    }
}
