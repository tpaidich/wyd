import Foundation

enum DrinkCategory: String, CaseIterable, Identifiable {
    case hot
    case cold
    case energy
    case alcohol

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hot: return "Hot drinks"
        case .cold: return "Cold drinks"
        case .energy: return "Energy and sport"
        case .alcohol: return "Alcohol"
        }
    }
}

enum DrinkKind: String, Codable, CaseIterable, Identifiable {
    // The three on the home screen.
    case water
    case coffee
    case soda
    // Everything else lives behind "More drinks".
    case espresso
    case latte
    case coldBrew
    case tea
    case sparklingWater
    case juice
    case milk
    case energyDrink
    case sportsDrink
    case beer
    case wine
    case spirit

    var id: String { rawValue }

    /// The three people reach for most, shown without a tap.
    static let primary: [DrinkKind] = [.water, .coffee, .soda]

    static func inCategory(_ category: DrinkCategory) -> [DrinkKind] {
        allCases.filter { $0.category == category && !primary.contains($0) }
    }

    var category: DrinkCategory {
        switch self {
        case .coffee, .espresso, .latte, .coldBrew, .tea: return .hot
        case .water, .sparklingWater, .juice, .milk, .soda: return .cold
        case .energyDrink, .sportsDrink: return .energy
        case .beer, .wine, .spirit: return .alcohol
        }
    }

    var label: String {
        switch self {
        case .water: return "Water"
        case .coffee: return "Coffee"
        case .soda: return "Soda"
        case .espresso: return "Espresso"
        case .latte: return "Latte"
        case .coldBrew: return "Cold brew"
        case .tea: return "Tea"
        case .sparklingWater: return "Sparkling water"
        case .juice: return "Juice"
        case .milk: return "Milk"
        case .energyDrink: return "Energy drink"
        case .sportsDrink: return "Sports drink"
        case .beer: return "Beer"
        case .wine: return "Wine"
        case .spirit: return "Spirit"
        }
    }

    var symbol: String {
        switch self {
        case .water: return "drop.fill"
        case .sparklingWater: return "bubbles.and.sparkles.fill"
        case .coffee, .espresso: return "cup.and.heat.waves.fill"
        case .latte: return "cup.and.saucer.fill"
        case .coldBrew: return "takeoutbag.and.cup.and.straw.fill"
        case .tea: return "mug.fill"
        case .juice: return "takeoutbag.and.cup.and.straw.fill"
        case .milk: return "waterbottle.fill"
        case .soda: return "bubbles.and.sparkles.fill"
        case .energyDrink: return "bolt.fill"
        case .sportsDrink: return "figure.run"
        case .beer: return "mug.fill"
        case .wine: return "wineglass.fill"
        case .spirit: return "wineglass.fill"
        }
    }

    /// The size this drink usually comes in. Editable in Settings.
    var defaultVolumeML: Int {
        switch self {
        case .water: return 237            // 8 oz glass
        case .coffee: return 355           // 12 oz
        case .soda: return 355             // 12 oz can
        case .espresso: return 30          // 1 oz shot
        case .latte: return 355            // 12 oz
        case .coldBrew: return 473         // 16 oz
        case .tea: return 237              // 8 oz
        case .sparklingWater: return 355   // 12 oz
        case .juice: return 237            // 8 oz
        case .milk: return 237             // 8 oz
        case .energyDrink: return 473      // 16 oz can
        case .sportsDrink: return 591      // 20 oz
        case .beer: return 355             // 12 oz
        case .wine: return 148             // 5 oz
        case .spirit: return 44            // 1.5 oz
        }
    }

    /// How a drink translates into hydration. Most scale with volume, but
    /// alcohol does not: its cost tracks the alcohol, not the liquid.
    enum Effect {
        case multiplier(Double)
        case volumeMinusLoss(mlPerServing: Int)
    }

    /// Roughly the extra fluid the body sheds per standard alcoholic drink.
    static let diureticLossPerDrinkML = 140

    var effect: Effect {
        switch self {
        case .water, .sparklingWater, .tea: return .multiplier(1.0)
        case .milk: return .multiplier(1.3)
        case .sportsDrink: return .multiplier(1.1)
        case .latte: return .multiplier(1.05)
        case .coffee, .juice: return .multiplier(0.95)
        case .soda: return .multiplier(0.9)
        case .espresso, .coldBrew: return .multiplier(0.9)
        case .energyDrink: return .multiplier(0.85)
        case .beer, .wine, .spirit:
            return .volumeMinusLoss(mlPerServing: Self.diureticLossPerDrinkML)
        }
    }

