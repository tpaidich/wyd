import SwiftUI

/// Chooses which three drinks sit on the home screen.
struct QuickDrinksView: View {
    @ObservedObject var store: WaterStore

    var body: some View {
        List {
            Section {
                ForEach(store.quickDrinks) { kind in
                    row(for: kind)
                }
                .onMove { source, destination in
                    store.reorderQuickDrinks(from: source, to: destination)
                }
            } header: {
                Text("On the home screen")
            } footer: {
                Text("Drag to reorder. Choosing a fourth replaces whichever you picked longest ago.")
                    .foregroundStyle(Brand.inkSoft)
            }
            .listRowBackground(Brand.rowFill)

            ForEach(DrinkCategory.allCases) { category in
                let drinks = DrinkKind.allCases.filter {
                    $0.category == category && !store.isQuickDrink($0)
                }
                if !drinks.isEmpty {
                    Section(category.label) {
                        ForEach(drinks) { kind in
                            row(for: kind)
                        }
                    }
                    .listRowBackground(Brand.rowFill)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .wydForm()
        .navigationTitle("Quick drinks")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for kind: DrinkKind) -> some View {
        Button {
            store.toggleQuickDrink(kind)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kind.symbol)
                    .foregroundStyle(Brand.ink)
                    .frame(width: 24)
                Text(kind.label)
                    .foregroundStyle(.primary)
                Spacer()
                if store.isQuickDrink(kind) {
                    Image(systemName: "checkmark")
                        .font(.app(.subheadline, weight: .semibold))
                        .foregroundStyle(Brand.ink)
                }
            }
        }
    }
}
