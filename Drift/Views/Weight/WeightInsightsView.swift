import SwiftUI

struct WeightInsightsView: View {
    let trend: WeightTrendCalculator.WeightTrend
    let unit: WeightUnit
    var isLosing: Bool = true

    /// Goal-aware color for weight changes.
    /// If losing: decrease=green, increase=red.
    /// If gaining: increase=green, decrease=red.
    private func changeColor(_ value: Double) -> Color {
        let isDecrease = value < -0.01
        let isIncrease = value > 0.01
        if isLosing {
            return isDecrease ? Theme.deficit : isIncrease ? Theme.surplus : .secondary
        } else {
            return isIncrease ? Theme.deficit : isDecrease ? Theme.surplus : .secondary
        }
    }

    private func directionLabel(_ value: Double) -> String {
        value < -0.01 ? "Decrease" : value > 0.01 ? "Increase" : "Stable"
    }

    private func directionIcon(_ value: Double) -> String {
        value < -0.01 ? "arrow.down.right" : value > 0.01 ? "arrow.up.right" : "arrow.right"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Insights & Data")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // Weight changes
            VStack(spacing: 0) {
                Text("Weight Changes")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 6)

                changeRow("3-day", value: trend.weightChanges.threeDay)
                changeRow("7-day", value: trend.weightChanges.sevenDay)
                changeRow("14-day", value: trend.weightChanges.fourteenDay)
                changeRow("30-day", value: trend.weightChanges.thirtyDay)
                changeRow("90-day", value: trend.weightChanges.ninetyDay)
            }
            .card()

            // Descriptive metric cards
            insightCard(
                value: String(format: "%.1f", unit.convert(fromKg: trend.currentEMA)),
                valueUnit: unit.displayName,
                title: "Current Weight",
                description: "Your true weight after smoothing out day-to-day fluctuations.",
                valueColor: .primary
            )

            let rateColor = changeColor(trend.weeklyRateKg)
            insightCard(
                value: String(format: "%+.2f", unit.convert(fromKg: trend.weeklyRateKg)),
                valueUnit: "\(unit.displayName)/wk",
                title: "Weekly Weight Change",
                description: "Your typical weekly rate over the past three weeks.",
                valueColor: rateColor
            )

            let deficitColor = changeColor(trend.estimatedDailyDeficit < 0 ? -1 : 1)
            insightCard(
                value: String(format: "%+.0f", trend.estimatedDailyDeficit),
                valueUnit: "kcal/day",
                title: trend.estimatedDailyDeficit < 0 ? "Energy Deficit" : "Energy Surplus",
                description: "Estimated daily caloric \(trend.estimatedDailyDeficit < 0 ? "deficit" : "surplus") based on your weight trend over the past three weeks.",
                valueColor: isLosing ? (trend.estimatedDailyDeficit < 0 ? Theme.deficit : Theme.surplus) : (trend.estimatedDailyDeficit > 0 ? Theme.deficit : Theme.surplus)
            )

            if let proj = trend.projection30Day {
                insightCard(
                    value: String(format: "%.1f", unit.convert(fromKg: proj)),
                    valueUnit: unit.displayName,
                    title: "30-Day Projection",
                    description: "Your projected weight in 30 days if your current rate continues.",
                    valueColor: .primary
                )
            }
        }
    }

    private func changeRow(_ period: String, value: Double?) -> some View {
        HStack {
            Text(period)
                .font(.subheadline).foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            if let value {
                let d = unit.convert(fromKg: value)
                Text("\(d >= 0 ? "+" : "")\(String(format: "%.1f", d)) \(unit.displayName)")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(changeColor(value))
                Spacer()
                Image(systemName: directionIcon(value))
                    .font(.caption2).foregroundStyle(changeColor(value))
                Text(directionLabel(value))
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("--").font(.subheadline).foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(.vertical, 6)
    }

    private func insightCard(value: String, valueUnit: String, title: String, description: String, valueColor: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 2) {
                Text(value)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(valueColor)
                Text(valueUnit)
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(width: 90)
            .padding(.vertical, 12)
            .background(Theme.cardBackgroundElevated, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(description).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }
}
