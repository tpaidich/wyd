import SwiftUI

/// Lets people correct any size that does not match what they actually drink.
struct DrinkSizesView: View {
    @ObservedObject var store: WaterStore

    var body: some View {
        Form {
            Section {
                Stepper(value: bottleBinding, in: 8...128, step: 2) {
                    HStack {
                        Text("Bottle")
                        Spacer()
                        Text("\(Int(Volume.oz(store.bottleSizeML).rounded())) oz")
                            .foregroundStyle(Brand.inkSoft)
                    }
                }
            } header: {
                Text("Your bottle")
            } footer: {
                Text("A full bottle is \(Glass.format(store.bottleSizeML)) glasses.")
                    .foregroundStyle(Brand.inkSoft)
            }
            .listRowBackground(Brand.rowFill)

            ForEach(DrinkCategory.allCases) { category in
                Section(category.label) {
                    ForEach(DrinkKind.allCases.filter { $0.category == category }) { kind in
                        Stepper(value: binding(for: kind), in: 1...68, step: 1) {
                            HStack {
                                Text(kind.label)
                                Spacer()
                                Text("\(Int(Volume.oz(store.volumeML(for: kind)).rounded())) oz")
                                    .foregroundStyle(Brand.inkSoft)
                            }
                        }
                    }
                }
                .listRowBackground(Brand.rowFill)
            }
        }
        .wydForm()
        .navigationTitle("Drink sizes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bottleBinding: Binding<Double> {
        Binding(
            get: { Volume.oz(store.bottleSizeML).rounded() },
            set: { store.bottleSizeML = Volume.ml(fromOz: $0) }
        )
    }

    private func binding(for kind: DrinkKind) -> Binding<Double> {
        Binding(
            get: { Volume.oz(store.volumeML(for: kind)).rounded() },
            set: { store.setVolume(Volume.ml(fromOz: $0), for: kind) }
        )
    }
}
