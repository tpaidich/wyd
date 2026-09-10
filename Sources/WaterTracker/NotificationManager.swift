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

    /// A different nudge for each hour, so six reminders a day never read as
    /// the same alert repeating. Each one is written for what that hour
    /// actually feels like.
    private static func message(forHour hour: Int) -> (title: String, body: String) {
        switch hour {
        case 0...4:   return ("Still up?", "A glass now saves you a headache later.")
        case 5:       return ("Early start", "Water before coffee. Your body has gone eight hours without.")
        case 6:       return ("Morning", "You woke up dehydrated. Everyone does. Fix it first.")
        case 7:       return ("Before the day starts", "One glass now is the easiest one you'll drink today.")
        case 8:       return ("Coffee o'clock", "Have it. Just put a glass of water next to it.")
        case 9:       return ("Mid-morning", "Refill the bottle while you're thinking about it.")
        case 10:      return ("Halfway to lunch", "Good time for a top-up.")
        case 11:      return ("Late morning", "Aim to be a third of the way there by noon.")
        case 12:      return ("Lunch", "Drink something with it, not just after it.")
        case 13:      return ("Post-lunch dip", "That heavy feeling is often thirst wearing a disguise.")
        case 14:      return ("Afternoon", "The 3pm slump starts here. Water helps more than another coffee.")
        case 15:      return ("Slump hour", "Before you reach for caffeine, try a glass.")
        case 16:      return ("Late afternoon", "Two thirds of the day gone. How's the bottle looking?")
        case 17:      return ("Winding down", "Catch up now so you're not chugging at bedtime.")
        case 18:      return ("Evening", "Dinner's coming. Get a glass in beforehand.")
        case 19:      return ("After dinner", "A steady sip beats a big glass right before bed.")
        case 20:      return ("Settling in", "Last comfortable window before it costs you sleep.")
        case 21:      return ("Nearly there", "Close the gap now rather than at midnight.")
        case 22:      return ("Winding up", "Small glass. Big glass this late means a 3am trip.")
        default:      return ("Late", "Just a sip if you need it. Tomorrow starts fresh.")
        }
    }

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

        for hour in hours {
            let copy = Self.message(forHour: hour)
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
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
