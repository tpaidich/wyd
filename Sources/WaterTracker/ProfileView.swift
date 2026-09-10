import SwiftUI

struct ProfileView: View {
    @ObservedObject var store: WaterStore

    var body: some View {
        Form {
            Section("Body") {
                LabeledStepper(
                    label: "Weight",
                    value: Binding(
                        get: { BodyUnits.pounds(store.profile.weightKG).rounded() },
                        set: { store.profile.weightKG = BodyUnits.kilograms($0) }
                    ),
                    range: 66...440,
                    step: 1,
                    format: { "\(Int($0)) lb" }
                )

                LabeledStepper(
                    label: "Height",
                    value: Binding(
                        get: { BodyUnits.inches(store.profile.heightCM).rounded() },
                        set: { store.profile.heightCM = BodyUnits.centimetres($0) }
                    ),
                    range: 47...87,
                    step: 1,
                    format: { BodyUnits.heightLabel(inches: $0) }
                )

                Stepper(value: $store.profile.age, in: 10...100) {
                    HStack {
                        Text("Age")
                        Spacer()
                        Text("\(store.profile.age)")
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Sex", selection: $store.profile.sex) {
                    ForEach(BiologicalSex.allCases) { sex in
                        Text(sex.label).tag(sex)
                    }
                }
            }

            Section {
                Picker("Activity", selection: $store.profile.activity) {
                    ForEach(ActivityLevel.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)

                Text(store.profile.activity.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Activity")
            }

            Section {
                HStack {
                    Text("Body baseline")
                    Spacer()
                    Text(Volume.label(store.profile.baseGoalML))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("BMI")
                    Spacer()
                    Text(String(format: "%.1f", store.profile.bmi))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Result")
            } footer: {
                Text("A general wellness estimate from body weight, age, sex and activity — not medical advice. Ask a doctor if you have a condition that affects fluid intake.")
            }
        }
        .wydForm()
        .navigationTitle("Your Body")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A stepper whose value is a Double but reads as a formatted measurement.
private struct LabeledStepper: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack {
                Text(label)
                Spacer()
                Text(format(value))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
