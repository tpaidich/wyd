import Foundation
import SwiftData

/// One tracked day. The unique date key means a day can never be written twice,
/// which `UserDefaults` could not guarantee once two code paths both wrote the
/// history dictionary.
@Model
final class DayLog {
    /// "yyyy-MM-dd", the same key the app has always used.
    @Attribute(.unique) var date: String
    var intakeML: Int
    var goalML: Int
    /// Denormalised so the streak and the calendar can be answered by a query
    /// with a predicate, instead of loading every day into memory to filter it.
    var metGoal: Bool

    @Relationship(deleteRule: .cascade, inverse: \DrinkLog.day)
    var entries: [DrinkLog] = []

    init(date: String, intakeML: Int = 0, goalML: Int = 0) {
        self.date = date
        self.intakeML = intakeML
        self.goalML = goalML
        self.metGoal = goalML > 0 && intakeML >= goalML
    }

    /// The one place intake and goal change, so `metGoal` cannot drift.
    func apply(intakeML: Int? = nil, goalML: Int? = nil) {
        if let intakeML { self.intakeML = max(0, intakeML) }
        if let goalML { self.goalML = goalML }
        metGoal = self.goalML > 0 && self.intakeML >= self.goalML
    }

    /// A value snapshot for the views, which never touch the model objects.
    var snapshot: DayRecord {
        DayRecord(
            date: date,
            intakeML: intakeML,
            goalML: goalML,
            entries: entries.sorted { $0.time < $1.time }.map(\.entry)
        )
    }
}

@Model
final class DrinkLog {
    var kindID: String
    var volumeML: Int
    var hydrationML: Int
    var time: Date
    /// Set when the drink came from the user's own bottle.
    var bottleFraction: Double?
    var day: DayLog?

    init(entry: DrinkEntry) {
        kindID = entry.kind.rawValue
        volumeML = entry.volumeML
        hydrationML = entry.hydrationML
        time = entry.time
        bottleFraction = entry.bottleFraction
    }

    var entry: DrinkEntry {
        var value = DrinkEntry(
            kind: DrinkKind(rawValue: kindID) ?? .water,
            volumeML: volumeML,
            bottleFraction: bottleFraction,
            time: time
        )
        // A drink's hydration factor could change between releases; what was
        // actually credited on the day is what the day should keep showing.
        value.hydrationML = hydrationML
        return value
    }
}

enum Persistence {
    static let schema = Schema([DayLog.self, DrinkLog.self])

    /// Falls back to an in-memory store rather than trapping. A failure here
    /// means the day's logging is lost on quit, which is bad, but a crash on
    /// launch with no way back is worse.
    static func container() -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema)
            )
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: fallback)
        }
    }
}
