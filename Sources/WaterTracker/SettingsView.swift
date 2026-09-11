import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: WaterStore
    @ObservedObject var notifications: NotificationManager
    @ObservedObject var weather: WeatherService

    @State private var goalInput: Double
    @State private var showingDeniedAlert = false

    init(store: WaterStore, notifications: NotificationManager, weather: WeatherService) {
        self.store = store
        self.notifications = notifications
        self.weather = weather
        _goalInput = State(initialValue: Volume.oz(store.manualGoalML).rounded())
    }

    var body: some View {
        Form {
            Section {
                Image("SettingsHeader")
                    .renderable()
                    .frame(maxWidth: 140)
                    .foregroundStyle(Brand.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.top, -10)
                    .accessibilityLabel("Settings")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            // The wordmark is a title, not a group of settings, so it does not
            // need the gap a Form puts between two sections.
            .listSectionSpacing(6)

            Section {
                Toggle("Automatic goal", isOn: $store.useAutoGoal)

                if store.useAutoGoal {
                    NavigationLink {
                        ProfileView(store: store)
                    } label: {
                        HStack {
                            Text("Your body")
                            Spacer()
                            Text(Volume.label(store.profile.baseGoalML))
                                .foregroundStyle(Brand.inkSoft)
                        }
                    }

                    HStack {
                        Text("Heat allowance")
                        Spacer()
                        Text(weatherBonusText)
                            .foregroundStyle(Brand.inkSoft)
                    }

                    HStack {
                        Text("Today's goal")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(Volume.label(store.goalML))
                            .fontWeight(.semibold)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(Int(goalInput)) oz")
                                .font(.app(.title3, weight: .semibold))
                            Spacer()
                            Text(glassesText)
                                .font(.app(.subheadline))
                                .foregroundStyle(Brand.inkSoft)
                        }
                        // Whole ounces, stepping by half a glass.
                        Slider(value: $goalInput, in: 16...170, step: 4) { editing in
                            if !editing {
                                store.setGoal(Int((goalInput * Volume.mlPerOz).rounded()))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Daily goal")
                    .foregroundStyle(Brand.inkSoft)
            } footer: {
                if store.useAutoGoal {
                    Text("Calculated from your body metrics, then topped up when it is hot or humid where you are.")
                        .foregroundStyle(Brand.inkSoft)
                }
            }
            .listRowBackground(Brand.rowFill)

            Section {
                if weather.authorizationDenied {
                    Text("Location is off, so the heat allowance stays at 0 ml. Enable location for Wyd in the Settings app.")
                        .font(.app(.footnote))
                        .foregroundStyle(Brand.inkSoft)
                } else if let conditions = weather.conditions {
                    HStack {
                        Text(conditions.city)
                        Spacer()
                        Text(conditions.summary)
                            .foregroundStyle(Brand.inkSoft)
                            .multilineTextAlignment(.trailing)
                    }
                    if conditions.isHeatwave {
                        Label("Extreme heat. Drink more than usual.", systemImage: "thermometer.sun.fill")
                            .font(.app(.footnote))
                            .foregroundStyle(Brand.flame)
                    }
                } else if weather.isLoading {
                    HStack {
                        ProgressView()
                        Text("Checking local conditions…")
                            .foregroundStyle(Brand.inkSoft)
                    }
                } else {
                    Button("Use my location") { weather.refresh() }
                }

                if let errorMessage = weather.errorMessage {
                    Text(errorMessage)
                        .font(.app(.footnote))
                        .foregroundStyle(Brand.inkSoft)
                }
            } header: {
                Text("Weather")
                    .foregroundStyle(Brand.inkSoft)
            }
            .listRowBackground(Brand.rowFill)

            Section {
                NavigationLink {
                    QuickDrinksView(store: store)
                } label: {
                    Text("Quick drinks")
                }

                NavigationLink {
                    DrinkSizesView(store: store)
                } label: {
                    Text("Drink sizes")
                }

                NavigationLink {
                    DrinkInfoView()
                } label: {
                    Text("How drinks count")
                }
            } header: {
                Text("Drinks")
                    .foregroundStyle(Brand.inkSoft)
            }
            .listRowBackground(Brand.rowFill)

            Section {
                Toggle("Reminders", isOn: $notifications.remindersEnabled)

                if notifications.remindersEnabled {
                    Stepper(
                        "\(notifications.remindersPerDay) per day",
                        value: $notifications.remindersPerDay,
                        in: 1...12
                    )

                    Picker("Start", selection: $notifications.startHour) {
                        ForEach(Array(5..<22), id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }

                    Picker("End", selection: $notifications.endHour) {
                        ForEach(Array((notifications.startHour + 1)..<24), id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }
                }
            } header: {
                Text("Reminders")
                    .foregroundStyle(Brand.inkSoft)
            } footer: {
                if notifications.remindersEnabled {
                    Text("Reminders at \(scheduleSummary).")
                        .foregroundStyle(Brand.inkSoft)
                } else {
                    Text("Get nudged through the day to keep drinking water.")
                        .foregroundStyle(Brand.inkSoft)
                }
            }
            .listRowBackground(Brand.rowFill)
        }
        .wydForm()
        // A Form opens with a wide top inset meant for a navigation title.
        // The wordmark is the title here, so that space is dead.
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: notifications.remindersEnabled) { _, enabled in
            guard enabled else {
                Task { await notifications.reschedule() }
                return
            }
            Task {
                // Flip the toggle back if the user refuses at the system prompt.
                guard await notifications.ensureAuthorized() else {
                    await MainActor.run {
                        notifications.remindersEnabled = false
                        showingDeniedAlert = true
                    }
                    return
                }
                await notifications.reschedule()
            }
        }
        .onChange(of: notifications.remindersPerDay) { _, _ in
            Task { await notifications.reschedule() }
        }
        .onChange(of: notifications.startHour) { _, _ in
            Task { await notifications.reschedule() }
        }
        .onChange(of: notifications.endHour) { _, _ in
            Task { await notifications.reschedule() }
        }
        .alert("Notifications are off", isPresented: $showingDeniedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable notifications for Wyd in the Settings app to get reminders.")
        }
    }

    private var weatherBonusText: String {
        guard let conditions = weather.conditions else { return "Not set" }
        return conditions.extraML == 0 ? "none needed" : "+\(Volume.label(conditions.extraML))"
    }

    private var glassesText: String {
        let millilitres = Int((goalInput * Volume.mlPerOz).rounded())
        return "≈ \(Glass.format(millilitres)) glasses"
    }

    private var scheduleSummary: String {
        notifications.reminderHours().map(hourLabel).joined(separator: ", ")
    }

    private func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()

        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }
}
