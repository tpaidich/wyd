import SwiftUI

struct ProfileView: View {
    @ObservedObject var store: WaterStore

    /// Pounds and inches are what the wheels show; the profile stores metric.
    private var weightPounds: Binding<Int> {
        Binding(
            get: { Int(BodyUnits.pounds(store.profile.weightKG).rounded()) },
            set: { store.profile.weightKG = BodyUnits.kilograms(Double($0)) }
        )
    }

    private var heightInches: Binding<Int> {
        Binding(
            get: { Int(BodyUnits.inches(store.profile.heightCM).rounded()) },
            set: { store.profile.heightCM = BodyUnits.centimetres(Double($0)) }
        )
    }

    private func wheelCaption(_ text: String) -> some View {
        Text(text)
            .font(.app(.footnote))
            .foregroundStyle(Brand.inkSoft)
            .frame(maxWidth: .infinity)
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 2) {
                    HStack(spacing: 0) {
                        wheelCaption("Weight")
                        wheelCaption("Height")
                        wheelCaption("Age")
                    }

                    HStack(spacing: 0) {
                        Picker("Weight", selection: weightPounds) {
                            ForEach(Array(66...440), id: \.self) { pounds in
                                Text("\(pounds) lb").tag(pounds)
                            }
                        }
                        .wheelColumn()

                        Picker("Height", selection: heightInches) {
                            ForEach(Array(47...87), id: \.self) { inches in
                                Text(BodyUnits.heightLabel(inches: Double(inches))).tag(inches)
                            }
                        }
                        .wheelColumn()

                        Picker("Age", selection: $store.profile.age) {
                            ForEach(Array(10...100), id: \.self) { years in
                                Text("\(years)").tag(years)
                            }
                        }
                        .wheelColumn()
                    }
                    .frame(height: 150)
                }
                .padding(.vertical, 4)

                Picker("Sex", selection: $store.profile.sex) {
                    ForEach(BiologicalSex.allCases) { sex in
                        Text(sex.label).tag(sex)
                    }
                }
            } header: {
                Text("Body")
                    .foregroundStyle(Brand.inkSoft)
            }
            .listRowBackground(Brand.rowFill)

            Section {
                Picker("Activity", selection: $store.profile.activity) {
                    ForEach(ActivityLevel.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Activity")
                    .foregroundStyle(Brand.inkSoft)
            } footer: {
                Text(store.profile.activity.detail)
                    .foregroundStyle(Brand.inkSoft)
            }
            .listRowBackground(Brand.rowFill)

            Section {
                HStack {
                    Text("Body baseline")
                    Spacer()
                    Text(Volume.label(store.profile.baseGoalML))
                        .foregroundStyle(Brand.inkSoft)
                }
                HStack {
                    Text("BMI")
                    Spacer()
                    Text(String(format: "%.1f", store.profile.bmi))
                        .foregroundStyle(Brand.inkSoft)
                }
            } header: {
                Text("Result")
                    .foregroundStyle(Brand.inkSoft)
            } footer: {
                Text("A general wellness estimate from body weight, age, sex and activity — not medical advice. Ask a doctor if you have a condition that affects fluid intake.")
                    .foregroundStyle(Brand.inkSoft)
            }
            .listRowBackground(Brand.rowFill)
        }
        .wydForm()
        .navigationTitle("Your Body")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension View {
    /// One column of the three-up wheel. Wheels do not shrink on their own, so
    /// each is given an equal share of the row and clipped to it.
    func wheelColumn() -> some View {
        self.pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
    }
}
