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

    /// Scales caffeine half-life: slow metabolizers clear caffeine over a
    /// LONGER half-life (multiplier > 1), fast metabolizers shorter (< 1).
    /// Every consumer must apply it in the half-life-lengthening direction:
    /// `halfLife * multiplier`, `Vmax / multiplier`, `bufferHours * multiplier`.
    /// (Fixed 2026-09: values were inverted — slow cleared faster.)
    var halfLifeMultiplier: Double {
        switch self {
        case .slow: return 1.4
        case .medium: return 1.0
        case .fast: return 0.7
        }
    }

    var displayName: String {
        switch self {
        case .slow: return "Slow"
        case .medium: return "Medium"
        case .fast: return "Fast"
        }
    }

    /// Gene-type hint shown as a caption, never as the option label.
    var genotypeNote: String {
        switch self {
        case .slow: return "Often CYP1A2 AA type"
        case .medium: return "Most common type"
        case .fast: return "Often CYP1A2 AC or CC type"
        }
    }

    static func fromSliderValue(_ value: Double) -> MetabolismRate {
        if value < 0.33 { return .slow }
        if value > 0.66 { return .fast }
        return .medium
    }
}
