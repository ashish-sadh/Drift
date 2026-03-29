import SwiftUI
import Charts

struct WeightChartView: View {
    let trend: WeightTrendCalculator.WeightTrend
    let unit: WeightUnit

    private var displayPoints: [(date: Date, actual: Double?, ema: Double)] {
        trend.dataPoints.map {
            ($0.date, $0.actualWeight.map { unit.convert(fromKg: $0) }, unit.convert(fromKg: $0.emaWeight))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                if let last = displayPoints.last {
                    Text(String(format: "%.1f", last.ema))
                        .font(.title.weight(.bold).monospacedDigit())
                    Text(unit.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let first = displayPoints.first?.ema, let last = displayPoints.last?.ema {
                    let diff = last - first
                    Text("\(diff >= 0 ? "+" : "")\(String(format: "%.1f", diff))")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(diff < 0 ? Theme.deficit : diff > 0 ? Theme.surplus : .secondary)
                }
            }

            // Chart
            Chart {
                ForEach(displayPoints.indices, id: \.self) { i in
                    if let actual = displayPoints[i].actual {
                        PointMark(x: .value("", displayPoints[i].date), y: .value("", actual))
                            .foregroundStyle(Theme.accent.opacity(0.4))
                            .symbolSize(16)
                    }
                }
                ForEach(displayPoints.indices, id: \.self) { i in
                    LineMark(x: .value("", displayPoints[i].date), y: .value("", displayPoints[i].ema))
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                }
            }

            // Legend
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Circle().fill(Theme.accent.opacity(0.4)).frame(width: 6, height: 6)
                    Text("Scale").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1).fill(Theme.accent).frame(width: 12, height: 2)
                    Text("Trend").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }
}
