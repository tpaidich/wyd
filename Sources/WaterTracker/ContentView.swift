import SwiftUI

struct ContentView: View {
    @StateObject private var store = WaterStore()
    @StateObject private var notifications = NotificationManager()
    @StateObject private var weather = WeatherService()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingMoreDrinks = false
    @State private var surge: Double = 0

    // The ring and its numeral scale with Dynamic Type instead of staying fixed.
    @ScaledMetric(relativeTo: .largeTitle) private var ringDiameter: CGFloat = 220
    @ScaledMetric(relativeTo: .largeTitle) private var countFontSize: CGFloat = 52


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                streakBanner

                ZStack {
                    WaveFillCircle(progress: store.progress, diameter: ringDiameter, surge: surge)

                    RippleOverlay(trigger: store.intakeML)
                        .frame(width: ringDiameter, height: ringDiameter)

                    VStack(spacing: 2) {
                        Text(Glass.format(store.intakeML))
                            .font(.display(countFontSize, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.snappy, value: store.intakeML)
                            .foregroundStyle(waterlineColor(offset: 0))
                        Text("of \(Glass.format(store.goalML)) glasses")
                            .font(.subheadline)
                            .foregroundStyle(waterlineColor(offset: 30, dimmed: true))
                        Text("\(Volume.format(store.intakeML)) / \(Volume.label(store.goalML))")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(waterlineColor(offset: 54, dimmed: true))
                            .padding(.top, 4)
                    }
                    .shadow(color: .black.opacity(0.14), radius: 4)
                    .animation(.easeOut(duration: 0.4), value: store.progress)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                }

                Text(progressMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let note = weatherNote {
                    Label(note, systemImage: "thermometer.sun.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                }

                VStack(spacing: 16) {
                    bottleCard

                    HStack(spacing: 12) {
                        ForEach(DrinkKind.primary) { kind in
                            Button {
                                store.log(kind)
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: kind.symbol)
                                        .font(.title2)
                                    Text(kind.label)
                                        .font(.subheadline.weight(.semibold))
                                    Text(Volume.label(store.volumeML(for: kind)))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }

                    Button {
                        showingMoreDrinks = true
                    } label: {
                        Label("More drinks", systemImage: "ellipsis.circle")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)

                // Side by side normally; stacked once large text sizes make them overflow.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { correctionButtons }
                    VStack(spacing: 12) { correctionButtons }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Wyd")
                        .font(.display(.headline))
                }

                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView(store: store)
                    } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(store: store, notifications: notifications, weather: weather)
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showingMoreDrinks) {
            MoreDrinksView(store: store)
        }
        .task {
            await notifications.reschedule()
            weather.refreshIfStale()
        }
        .onChange(of: store.intakeML) { _, _ in
            // The splash builds fast and settles slowly, the way water does.
            withAnimation(.easeOut(duration: 0.18)) { surge = 1 }
            withAnimation(.easeInOut(duration: 1.5).delay(0.18)) { surge = 0 }
        }
        .onChange(of: weather.conditions) { _, conditions in
            store.weatherBonusML = conditions?.extraML ?? 0
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshDay()
                weather.refreshIfStale()
            }
        }
    }

    @ViewBuilder
    private var correctionButtons: some View {
        Button(undoLabel) {
            store.undoLast()
        }
        .buttonStyle(.bordered)
        .disabled(store.lastDrink == nil)

        Button("Reset Today", role: .destructive) {
            store.reset()
        }
        .buttonStyle(.bordered)
        .disabled(store.intakeML == 0)
    }

    private var streakBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: store.currentStreak > 0 ? "flame.fill" : "flame")
                .foregroundStyle(store.currentStreak > 0 ? .orange : .secondary)
            Text(streakMessage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(store.currentStreak > 0 ? .primary : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(store.currentStreak > 0 ? Color.orange.opacity(0.12) : Color.gray.opacity(0.12))
        )
    }

    private var streakMessage: String {
        switch store.currentStreak {
        case 0: return "No streak yet — hit your goal today"
        case 1: return "1 day streak"
        default: return "\(store.currentStreak) day streak"
        }
    }

    /// Each line of the readout sits at a different height, so each one crosses
    /// the waterline at its own moment. One shared threshold left the smaller
    /// lines dark while they were already underwater.
    private func waterlineColor(offset: CGFloat, dimmed: Bool = false) -> Color {
        let threshold = 1 - (0.5 + offset / max(ringDiameter, 1))
        let submerged = store.progress > threshold
        if submerged { return .white.opacity(dimmed ? 0.85 : 1) }
        return dimmed ? Color.secondary : Color.primary
    }

    /// The bottle people actually sip from, logged in fractions.
    private var bottleCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Your bottle", systemImage: "waterbottle.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(Volume.label(store.bottleSizeML))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(BottlePour.allCases) { pour in
                    Button {
                        store.logBottle(pour.fraction)
                    } label: {
                        VStack(spacing: 3) {
                            Text(pour.label)
                                .font(.headline)
                            Text(Volume.label(Int(Double(store.bottleSizeML) * pour.fraction)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.cyan.opacity(0.14))
                        .foregroundStyle(.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }

            Text(bottleSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.teal.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var bottleSummary: String {
        let glasses = Glass.format(store.bottleSizeML)
        let bottles = String(format: "%.1f", store.goalInBottles)
        return "A full bottle is \(glasses) glasses. Today's goal is about \(bottles) bottles."
    }

    private var undoLabel: String {
        guard let last = store.lastDrink else { return "Undo" }
        return "Undo \(last.kind.label.lowercased())"
    }

    private var weatherNote: String? {
        guard store.useAutoGoal,
              let conditions = weather.conditions,
              conditions.extraML > 0 else { return nil }
        return "\(conditions.city) feels like \(conditions.heatIndexF)°F — goal raised \(Volume.label(conditions.extraML))"
    }

    private var progressMessage: String {
        if store.intakeML == 0 {
            return "Nothing logged yet. Tap what you drank."
        } else if store.progress >= 1.0 {
            return "Goal reached! Great job staying hydrated today."
        } else {
            return "About \(Glass.format(store.remainingML)) more glasses to go."
        }
    }
}

#Preview {
    ContentView()
}
