import SwiftUI

struct WeightLogListView: View {
    let entries: [WeightEntry]
    let unit: WeightUnit
    let onDelete: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(entries.prefix(15).enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(String(format: "%.1f", unit.convert(fromKg: entry.weightKg))) \(unit.displayName)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            Text(formatDate(entry.date))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        if index < entries.count - 1 {
                            let prev = entries[index + 1]
                            let change = unit.convert(fromKg: entry.weightKg - prev.weightKg)
                            HStack(spacing: 3) {
                                Image(systemName: change < -0.01 ? "arrow.down.right" : change > 0.01 ? "arrow.up.right" : "arrow.right")
                                    .font(.caption2)
                                Text("\(change >= 0 ? "+" : "")\(String(format: "%.1f", change))")
                                    .font(.caption.monospacedDigit())
                            }
                            .foregroundStyle(change < -0.01 ? Theme.deficit : change > 0.01 ? Theme.surplus : .secondary)
                        }

                        if entry.syncedFromHk {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(Theme.heartRed.opacity(0.6))
                        }
                    }
                    .padding(.vertical, 8)

                    if index < min(entries.count, 15) - 1 {
                        Divider().overlay(Color.white.opacity(0.05))
                    }
                }
            }
            .card()
        }
    }

    private func formatDate(_ s: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let d = f.date(from: s) else { return s }
        return DateFormatters.dayDisplay.string(from: d)
    }
}
