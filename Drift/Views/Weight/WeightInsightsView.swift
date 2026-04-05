import SwiftUI

struct WeightInsightsView: View {
    let trend: WeightTrendCalculator.WeightTrend
    let unit: WeightUnit
    var isLosing: Bool = true
    private func changeColor(_ value: Double) -> Color {
        let isDecrease = value < -0.01
        let isIncrease = value > 0.01
        if isLosing {
            return isDecrease ? Theme.deficit : isIncrease ? Theme.surplus : .secondary
        } else {
            return isIncrease ? Theme.deficit : isDecrease ? Theme.surplus : .secondary
        }
    }

    private func directionIcon(_ value: Double) -> String {
        value < -0.01 ? "arrow.down.right" : value > 0.01 ? "arrow.up.right" : "arrow.right"
    }

    var body: some View {
        VStack(spacing: 8) {
            // Key metrics — 2×2 compact grid
            HStack(spacing: 8) {
                metricCell(
                    id: "current",
                    label: "Current",
                    value: String(format: "%.1f", unit.convert(fromKg: trend.currentEMA)),
                    valueUnit: unit.displayName,
                    color: .primary,
                    tooltip: "Your true weight after smoothing out day-to-day fluctuations."
                )

                let rate = trend.weeklyRateKg
                metricCell(
                    id: "weekly",
                    label: "Weekly",
                    value: String(format: "%+.2f", unit.convert(fromKg: rate)),
                    valueUnit: "\(unit.displayName)/wk",
                    color: changeColor(rate),
                    direction: directionIcon(rate),
                    directionColor: changeColor(rate),
                    tooltip: "Your typical weekly rate of change over the past \(WeightTrendCalculator.loadConfig().regressionWindowDays) days.",
                    nudge: weeklyNudge(rate: rate)
                )
            }

            HStack(spacing: 8) {
                let deficit = trend.estimatedDailyDeficit
                let deficitColor = isLosing
                    ? (deficit < 0 ? Theme.deficit : Theme.surplus)
                    : (deficit > 0 ? Theme.deficit : Theme.surplus)
                metricCell(
                    id: "deficit",
                    label: deficit < 0 ? "Est. Deficit" : "Est. Surplus",
                    value: String(format: "%+.0f", deficit),
                    valueUnit: "kcal/day",
                    color: deficitColor,
                    direction: directionIcon(deficit),
                    directionColor: deficitColor,
                    tooltip: "Estimated daily caloric \(deficit < 0 ? "deficit" : "surplus") based on your weight trend over the past \(WeightTrendCalculator.loadConfig().regressionWindowDays) days.",
                    nudge: deficitNudge(deficit: deficit)
                )

                if let proj = trend.projection30Day {
                    metricCell(
                        id: "projected",
                        label: "Projected",
                        labelIcon: "chart.line.flattrend.xyaxis",
                        value: String(format: "%.1f", unit.convert(fromKg: proj)),
                        valueUnit: "\(unit.displayName) in 30d",
                        color: .primary,
                        tooltip: "Your projected weight in 30 days if your current rate continues."
                    )
                } else {
                    metricCell(
                        id: "projected",
                        label: "Projected",
                        labelIcon: "chart.line.flattrend.xyaxis",
                        value: "--",
                        valueUnit: "",
                        color: .secondary,
                        tooltip: "Not enough data yet. Keep logging for a few weeks."
                    )
                }
            }

            // Compact weight-change chips
            weightChangesRow

            // Weekday pattern insight
            if trend.dataPoints.count >= 14 {
                weekdayInsight
            }
        }
    }

    // MARK: - Weekday Pattern

    private var weekdayInsight: some View {
        let cal = Calendar.current
        var byDay: [Int: [Double]] = [:] // 1=Sun ... 7=Sat
        for p in trend.dataPoints {
            guard let w = p.actualWeight else { continue }
            let weekday = cal.component(.weekday, from: p.date)
            byDay[weekday, default: []].append(w)
        }
        let averages = byDay.compactMapValues { vals -> Double? in
            guard !vals.isEmpty else { return nil }
            return vals.reduce(0, +) / Double(vals.count)
        }
        guard averages.count >= 5 else { return AnyView(EmptyView()) } // need most days

        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let lightest = averages.min(by: { $0.value < $1.value })
        let heaviest = averages.max(by: { $0.value < $1.value })

        guard let light = lightest, let heavy = heaviest, light.key != heavy.key else {
            return AnyView(EmptyView())
        }

        return AnyView(
            Text("You tend to weigh least on \(dayNames[light.key])s and most on \(dayNames[heavy.key])s")
                .font(.caption2).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        )
    }

    // MARK: - Metric Cell

    // MARK: - Nudge Helpers

    private func weeklyNudge(rate: Double) -> String? {
        let absRate = abs(unit.convert(fromKg: rate))
        if isLosing {
            if rate < -0.01 && absRate > 1.0 { return "Aggressive pace — stay safe" }
            if rate < -0.01 && absRate >= 0.5 { return "Healthy pace" }
            if rate < -0.01 { return "Slow & steady" }
            if rate > 0.01 { return "Trending up — check intake" }
        } else {
            if rate > 0.01 && absRate > 0.5 { return "Strong gain pace" }
            if rate > 0.01 { return "Gaining steadily" }
            if rate < -0.01 { return "Trending down — check surplus" }
        }
        return "Maintaining"
    }

    private func deficitNudge(deficit: Double) -> String? {
        let abs = abs(deficit)
        if isLosing {
            if deficit < -750 { return "~1.5 lb/wk pace" }
            if deficit < -500 { return "~1 lb/wk pace" }
            if deficit < -250 { return "~0.5 lb/wk pace" }
            if deficit < 0 { return "Mild deficit" }
            return nil
        } else {
            if deficit > 500 { return "Strong surplus" }
            if deficit > 250 { return "Moderate surplus" }
            if deficit > 0 { return "Mild surplus" }
            return nil
        }
    }

    private func metricCell(
        id: String,
        label: String,
        labelIcon: String? = nil,
        value: String,
        valueUnit: String,
        color: Color,
        direction: String? = nil,
        directionColor: Color? = nil,
        tooltip: String,
        nudge: String? = nil
    ) -> some View {
        VStack(spacing: 4) {
            // Label + direction arrow
            HStack(spacing: 4) {
                if let labelIcon {
                    Image(systemName: labelIcon)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if let direction {
                    Image(systemName: direction)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(directionColor ?? color)
                }
            }

            // Value
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
                if !valueUnit.isEmpty {
                    Text(valueUnit)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Nudge
            if let nudge {
                Text(nudge)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Weight Changes Row

    private var weightChangesRow: some View {
        HStack(spacing: 0) {
            changeChip("3d", value: trend.weightChanges.threeDay)
            changeChip("7d", value: trend.weightChanges.sevenDay)
            changeChip("14d", value: trend.weightChanges.fourteenDay)
            changeChip("30d", value: trend.weightChanges.thirtyDay)
            changeChip("90d", value: trend.weightChanges.ninetyDay)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private func changeChip(_ period: String, value: Double?) -> some View {
        VStack(spacing: 3) {
            Text(period)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            if let value {
                let d = unit.convert(fromKg: value)
                HStack(spacing: 1) {
                    Image(systemName: directionIcon(value))
                        .font(.caption2.weight(.bold))
                    Text(String(format: "%+.1f", d))
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(changeColor(value))
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
