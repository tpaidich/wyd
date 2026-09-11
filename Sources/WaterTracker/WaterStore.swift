import Foundation
import Combine
import SwiftData

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
    /// Today, as a value. Views read this rather than the model objects, so a
    /// fetch never has to happen inside a `body`.
    @Published private(set) var today: DayRecord
    @Published private(set) var todayKey: String = WaterStore.key(for: Date())

    /// Both are read several times per render, so they are cached and
    /// recomputed on write rather than queried from `body`.
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var averageIntake: Int = 0

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

    /// The three drinks on the home screen, in the order they appear.
    @Published private(set) var quickDrinkIDs: [String] {
        didSet { defaults.set(quickDrinkIDs, forKey: quickKey) }
    }

    // Days live in SwiftData; settings are a fixed handful of values and stay
    // in UserDefaults, which is the right size of tool for them.
    private let container: ModelContainer
    private let context: ModelContext

    private let defaults = UserDefaults.standard
    private let quickKey = "quickDrinkIDs"
    private let bottleKey = "bottleSizeML"
    private let sizesKey = "drinkSizeOverrides"
    private let historyKey = "history"
    private let migratedKey = "historyMigratedToSwiftData"
    private let goalKey = "goalML"
    private let profileKey = "profile"
    private let autoGoalKey = "useAutoGoal"

    init(container: ModelContainer = Persistence.container()) {
        self.container = container
        self.context = ModelContext(container)

        let storedQuick = defaults.stringArray(forKey: quickKey) ?? []
        // Fall back to the original trio if nothing valid is stored.
        let valid = storedQuick.filter { DrinkKind(rawValue: $0) != nil }
        quickDrinkIDs = valid.isEmpty ? DrinkKind.primary.map(\.rawValue) : valid

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

        today = DayRecord(date: WaterStore.key(for: Date()), intakeML: 0, goalML: 0)

        migrateHistoryIfNeeded()
        refreshDay()
    }

    /// Today's target: body-weight baseline plus a heat allowance, or the manual value.
    var goalML: Int {
        guard useAutoGoal else { return manualGoalML }
        return min(profile.baseGoalML + weatherBonusML, 8000)
    }

    // MARK: - Migration

    /// Moves the single `history` blob into SwiftData, once. The blob is left
    /// in place rather than deleted: if this release turns out to be wrong,
    /// the user's days are still sitting there.
    private func migrateHistoryIfNeeded() {
        guard !defaults.bool(forKey: migratedKey) else { return }
        defer { defaults.set(true, forKey: migratedKey) }

        guard let data = defaults.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([String: DayRecord].self, from: data)
        else { return }

        for record in decoded.values {
            let day = DayLog(date: record.date, intakeML: record.intakeML, goalML: record.goalML)
            context.insert(day)
            for entry in record.entries {
                let drink = DrinkLog(entry: entry)
                drink.day = day
                context.insert(drink)
            }
        }
        try? context.save()
    }

    // MARK: - Fetching

    private func dayLog(for key: String) -> DayLog? {
        var descriptor = FetchDescriptor<DayLog>(predicate: #Predicate { $0.date == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// The day, creating it if this is the first time it has been touched.
    private func ensureDayLog(for key: String) -> DayLog {
        if let existing = dayLog(for: key) { return existing }
        let day = DayLog(date: key, intakeML: 0, goalML: goalML)
        context.insert(day)
        return day
    }

    /// A day as a value, or nil if nothing was ever logged that day.
    func record(for key: String) -> DayRecord? {
        dayLog(for: key)?.snapshot
    }

    private func days(withKeys keys: [String]) -> [String: DayLog] {
        let descriptor = FetchDescriptor<DayLog>(predicate: #Predicate { keys.contains($0.date) })
        let found = (try? context.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: found.map { ($0.date, $0) })
    }

    // MARK: - Today

    var todayRecord: DayRecord { today }

    var intakeML: Int { today.intakeML }

    var progress: Double {
        guard goalML > 0 else { return 0 }
        return min(Double(intakeML) / Double(goalML), 1.0)
    }

    var remainingML: Int { max(0, goalML - intakeML) }

    var lastDrink: DrinkEntry? { today.entries.last }

    /// Rolls over to a new day when the app returns from the background past midnight.
    func refreshDay() {
        let key = WaterStore.key(for: Date())
        if key != todayKey { todayKey = key }
        let day = ensureDayLog(for: key)
        day.apply(goalML: goalML)
        commit(day)
    }

    private func syncTodayGoal() {
        let day = ensureDayLog(for: todayKey)
        guard day.goalML != goalML else { return }
        day.apply(goalML: goalML)
        commit(day)
    }

    /// The one write path: save, refresh the published snapshot, recompute the
    /// cached stats. Nothing else is allowed to touch the context.
    private func commit(_ day: DayLog) {
        try? context.save()
        today = day.snapshot
        recomputeStats()
    }

    // MARK: - Logging

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
        let day = ensureDayLog(for: todayKey)
        let drink = DrinkLog(entry: entry)
        drink.day = day
        context.insert(drink)
        day.apply(intakeML: day.intakeML + entry.hydrationML)
        commit(day)
    }

    /// Removes the most recent drink, the fix for a mis-tap.
    func undoLast() {
        let day = ensureDayLog(for: todayKey)
        guard let last = day.entries.max(by: { $0.time < $1.time }) else { return }
        day.apply(intakeML: day.intakeML - last.hydrationML)
        context.delete(last)
        commit(day)
    }

    func reset() {
        let day = ensureDayLog(for: todayKey)
        for drink in day.entries { context.delete(drink) }
        day.apply(intakeML: 0)
        commit(day)
    }

    func setGoal(_ amount: Int) {
        manualGoalML = min(max(250, amount), 10000)
    }

    // MARK: - Quick drinks and sizes

    var quickDrinks: [DrinkKind] {
        quickDrinkIDs.compactMap(DrinkKind.init(rawValue:))
    }

    static let quickDrinkLimit = 3

    /// Adding a fourth pushes out the one chosen longest ago, so picking a new
    /// favourite never requires deselecting something first.
    func toggleQuickDrink(_ kind: DrinkKind) {
        if let index = quickDrinkIDs.firstIndex(of: kind.rawValue) {
            guard quickDrinkIDs.count > 1 else { return }
            quickDrinkIDs.remove(at: index)
        } else {
            quickDrinkIDs.append(kind.rawValue)
            if quickDrinkIDs.count > Self.quickDrinkLimit {
                quickDrinkIDs.removeFirst()
            }
        }
    }

    func reorderQuickDrinks(from source: IndexSet, to destination: Int) {
        quickDrinkIDs.move(fromOffsets: source, toOffset: destination)
    }

    func isQuickDrink(_ kind: DrinkKind) -> Bool {
        quickDrinkIDs.contains(kind.rawValue)
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

    /// How many bottle-fulls today's goal works out to.
    var goalInBottles: Double {
        guard bottleSizeML > 0 else { return 0 }
        return Double(goalML) / Double(bottleSizeML)
    }

    // MARK: - Stats

    private func recomputeStats() {
        currentStreak = computeCurrentStreak()
        averageIntake = computeAverageIntake()
    }

    /// Consecutive days hitting the goal. Today only counts once the goal is met,
    /// so an unfinished day never reads as a broken streak.
    ///
    /// Only days that met the goal are fetched, newest first, so the walk stops
    /// at the first gap instead of scanning the whole history.
    private func computeCurrentStreak() -> Int {
        var descriptor = FetchDescriptor<DayLog>(
            predicate: #Predicate { $0.metGoal },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.propertiesToFetch = [\.date]
        guard let met = try? context.fetch(descriptor), !met.isEmpty else { return 0 }

        let metKeys = Set(met.map(\.date))
        let calendar = Calendar.current
        var day = Date()

        // An unfinished today is not a broken streak, so start from yesterday.
        if !metKeys.contains(WaterStore.key(for: day)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while metKeys.contains(WaterStore.key(for: day)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private func computeAverageIntake() -> Int {
        var descriptor = FetchDescriptor<DayLog>(predicate: #Predicate { $0.intakeML > 0 })
        descriptor.propertiesToFetch = [\.intakeML]
        guard let logged = try? context.fetch(descriptor), !logged.isEmpty else { return 0 }
        return logged.reduce(0) { $0 + $1.intakeML } / logged.count
    }

    // MARK: - History

    /// The last `count` days ending today, with untracked days filled in as zero.
    func recentDays(_ count: Int) -> [DayRecord] {
        let calendar = Calendar.current
        let keys: [String] = (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: Date()).map(WaterStore.key(for:))
        }
        let found = days(withKeys: keys)
        return keys.map { key in
            found[key]?.snapshot ?? DayRecord(date: key, intakeML: 0, goalML: goalML)
        }
    }

    /// Every day in the given keys that has something logged, as values.
    func records(forKeys keys: [String]) -> [String: DayRecord] {
        days(withKeys: keys).mapValues(\.snapshot)
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
