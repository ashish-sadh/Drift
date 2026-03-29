import SwiftUI

struct WeightInsightsView: View {
    let trend: WeightTrendCalculator.WeightTrend
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Insights")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // Weight changes
            VStack(spacing: 0) {
                changeRow("3-day", value: trend.weightChanges.threeDay)
                Divider().overlay(Color.white.opacity(0.05))
                changeRow("7-day", value: trend.weightChanges.sevenDay)
                Divider().overlay(Color.white.opacity(0.05))
                changeRow("14-day", value: trend.weightChanges.fourteenDay)
                Divider().overlay(Color.white.opacity(0.05))
                changeRow("30-day", value: trend.weightChanges.thirtyDay)
                Divider().overlay(Color.white.opacity(0.05))
                changeRow("90-day", value: trend.weightChanges.ninetyDay)
            }
            .card()

            // Key metrics grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricCard(
                    title: "Current Weight",
                    value: String(format: "%.1f", unit.convert(fromKg: trend.currentEMA)),
                    subtitle: unit.displayName,
                    detail: "Smoothed"
                )
                metricCard(
                    title: "Weekly Change",
                    value: String(format: "%+.2f", unit.convert(fromKg: trend.weeklyRateKg)),
                    subtitle: "\(unit.displayName)/wk",
                    detail: trend.trendDirection.displayText,
                    valueColor: trend.weeklyRateKg < -0.05 ? Theme.deficit : trend.weeklyRateKg > 0.05 ? Theme.surplus : .primary
                )
                metricCard(
                    title: trend.estimatedDailyDeficit < 0 ? "Daily Deficit" : "Daily Surplus",
                    value: String(format: "%+.0f", trend.estimatedDailyDeficit),
                    subtitle: "kcal/day",
                    detail: "From trend",
                    valueColor: trend.estimatedDailyDeficit < 0 ? Theme.deficit : Theme.surplus
                )
                if let proj = trend.projection30Day {
                    metricCard(
                        title: "30-Day Projection",
                        value: String(format: "%.1f", unit.convert(fromKg: proj)),
                        subtitle: unit.displayName,
                        detail: "At current rate"
                    )
                }
            }
        }
    }

    private func changeRow(_ period: String, value: Double?) -> some View {
        HStack {
            Text(period)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 55, alignment: .leading)

            if let value {
                let d = unit.convert(fromKg: value)
                Text("\(d >= 0 ? "+" : "")\(String(format: "%.1f", d)) \(unit.displayName)")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(d < -0.01 ? Theme.deficit : d > 0.01 ? Theme.surplus : .primary)
                Spacer()
                Image(systemName: d < -0.01 ? "arrow.down.right" : d > 0.01 ? "arrow.up.right" : "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(d < -0.01 ? Theme.deficit : d > 0.01 ? Theme.surplus : .secondary)
            } else {
                Text("--")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(.vertical, 8)
    }

    private func metricCard(title: String, value: String, subtitle: String, detail: String, valueColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(valueColor)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
