import Foundation

enum MetabolismRate: String, CaseIterable, Identifiable {
    case slow
    case medium
    case fast

    var id: String { rawValue }

    var swiftDataValue: String {
        rawValue
    }

    init?(swiftDataValue: String) {
        switch swiftDataValue.lowercased() {
        case "slow": self = .slow
        case "medium": self = .medium
        case "fast": self = .fast
        default: return nil
        }
    }

    var halfLifeMultiplier: Double {
        switch self {
        case .slow: return 0.7
        case .medium: return 1.0
        case .fast: return 1.4
        }
    }

    var displayName: String {
        switch self {
        case .slow: return "Slow (CYP1A2 AA)"
        case .medium: return "Medium"
        case .fast: return "Fast (CYP1A2 AC/CC)"
        }
    }

    static func fromSliderValue(_ value: Double) -> MetabolismRate {
        if value < 0.33 { return .slow }
        if value > 0.66 { return .fast }
        return .medium
    }
}
