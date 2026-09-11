import SwiftUI

/// What a single day actually looked like. This replaces the long "all days"
/// list: the calendar carries the overview, and the detail is one tap away.
struct DayDetailView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var detailCountSize: CGFloat = 40
    let dateKey: String
    let record: DayRecord?
    let goalML: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Glass.format(intake))
                            .font(.display(detailCountSize, weight: .bold))
                            .monospacedDigit()
                        Text("of \(Glass.format(goal)) glasses")
                            .font(.app(.subheadline))
                            .foregroundStyle(Brand.inkSoft)
                    }

                    ProgressView(value: min(progress, 1))
                        .tint(metGoal ? .blue : .cyan)

                    HStack {
                        Text(Volume.label(intake))
                            .font(.app(.subheadline))
                            .monospacedDigit()
                        Spacer()
                        if metGoal {
                            Label("Goal met", systemImage: "checkmark.circle.fill")
                                .font(.app(.subheadline))
                                .foregroundStyle(.blue)
                        } else if intake > 0 {
                            Text("\(Volume.label(max(0, goal - intake))) short")
                                .font(.app(.subheadline))
                                .foregroundStyle(Brand.inkSoft)
                        }
                    }
                }
                .listRowBackground(Brand.rowFill)

                Section("Drinks") {
                    if entries.isEmpty {
                        Text(intake > 0
                             ? "This day was logged before drinks were itemised."
                             : "Nothing logged on this day.")
                            .font(.app(.subheadline))
                            .foregroundStyle(Brand.inkSoft)
                    } else {
                        ForEach(entries.reversed()) { entry in
                            HStack(spacing: 12) {
                                Image(systemName: entry.kind.symbol)
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.kind.label)
                                    Text(entry.time, style: .time)
                                        .font(.app(.caption2))
                                        .foregroundStyle(Brand.inkSoft)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Volume.label(entry.volumeML))
                                        .monospacedDigit()
                                    if entry.hydrationML != entry.volumeML {
                                        Text("counts \(Volume.label(entry.hydrationML))")
                                            .font(.app(.caption2))
                                            .foregroundStyle(
                                                entry.hydrationML < 0 ? Brand.flame : Brand.inkSoft
                                            )
                                    }
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Brand.rowFill)
            }
            .wydForm()
            .navigationTitle(WaterStore.displayName(for: dateKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var intake: Int { record?.intakeML ?? 0 }
    private var goal: Int { record?.goalML ?? goalML }
    private var entries: [DrinkEntry] { record?.entries ?? [] }
    private var metGoal: Bool { record?.metGoal ?? false }
    private var progress: Double { goal > 0 ? Double(intake) / Double(goal) : 0 }
}
