import Foundation
import Combine

struct DayRecord: Codable, Identifiable {
    let date: String
    var intakeML: Int
    var goalML: Int
    var entries: [DrinkEntry]

    init(date: String, intakeML: Int, goalML: Int, entries: [DrinkEntry] = []) {
        self.date = date
        self.intakeML = intakeML
        self.goalML = goalML
        self.entries = entries
    }

    // Days logged before drinks were itemised decode with no entries.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        intakeML = try container.decode(Int.self, forKey: .intakeML)
        goalML = try container.decode(Int.self, forKey: .goalML)
        entries = try container.decodeIfPresent([DrinkEntry].self, forKey: .entries) ?? []
    }

    var id: String { date }

    /// Parsed calendar date, used as a chart axis value so distinct days never merge.
    var dateValue: Date { WaterStore.date(from: date) ?? Date() }

    var metGoal: Bool { goalML > 0 && intakeML >= goalML }

    var progress: Double {
        guard goalML > 0 else { return 0 }
        return min(Double(intakeML) / Double(goalML), 1.0)
    }
}

final class WaterStore: ObservableObject {
    @Published private(set) var history: [String: DayRecord] = [:]
    @Published private(set) var todayKey: String = WaterStore.key(for: Date())
    /// Body metrics the automatic goal is derived from.
    @Published var profile: UserProfile {
        didSet {
            if let data = try? JSONEncoder().encode(profile) {
                defaults.set(data, forKey: profileKey)
            }
            syncTodayGoal()
        }
    }

    /// When off, `manualGoalML` wins and body/weather inputs are ignored.
    @Published var useAutoGoal: Bool {
        didSet {
            defaults.set(useAutoGoal, forKey: autoGoalKey)
            syncTodayGoal()
        }
    }

    @Published var manualGoalML: Int {
        didSet {
            defaults.set(manualGoalML, forKey: goalKey)
            syncTodayGoal()
        }
    }

    /// Heat/humidity top-up for today, supplied by `WeatherService`.
    @Published var weatherBonusML: Int = 0 {
        didSet { syncTodayGoal() }
    }

    /// The bottle people refill and sip from all day.
    @Published var bottleSizeML: Int {
        didSet { defaults.set(bottleSizeML, forKey: bottleKey) }
    }

    /// Per-drink size overrides, keyed by DrinkKind.rawValue.
    @Published private(set) var sizeOverrides: [String: Int] = [:] {
        didSet {
            if let data = try? JSONEncoder().encode(sizeOverrides) {
                defaults.set(data, forKey: sizesKey)
            }
        }
    }

    private let defaults = UserDefaults.standard
    private let bottleKey = "bottleSizeML"
    private let sizesKey = "drinkSizeOverrides"
    private let historyKey = "history"
    private let goalKey = "goalML"
    private let profileKey = "profile"
    private let autoGoalKey = "useAutoGoal"

    init() {
        let storedBottle = defaults.integer(forKey: bottleKey)
        bottleSizeML = storedBottle == 0 ? 946 : storedBottle   // 32 oz default

        if let data = defaults.data(forKey: sizesKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            sizeOverrides = decoded
        }

        let storedGoal = defaults.integer(forKey: goalKey)
        manualGoalML = storedGoal == 0 ? 2000 : storedGoal

        if let data = defaults.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
        } else {
            profile = .default
        }

        // Default to automatic unless the user has explicitly turned it off.
        useAutoGoal = defaults.object(forKey: autoGoalKey) as? Bool ?? true

