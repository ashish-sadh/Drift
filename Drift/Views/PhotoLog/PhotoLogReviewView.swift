import SwiftUI

/// Second step of the Photo Log flow. The cloud-vision response has been
/// decoded into `PhotoLogEditableItem`s by the parent; this view lets the
/// user uncheck misrecognized items, tweak the grams inline (macros scale
/// with the cached per-gram rates), pick a meal period, and log the
/// selected items. Shows an empty state if the provider returned nothing.
/// #224 / #267.
struct PhotoLogReviewView: View {
    @Binding var items: [PhotoLogEditableItem]
    let overallConfidence: Confidence
    let notes: String?
    let foodLog: FoodLogViewModel
    let onLogged: () -> Void
    let onRetake: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var mealType: MealType = .snack
    @State private var mealTypeResolved = false

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .background(Theme.background)
            .navigationTitle("Review Photo Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: resolveDefaultMealType)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Populated content

    private var content: some View {
        VStack(spacing: 0) {
            List {
                overallSection
                itemsSection
                if let notes, !notes.isEmpty {
                    Section {
                        Text(notes)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Notes")
                    }
                }
                mealSection
                totalsSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            logButton
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.background)
        }
    }

    private var overallSection: some View {
        Section {
            HStack {
                confidenceBadge(for: overallConfidence, big: true)
                Spacer()
                Text("\(items.count) item\(items.count == 1 ? "" : "s") detected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var itemsSection: some View {
        Section {
            ForEach($items) { $item in
                PhotoLogItemRow(item: $item)
            }
        } header: {
            Text("Items")
        } footer: {
            Text("Uncheck anything the model got wrong. Tap grams to adjust.")
                .font(.caption2)
        }
    }

    private var mealSection: some View {
        Section {
            Picker("Meal", selection: $mealType) {
                ForEach(MealType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
        } header: {
            Text("Log as")
        }
    }

    private var totalsSection: some View {
        let totals = PhotoLogTotals.sum(items)
        return Section {
            HStack {
                totalStat("\(totals.calories)", "cal")
                Divider().frame(height: 24)
                totalStat("\(totals.proteinG)g", "protein")
                Divider().frame(height: 24)
                totalStat("\(totals.carbsG)g", "carbs")
                Divider().frame(height: 24)
                totalStat("\(totals.fatG)g", "fat")
            }
            .frame(maxWidth: .infinity)
        } header: {
            Text("Totals (\(totals.selectedCount) selected)")
        }
    }

    private func totalStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.fontHeadline).foregroundStyle(Theme.textPrimary)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var logButton: some View {
        let totals = PhotoLogTotals.sum(items)
        return Button {
            logSelected()
        } label: {
            Text(totals.selectedCount == 0
                 ? "Select at least one item"
                 : "Log \(totals.selectedCount) item\(totals.selectedCount == 1 ? "" : "s") as \(mealType.displayName)")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .disabled(totals.selectedCount == 0)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(Theme.textTertiary)
            Text("We couldn't spot any food in that photo.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Try one with the meal centered and in good light.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                onRetake()
            } label: {
                Label("Take another", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .padding(.top, 8)
        }
        .padding(24)
    }

    // MARK: - Behavior

    /// Resolve the default meal period the first time this view appears.
    /// Uses the same 3h-inherit rule as manual food logging so a second
    /// bowl at 10am still defaults to breakfast. Flag ensures we don't
    /// clobber a user-picked meal on subsequent body refreshes.
    private func resolveDefaultMealType() {
        guard !mealTypeResolved else { return }
        mealType = MealType.resolve(now: Date(), recentEntries: foodLog.todayEntries)
        mealTypeResolved = true
    }

    private func logSelected() {
        for item in items where item.selected {
            let food = Food(
                name: item.name,
                category: "Photo Log",
                servingSize: max(item.grams, 1),
                servingUnit: "g",
                calories: item.calories,
                proteinG: item.proteinG,
                carbsG: item.carbsG,
                fatG: item.fatG,
                source: "photo_log"
            )
            foodLog.logFood(food, servings: 1, mealType: mealType)
        }
        onLogged()
        dismiss()
    }

    private func confidenceBadge(for confidence: Confidence, big: Bool = false) -> some View {
        let (text, color): (String, Color) = switch confidence {
        case .high: ("High confidence", Theme.deficit)
        case .medium: ("Medium confidence", Theme.fatYellow)
        case .low: ("Low confidence — double-check", Theme.surplus)
        }
        return Label(text, systemImage: confidence == .low ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
            .font(big ? .footnote : .caption2)
            .foregroundStyle(color)
    }
}

// MARK: - Row

private struct PhotoLogItemRow: View {
    @Binding var item: PhotoLogEditableItem
    @FocusState private var gramsFocused: Bool
    @State private var gramsText: String = ""

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                item.selected.toggle()
            } label: {
                Image(systemName: item.selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.selected ? Theme.accent : Theme.textTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if item.confidence == .low {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.surplus)
                    }
                }
                Text("\(Int(item.calories.rounded())) cal · \(Int(item.proteinG.rounded()))P / \(Int(item.carbsG.rounded()))C / \(Int(item.fatG.rounded()))F")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                TextField("0", text: $gramsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .focused($gramsFocused)
                    .frame(width: 52)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    .onChange(of: gramsText) { _, newValue in
                        let parsed = Double(newValue) ?? 0
                        if parsed != item.grams {
                            item.grams = parsed
                            item.rescale()
                        }
                    }
                Text("g").font(.caption).foregroundStyle(.secondary)
            }
        }
        .opacity(item.selected ? 1.0 : 0.45)
        .onAppear {
            gramsText = String(Int(item.grams.rounded()))
        }
    }
}
