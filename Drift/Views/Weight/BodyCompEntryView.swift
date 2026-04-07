import SwiftUI

/// Standalone entry view for body composition (fat %, BMI, water %).
struct BodyCompEntryView: View {
    let onSave: (Double?, Double?, Double?, Date) -> Void  // bodyFat, bmi, water, date
    var lastBodyFat: Double? = nil
    var lastBMI: Double? = nil
    var lastWater: Double? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var bodyFatText = ""
    @State private var bmiText = ""
    @State private var waterText = ""
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            Form {
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
                        Label("BMI", systemImage: "scalemass")
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
            .navigationTitle("Log Body Composition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let bf = Double(bodyFatText)
                        let bmi = Double(bmiText)
                        let water = Double(waterText)
                        guard bf != nil || bmi != nil || water != nil else { return }
                        onSave(bf, bmi, water, selectedDate)
                        dismiss()
                    }
                    .disabled(bodyFatText.isEmpty && bmiText.isEmpty && waterText.isEmpty)
                }
            }
        }
    }
}
