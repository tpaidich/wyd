import SwiftUI

struct ContentView: View {
    @StateObject private var store = WaterStore()
    @StateObject private var notifications = NotificationManager()
    @StateObject private var weather = WeatherService()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingMoreDrinks = false
    @State private var showingQuickPicker = false
    @State private var surge: Double = 0

    // The ring and its numeral scale with Dynamic Type instead of staying fixed.
    @ScaledMetric(relativeTo: .largeTitle) private var ringDiameter: CGFloat = 202
    @ScaledMetric(relativeTo: .largeTitle) private var countFontSize: CGFloat = 48


    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                VStack(spacing: 14) {
                Image("WydHeader")
                    .renderable()
                    .frame(maxWidth: 92)
                    .foregroundStyle(Brand.ink)
                    .padding(.top, -8)
                    .accessibilityLabel("Wyd, what're you drinking")

                streakBanner

                ZStack {
                    WaveFillCircle(progress: store.progress, diameter: ringDiameter, surge: surge)
                        // A plain contact shadow, cast by the same light that
                        // shades the orb. No colour, so nothing glows.
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 3, y: 8)

                    RippleOverlay(trigger: store.intakeML)
                        .frame(width: ringDiameter, height: ringDiameter)

                    orbReadout
                        .animation(.easeOut(duration: 0.4), value: store.progress)
                }
                // The glass is the focal point, so it gets room to breathe.
                .padding(.vertical, 20)

                Text(progressMessage)
                    .font(.app(.callout))
                    .foregroundStyle(Brand.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let note = weatherNote {
                    Label(note, systemImage: "thermometer.sun.fill")
                        .font(.app(.footnote))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                }

                VStack(spacing: 11) {
                    bottleCard

                    HStack(spacing: 10) {
                        ForEach(store.quickDrinks) { kind in
                            Button {
                                store.log(kind)
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: kind.symbol)
                                        .font(.app(.footnote, weight: .semibold))
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(kind.label)
                                            .font(.app(.footnote, weight: .semibold))
                                            .lineLimit(1)
                                        Text(Volume.label(store.volumeML(for: kind)))
                                            .font(.app(.caption2))
                                            .opacity(0.75)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .foregroundStyle(Brand.cream)
                                .background(
                                    RoundedRectangle(cornerRadius: 13).fill(Brand.cobalt)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    showingQuickPicker = true
                                } label: {
                                    Label("Change quick drinks", systemImage: "slider.horizontal.3")
                                }
                            }
                        }
                    }

                    Button {
                        showingMoreDrinks = true
                    } label: {
                        Label("More drinks", systemImage: "ellipsis.circle")
                            .font(.app(.subheadline, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)

                }
                // Fills the viewport, so what follows starts below the fold.
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.top, 0)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)

                // Corrections live past the fold: a deliberate reach, not
                // something to hit by accident while logging.
                VStack(spacing: 10) {
                    Text("Fix a mistake")
                        .font(.app(.caption))
                        .foregroundStyle(Brand.inkSoft)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { correctionButtons }
                        VStack(spacing: 12) { correctionButtons }
                    }
                }
                .padding(.top, 26)
                .padding(.bottom, 34)
                .padding(.horizontal, 24)
                }
            }
            }
            .background(Brand.ground)
            .tint(Brand.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

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
        .sheet(isPresented: $showingQuickPicker) {
            NavigationStack { QuickDrinksView(store: store) }
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
        // The palette is two flat colours, but a destructive action still has
        // to look destructive. This is the one sanctioned exception.
        .tint(.red)
        .disabled(store.intakeML == 0)
    }

    private var streakBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: store.currentStreak > 0 ? "flame.fill" : "flame")
                .foregroundStyle(store.currentStreak > 0 ? Brand.flame : Brand.inkSoft)
            Text(streakMessage)
                .font(.app(.subheadline, weight: .medium))
                .foregroundStyle(store.currentStreak > 0 ? .primary : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(store.currentStreak > 0 ? Brand.flame.opacity(0.14) : Brand.cobalt.opacity(0.06))
        )
    }

    private var streakMessage: String {
        switch store.currentStreak {
        case 0: return "No streak yet — hit your goal today"
        case 1: return "1 day streak"
        default: return "\(store.currentStreak) day streak"
        }
    }

    /// The readout is cut by the waterline itself: ink where it sits in the air,
    /// cream where it sits in the water. Flipping the whole readout at one
    /// threshold always left it washed out for the stretch where the water was
    /// crossing the digits.
    private var orbReadout: some View {
        ZStack {
            readoutText(color: Brand.ink)

            readoutText(color: Brand.cream)
                .mask(
                    VStack(spacing: 0) {
                        Color.clear
                        Color.black
                            .frame(height: ringDiameter * CGFloat(min(max(store.progress, 0), 1)))
                    }
                    .frame(height: ringDiameter)
                )
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func readoutText(color: Color) -> some View {
        VStack(spacing: 2) {
            Text(Volume.format(store.intakeML))
                .font(.display(countFontSize, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: store.intakeML)
            Text("of \(Volume.label(store.goalML))")
                .font(.app(.subheadline))
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }

    /// The bottle people actually sip from, logged in fractions.
    ///
    /// Each button shows the level it represents, so the row reads as one
    /// bottle filling rather than four interchangeable chips.
    private var bottleCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Your bottle", systemImage: "waterbottle.fill")
                    .font(.app(.subheadline, weight: .semibold))
                    .foregroundStyle(Brand.ink)
                Spacer()
                Text(Volume.label(store.bottleSizeML))
                    .font(.app(.subheadline))
                    .foregroundStyle(Brand.inkSoft)
            }

            HStack(spacing: 9) {
                ForEach(BottlePour.allCases) { pour in
                    Button {
                        store.logBottle(pour.fraction)
                    } label: {
                        VStack(spacing: 5) {
                            // A miniature bottle, filled to this fraction.
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Brand.cobalt.opacity(0.16))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Brand.cobalt)
                                    .frame(height: 26 * pour.fraction)
                            }
                            .frame(width: 17, height: 26)

                            Text(pour.label)
                                .font(.app(.subheadline, weight: .semibold))
                            Text(Volume.label(Int(Double(store.bottleSizeML) * pour.fraction)))
                                .font(.app(.caption2))
                                .foregroundStyle(Brand.inkSoft)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(Brand.ink)
                        .background(
                            RoundedRectangle(cornerRadius: 13)
                                .fill(Brand.ground)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(bottleSummary)
                .font(.app(.caption2))
                .foregroundStyle(Brand.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20).fill(Brand.cobalt.opacity(0.07))
        )
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
            return "\(Volume.label(store.remainingML)) to go, about \(Glass.format(store.remainingML)) glasses."
        }
    }
}

#Preview {
    ContentView()
}