        if let data = defaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([String: DayRecord].self, from: data) {
            history = decoded
        }
        refreshDay()
    }

    /// Today's target: body-weight baseline plus a heat allowance, or the manual value.
    var goalML: Int {
        guard useAutoGoal else { return manualGoalML }
        return min(profile.baseGoalML + weatherBonusML, 8000)
    }

    private func syncTodayGoal() {
        var record = todayRecord
        guard record.goalML != goalML else { return }
        record.goalML = goalML
        history[todayKey] = record
        persistHistory()
    }

    // MARK: - Today

    var todayRecord: DayRecord {
        history[todayKey] ?? DayRecord(date: todayKey, intakeML: 0, goalML: goalML)
    }

    var intakeML: Int { todayRecord.intakeML }

    var progress: Double {
        guard goalML > 0 else { return 0 }
        return min(Double(intakeML) / Double(goalML), 1.0)
    }

    var remainingML: Int { max(0, goalML - intakeML) }

    /// Rolls over to a new day when the app returns from the background past midnight.
    func refreshDay() {
        let key = WaterStore.key(for: Date())
        if key != todayKey {
            todayKey = key
        }
        if history[key] == nil {
            history[key] = DayRecord(date: key, intakeML: 0, goalML: goalML)
            persistHistory()
        }
        syncTodayGoal()
    }

    /// The size this drink is logged at, honouring any edit the user made.
    func volumeML(for kind: DrinkKind) -> Int {
        sizeOverrides[kind.rawValue] ?? kind.defaultVolumeML
    }

    func setVolume(_ millilitres: Int, for kind: DrinkKind) {
        sizeOverrides[kind.rawValue] = max(15, min(millilitres, 2000))
    }

    func resetVolume(for kind: DrinkKind) {
        sizeOverrides.removeValue(forKey: kind.rawValue)
    }

    /// Logs a drink. Only the hydrating share counts toward the goal, so a
    /// 12 oz coffee moves the ring slightly less than 12 oz of water.
    func log(_ kind: DrinkKind) {
        append(DrinkEntry(kind: kind, volumeML: volumeML(for: kind)))
    }

    /// Logs part of the user's own bottle: a quarter, a half, or the lot.
    func logBottle(_ fraction: Double) {
        let millilitres = Int((Double(bottleSizeML) * fraction).rounded())
        append(DrinkEntry(kind: .water, volumeML: millilitres, bottleFraction: fraction))
    }

    private func append(_ entry: DrinkEntry) {
        var record = todayRecord
        record.entries.append(entry)
        record.intakeML = max(0, record.intakeML + entry.hydrationML)
        history[todayKey] = record
        persistHistory()
    }

    /// How many bottle-fulls today's goal works out to.
    var goalInBottles: Double {
        guard bottleSizeML > 0 else { return 0 }
        return Double(goalML) / Double(bottleSizeML)
    }

    /// Removes the most recent drink — the fix for a mis-tap.
    func undoLast() {
        var record = todayRecord
        guard let last = record.entries.popLast() else { return }
        record.intakeML = max(0, record.intakeML - last.hydrationML)
        history[todayKey] = record
        persistHistory()
    }

    var lastDrink: DrinkEntry? { todayRecord.entries.last }

    func reset() {
        var record = todayRecord
        record.intakeML = 0
        record.entries = []
        history[todayKey] = record
        persistHistory()
    }

    func setGoal(_ amount: Int) {
        manualGoalML = min(max(250, amount), 10000)
    }

    // MARK: - Streaks

    /// Consecutive days hitting the goal. Today only counts once the goal is met,
    /// so an unfinished day never reads as a broken streak.
    var currentStreak: Int {
        var streak = 0
        var day = Date()

        if !(history[WaterStore.key(for: day)]?.metGoal ?? false) {
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: day) else {
                return 0
            }
            day = yesterday
        }

        while let record = history[WaterStore.key(for: day)], record.metGoal {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    var bestStreak: Int {
        let metDays = history.values.filter(\.metGoal).map(\.date).sorted()
        guard !metDays.isEmpty else { return 0 }

        var best = 1
        var running = 1
        for index in 1..<metDays.count {
            guard let previous = WaterStore.date(from: metDays[index - 1]),
                  let current = WaterStore.date(from: metDays[index]),
                  let expected = Calendar.current.date(byAdding: .day, value: 1, to: previous) else {
                running = 1
                continue
            }
            if Calendar.current.isDate(current, inSameDayAs: expected) {
                running += 1
            } else {
                running = 1
            }
            best = max(best, running)
        }
        return best
    }

    var daysGoalMet: Int { history.values.filter(\.metGoal).count }

    // MARK: - History

    /// The last `count` days ending today, with untracked days filled in as zero.
    func recentDays(_ count: Int) -> [DayRecord] {
        let calendar = Calendar.current
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let key = WaterStore.key(for: day)
            return history[key] ?? DayRecord(date: key, intakeML: 0, goalML: goalML)
        }
    }

    /// Every tracked day, newest first.
    var loggedDays: [DayRecord] {
        history.values
            .filter { $0.intakeML > 0 }
            .sorted { $0.date > $1.date }
    }

    var averageIntake: Int {
        let logged = loggedDays
        guard !logged.isEmpty else { return 0 }
        return logged.reduce(0) { $0 + $1.intakeML } / logged.count
    }

    private func persistHistory() {
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }

    // MARK: - Date helpers

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func key(for date: Date) -> String { formatter.string(from: date) }

    static func date(from key: String) -> Date? { formatter.date(from: key) }

    static func displayName(for key: String) -> String {
        guard let date = date(from: key) else { return key }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let display = DateFormatter()
        display.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "EEE, MMM d"
            : "MMM d, yyyy"
        return display.string(from: date)
    }
}
