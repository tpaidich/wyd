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
                Toggle("Automatic goal", isOn: $store.useAutoGoal)

                if store.useAutoGoal {
                    NavigationLink {
                        ProfileView(store: store)
                    } label: {
                        HStack {
                            Text("Your body")
                            Spacer()
                            Text(Volume.label(store.profile.baseGoalML))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Heat allowance")
                        Spacer()
                        Text(weatherBonusText)
                            .foregroundStyle(.secondary)
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
                                .font(.title3.weight(.semibold))
                            Spacer()
                            Text(glassesText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
            } footer: {
                if store.useAutoGoal {
                    Text("Calculated from your body metrics, then topped up when it is hot or humid where you are.")
                }
            }

            Section {
                if weather.authorizationDenied {
                    Text("Location is off, so the heat allowance stays at 0 ml. Enable location for Wyd in the Settings app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let conditions = weather.conditions {
                    HStack {
                        Text(conditions.city)
                        Spacer()
                        Text(conditions.summary)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    if conditions.isHeatwave {
                        Label("Extreme heat — drink more than usual", systemImage: "thermometer.sun.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } else if weather.isLoading {
                    HStack {
                        ProgressView()
                        Text("Checking local conditions…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button("Use my location") { weather.refresh() }
                }

                if let errorMessage = weather.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Weather")
            }

            Section {
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
            }

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
            } footer: {
                if notifications.remindersEnabled {
                    Text("Reminders at \(scheduleSummary).")
                } else {
                    Text("Get nudged through the day to keep drinking water.")
                }
            }
        }
        .navigationTitle("Settings")
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
        guard let conditions = weather.conditions else { return "—" }
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
