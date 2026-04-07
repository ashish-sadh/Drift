import SwiftUI

struct WeightEntryView: View {
    let unit: WeightUnit
    let onSave: (Double, Date, Double?, Double?, Double?) -> Void  // weight, date, bodyFat, bmi, water

    @Environment(\.dismiss) private var dismiss
    @State private var weightText = ""
    @State private var selectedDate = Date()
    @State private var bodyFatText = ""
    @State private var bmiText = ""
    @State private var waterText = ""
    @State private var showBodyComp = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight") {
                    HStack {
                        TextField("0.0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .font(.title.monospacedDigit())
                        Text(unit.displayName)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Date") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }

                Section {
                    DisclosureGroup("Body Composition (Optional)", isExpanded: $showBodyComp) {
                        HStack {
                            Text("Body Fat")
                            Spacer()
                            TextField("—", text: $bodyFatText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("%").foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("BMI")
                            Spacer()
                            TextField("—", text: $bmiText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Water")
                            Spacer()
                            TextField("—", text: $waterText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("%").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let value = Double(weightText), value > 0 {
                            let bodyFat = Double(bodyFatText)
                            let bmi = Double(bmiText)
                            let water = Double(waterText)
                            onSave(value, selectedDate, bodyFat, bmi, water)
                            dismiss()
                        }
                    }
                    .disabled((Double(weightText) ?? 0) <= 0)
                }
            }
        }
    }
}
