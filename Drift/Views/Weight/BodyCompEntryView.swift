import SwiftUI

/// Entry view for body composition + optional weight.
/// Most smart scales give weight + body fat + BMI together.
struct BodyCompEntryView: View {
    let unit: WeightUnit
    let onSave: (Double?, Double?, Double?, Double?, Date) -> Void  // weight, bodyFat, bmi, water, date
    var lastBodyFat: Double? = nil
    var lastBMI: Double? = nil
    var lastWater: Double? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var bmiText = ""
    @State private var waterText = ""
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("Weight", systemImage: "scalemass.fill")
                        Spacer()
                        TextField("—", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(unit.displayName).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Weight (Optional)")
                } footer: {
                    Text("Add weight if your scale shows it alongside body composition.")
                }

                Section {
                    HStack {
                        Label("Body Fat", systemImage: "figure.arms.open")
                        Spacer()
                        TextField(lastBodyFat.map { String(format: "%.1f", $0) } ?? "—", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("%").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("BMI", systemImage: "heart.text.clipboard")
                        Spacer()
                        TextField(lastBMI.map { String(format: "%.1f", $0) } ?? "—", text: $bmiText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Label("Water", systemImage: "drop")
                        Spacer()
                        TextField(lastWater.map { String(format: "%.1f", $0) } ?? "—", text: $waterText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("%").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Body Composition")
                } footer: {
                    Text("Enter any values you have. Leave blank to skip.")
                }

                Section("Date") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Log Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let weight = Double(weightText)
                        let bf = Double(bodyFatText)
                        let bmi = Double(bmiText)
                        let water = Double(waterText)
                        guard weight != nil || bf != nil || bmi != nil || water != nil else { return }
                        onSave(weight, bf, bmi, water, selectedDate)
                        dismiss()
                    }
                    .disabled(weightText.isEmpty && bodyFatText.isEmpty && bmiText.isEmpty && waterText.isEmpty)
                }
            }
        }
    }
}