    /// Can be negative: a neat spirit costs more fluid than it supplies.
    func hydrationML(forVolume millilitres: Int) -> Int {
        switch effect {
        case .multiplier(let factor):
            return Int((Double(millilitres) * factor).rounded())
        case .volumeMinusLoss(let lossPerServing):
            // A double pour costs double, so scale the loss with servings.
            let servings = Double(millilitres) / Double(defaultVolumeML)
            return millilitres - Int((Double(lossPerServing) * servings).rounded())
        }
    }

    var rationale: String {
        switch self {
        case .water:
            return "The baseline everything else is measured against."
        case .sparklingWater:
            return "Carbonation changes nothing that matters. It hydrates like still water."
        case .milk:
            return "Protein, fat and lactose slow how fast milk leaves the stomach, and its sodium and potassium help the body hold on to fluid. Measured over a few hours, more of it stays in you than plain water does."
        case .sportsDrink:
            return "Built for rehydration. The sodium and small sugar load pull fluid across the gut wall and help you keep it."
        case .latte:
            return "Mostly milk, which offsets the espresso in it."
        case .tea:
            return "At normal brewing strength the caffeine is far too weak a diuretic to offset the fluid it arrives in."
        case .coffee:
            return "Caffeine is a much milder diuretic than its reputation suggests. A coffee still hydrates you nearly as well as water."
        case .espresso:
            return "Very concentrated caffeine, though the serving is so small it barely moves your total either way."
        case .coldBrew:
            return "Brewed strong, so it carries noticeably more caffeine per ounce than drip coffee."
        case .juice:
            return "Sugar draws water into the gut and slows absorption slightly."
        case .soda:
            return "More sugar than juice, so slightly less of it counts."
        case .energyDrink:
            return "Heavy caffeine and heavy sugar together, which is the least hydrating combination on this list."
        case .beer:
            return "Alcohol suppresses the hormone that tells your kidneys to hold water. A beer is mostly water though, so it still nets out positive."
        case .wine:
            return "Same alcohol as a beer in a third of the liquid, so it roughly cancels itself out."
        case .spirit:
            return "A full serving of alcohol with almost no water attached, so it takes more fluid than it gives."
        }
    }
}

struct DrinkEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: DrinkKind
    var volumeML: Int
    var hydrationML: Int
    var time: Date
    /// Set when the drink came from the user's own bottle.
    var bottleFraction: Double?

    init(kind: DrinkKind, volumeML: Int, bottleFraction: Double? = nil, time: Date = Date()) {
        self.kind = kind
        self.volumeML = volumeML
        self.hydrationML = kind.hydrationML(forVolume: volumeML)
        self.bottleFraction = bottleFraction
        self.time = time
    }

    // Older entries used vessels, then drink sizes. Both decode as their volume.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        time = try container.decodeIfPresent(Date.self, forKey: .time) ?? Date()
        bottleFraction = try container.decodeIfPresent(Double.self, forKey: .bottleFraction)

        let decodedKind = (try? container.decodeIfPresent(DrinkKind.self, forKey: .kind)) ?? nil
        kind = decodedKind ?? .water

        volumeML = try container.decodeIfPresent(Int.self, forKey: .volumeML) ?? kind.defaultVolumeML
        hydrationML = try container.decodeIfPresent(Int.self, forKey: .hydrationML)
            ?? kind.hydrationML(forVolume: volumeML)
    }
}

/// Fluid ounces for display; millilitres remain the storage unit.
enum Volume {
    static let mlPerOz = 29.5735

    static func oz(_ millilitres: Int) -> Double { Double(millilitres) / mlPerOz }

    static func ml(fromOz ounces: Double) -> Int { Int((ounces * mlPerOz).rounded()) }

    /// "8", "16.9", "108" - a decimal only where it carries meaning.
    static func format(_ millilitres: Int) -> String {
        let ounces = oz(millilitres)
        if ounces >= 20 { return String(Int(ounces.rounded())) }
        let rounded = (ounces * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
    }

    static func label(_ millilitres: Int) -> String { "\(format(millilitres)) oz" }
}

/// One 8 oz glass is the yardstick the whole UI counts in.
enum Glass {
    static let ml = 237

    /// "3", "3.5" - never "3.0", and never a wall of decimals.
    static func format(_ millilitres: Int) -> String {
        let glasses = Double(millilitres) / Double(ml)
        let rounded = (glasses * 2).rounded() / 2
        return rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
    }

    /// "1 glass", "3.5 glasses" - the count with a noun that agrees with it.
    static func label(_ millilitres: Int) -> String {
        let count = format(millilitres)
        return count == "1" ? "1 glass" : "\(count) glasses"
    }
}
