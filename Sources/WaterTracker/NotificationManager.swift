import Foundation
import UserNotifications

/// Deliberately not `@MainActor`-isolated: SwiftUI's `ObservedObject` binding
/// setter needs to write these properties synchronously, and class-wide
/// isolation makes `$notifications.remindersEnabled` a no-op from a Toggle.
final class NotificationManager: ObservableObject {
    @Published var remindersEnabled: Bool {
        didSet { defaults.set(remindersEnabled, forKey: enabledKey) }
    }
    @Published var startHour: Int {
        didSet {
            defaults.set(startHour, forKey: startKey)
            // Keep the window valid when the start is pushed past the end.
            if endHour <= startHour {
                endHour = min(startHour + 1, 23)
            }
        }
    }
    @Published var endHour: Int {
        didSet { defaults.set(endHour, forKey: endKey) }
    }
    @Published var remindersPerDay: Int {
        didSet { defaults.set(remindersPerDay, forKey: countKey) }
    }

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let enabledKey = "remindersEnabled"
    private let startKey = "reminderStartHour"
    private let endKey = "reminderEndHour"
    private let countKey = "remindersPerDay"

    private let messages = [
        "Time for a glass of water 💧",
        "Hydration check — grab a drink!",
        "Your body called. It wants water 🚰",
        "Quick sip break?",
        "Stay hydrated — log some water 💧"
    ]

    init() {
        remindersEnabled = defaults.bool(forKey: enabledKey)
        startHour = defaults.object(forKey: startKey) as? Int ?? 9
        endHour = defaults.object(forKey: endKey) as? Int ?? 21
        remindersPerDay = defaults.object(forKey: countKey) as? Int ?? 6
    }

    /// Returns true when the app may post notifications, prompting the user if
    /// they have not been asked yet.
    func ensureAuthorized() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        }
    }

    /// Spreads `remindersPerDay` repeating daily notifications across the active window.
    func reschedule() async {
        center.removeAllPendingNotificationRequests()

        let (enabled, hours) = await MainActor.run {
            (self.remindersEnabled, self.reminderHours())
        }
        guard enabled else { return }

        for (index, hour) in hours.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Wyd"
            content.body = messages[index % messages.count]
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = 0

            let request = UNNotificationRequest(
                identifier: "water-reminder-\(hour)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            try? await center.add(request)
        }
    }

    /// Evenly spaced hours between start and end, inclusive of both ends.
    func reminderHours() -> [Int] {
        guard endHour > startHour, remindersPerDay > 0 else { return [startHour] }
        guard remindersPerDay > 1 else { return [startHour] }

        let step = Double(endHour - startHour) / Double(remindersPerDay - 1)
        var hours: [Int] = []
        for index in 0..<remindersPerDay {
            let hour = Int((Double(startHour) + step * Double(index)).rounded())
            if !hours.contains(hour) {
                hours.append(hour)
            }
        }
        return hours
    }
}
