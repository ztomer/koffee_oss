import Foundation

enum DeliveryMethod: String, Codable, CaseIterable {
    case liquid = "Liquid"
    case capsule = "Capsule"
    case sublingual = "Sublingual"
    case edible = "Edible"
    case gum = "Gum"
    case pill = "Pill"

    var peakOffsetMinutes: Double {
        switch self {
        case .liquid: return 30
        case .capsule: return 60
        case .sublingual: return 15
        case .edible: return 45
        case .gum: return 15
        case .pill: return 90
        }
    }

    var absorptionRate: Double {
        switch self {
        case .liquid: return 1.0
        case .capsule: return 0.85
        case .sublingual: return 0.95
        case .edible: return 0.9
        case .gum: return 0.95
        case .pill: return 0.75
        }
    }
}
