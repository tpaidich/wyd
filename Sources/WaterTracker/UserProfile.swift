import Foundation

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case female
    case male
    case unspecified

    var id: String { rawValue }

    var label: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .unspecified: return "Prefer not to say"
        }
    }

    /// Baseline millilitres of water per kg of body weight. Males carry more
    /// lean mass and body water, so their per-kg requirement runs slightly higher.
    var mlPerKg: Double {
        switch self {
        case .male: return 35
        case .female: return 31
        case .unspecified: return 33
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case light
    case moderate
    case intense

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .intense: return "Intense"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return "Desk job, little exercise"
        case .light: return "Light exercise 1-3 days/week"
        case .moderate: return "Exercise 3-5 days/week"
        case .intense: return "Hard exercise 6-7 days/week"
        }
    }

    /// Extra millilitres to replace sweat losses on a typical day.
    var extraML: Int {
        switch self {
        case .sedentary: return 0
        case .light: return 350
        case .moderate: return 700
        case .intense: return 1000
        }
    }
}

/// Metric is the storage unit — the per-kg hydration formula is defined that
/// way — so these convert only at the edges, for display and entry.
enum BodyUnits {
    static let lbPerKG = 2.20462
    static let cmPerInch = 2.54

    static func pounds(_ kilograms: Double) -> Double { kilograms * lbPerKG }
    static func kilograms(_ pounds: Double) -> Double { pounds / lbPerKG }

    static func inches(_ centimetres: Double) -> Double { centimetres / cmPerInch }
    static func centimetres(_ inches: Double) -> Double { inches * cmPerInch }

    /// 66 inches reads as 5\' 6"
    static func heightLabel(inches: Double) -> String {
        let total = Int(inches.rounded())
        return "\(total / 12)\' \(total % 12)\""
    }
}

struct UserProfile: Codable, Equatable {
    var weightKG: Double
    var heightCM: Double
    var age: Int
    var sex: BiologicalSex
    var activity: ActivityLevel

    static let `default` = UserProfile(
        weightKG: 65,
        heightCM: 168,
        age: 30,
        sex: .unspecified,
        activity: .light
    )

    /// Body-weight driven baseline, nudged by age and topped up for activity.
    ///
    /// Kidney concentrating ability and thirst response decline with age, and
    /// children/teens run higher per-kg turnover, so the per-kg rate is scaled
    /// before the activity allowance is added.
    var baseGoalML: Int {
        let perKg = sex.mlPerKg * ageFactor
        let base = weightKG * perKg
        let total = base + Double(activity.extraML)
        // Round to the nearest 50 ml so the number reads like a target, not a readout.
        return min(max(Int((total / 50).rounded()) * 50, 1000), 6000)
    }

    private var ageFactor: Double {
        switch age {
        case ..<18: return 1.10
        case 18..<30: return 1.0
        case 30..<55: return 0.97
        case 55..<65: return 0.94
        default: return 0.90
        }
    }

    var bmi: Double {
        guard heightCM > 0 else { return 0 }
        let metres = heightCM / 100
        return weightKG / (metres * metres)
    }
}
