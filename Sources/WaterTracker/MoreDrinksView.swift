import SwiftUI

/// How much of your own bottle you just drank.
enum BottlePour: String, CaseIterable, Identifiable {
    case quarter
    case half
    case threeQuarters
    case full

    var id: String { rawValue }

    var fraction: Double {
        switch self {
        case .quarter: return 0.25
        case .half: return 0.5
        case .threeQuarters: return 0.75
        case .full: return 1.0
        }
    }

    var label: String {
        switch self {
        case .quarter: return "¼"
        case .half: return "½"
        case .threeQuarters: return "¾"
        case .full: return "Full"
        }
    }
}

struct MoreDrinksView: View {
    @ObservedObject var store: WaterStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(DrinkCategory.allCases) { category in
                    let drinks = DrinkKind.inCategory(category)
                    if !drinks.isEmpty {
                        Section(category.label) {
                            ForEach(drinks) { kind in
                                Button {
                                    store.log(kind)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: kind.symbol)
                                            .foregroundStyle(.blue)
                                            .frame(width: 26)
                                        Text(kind.label)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text(effectLabel(for: kind))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("More drinks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Shows the size, plus the net effect when a drink can move you backwards.
    private func effectLabel(for kind: DrinkKind) -> String {
        let volume = store.volumeML(for: kind)
        let net = kind.hydrationML(forVolume: volume)
        guard net < 0 else { return Volume.label(volume) }
        return "\(Volume.label(volume))  -\(Volume.label(abs(net)))"
    }
}
