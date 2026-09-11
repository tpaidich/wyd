import SwiftUI

struct DrinkInfoView: View {
    var body: some View {
        List {
            ForEach(DrinkKind.allCases) { kind in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: kind.symbol)
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text(kind.label)
                            .font(.app(.headline))
                        Spacer()
                        Text(effectLabel(for: kind))
                            .font(.app(.subheadline, weight: .medium))
                            .foregroundStyle(isNegative(kind) ? Brand.flame : Brand.inkSoft)
                    }
                    Text(kind.rationale)
                        .font(.app(.footnote))
                        .foregroundStyle(Brand.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
            }
        } 
        .wydForm()
        .navigationTitle("How drinks count")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Text("Rough guides, not medical advice. Individual needs vary.")
                .font(.app(.caption2))
                .foregroundStyle(Brand.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.bar)
        }
    }

    private func net(for kind: DrinkKind) -> Int {
        kind.hydrationML(forVolume: kind.defaultVolumeML)
    }

    private func isNegative(_ kind: DrinkKind) -> Bool { net(for: kind) < 0 }

    private func effectLabel(for kind: DrinkKind) -> String {
        switch kind.effect {
        case .multiplier(let factor):
            if factor == 1 { return "Counts fully" }
            return "Counts \(Int((factor * 100).rounded()))%"
        case .volumeMinusLoss:
            let value = net(for: kind)
            return value < 0
                ? "Minus \(Volume.label(abs(value)))"
                : "Nets \(Volume.label(value))"
        }
    }
}
