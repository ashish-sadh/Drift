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
                    tooltip: "Your typical weekly rate of change over the past \(WeightTrendCalculator.loadConfig().regressionWindowDays) days."
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
                    tooltip: "Estimated daily caloric \(deficit < 0 ? "deficit" : "surplus") based on your weight trend over the past \(WeightTrendCalculator.loadConfig().regressionWindowDays) days."
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

            // 21-day mini trend
            if trend.dataPoints.count >= 7 {
                last21DaysTrend
            }

            // Compact weight-change chips
            weightChangesRow

            // Weekday pattern insight
            if trend.dataPoints.count >= 14 {
                weekdayInsight
            }
        }
    }

    // MARK: - 21-Day Mini Trend

    private var last21DaysTrend: some View {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -21, to: Date())!
        let recent = trend.dataPoints.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return AnyView(EmptyView()) }

        let weights = recent.compactMap(\.actualWeight)
        let minW = weights.min() ?? 0
        let maxW = weights.max() ?? 0
        let range = max(maxW - minW, 0.1)
        let netChange = (weights.last ?? 0) - (weights.first ?? 0)

        return AnyView(
            VStack(spacing: 6) {
                HStack {
                    Text("Last 21 Days").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    Spacer()
                    let d = unit.convert(fromKg: netChange)
                    HStack(spacing: 2) {
                        Image(systemName: directionIcon(netChange)).font(.system(size: 9, weight: .bold))
                        Text(String(format: "%+.1f %@", d, unit.displayName))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                    }
                    .foregroundStyle(changeColor(netChange))
                }

                // Mini sparkline
                GeometryReader { geo in
                    let w = geo.size.width
                    let h: CGFloat = 40
                    let dayWidth = w / 20 // 21 days = 20 gaps

                    // EMA trend line
                    Path { path in
                        for (i, point) in recent.enumerated() {
                            let x = CGFloat(i) * dayWidth * (20.0 / max(CGFloat(recent.count - 1), 1))
                            let y = h - CGFloat((point.emaWeight - minW) / range) * h
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(Theme.accent.opacity(0.6), style: StrokeStyle(lineWidth: 1.5))

                    // Actual weight dots
                    ForEach(Array(recent.enumerated()), id: \.offset) { i, point in
                        if let actual = point.actualWeight {
                            let x = CGFloat(i) * dayWidth * (20.0 / max(CGFloat(recent.count - 1), 1))
                            let y = h - CGFloat((actual - minW) / range) * h
                            Circle()
                                .fill(changeColor(actual - point.emaWeight))
                                .frame(width: 4, height: 4)
                                .position(x: x, y: y)
                        }
                    }
                }
                .frame(height: 40)
            }
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        )
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

    private func metricCell(
        id: String,
        label: String,
        labelIcon: String? = nil,
        value: String,
        valueUnit: String,
        color: Color,
        direction: String? = nil,
        directionColor: Color? = nil,
        tooltip: String
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
