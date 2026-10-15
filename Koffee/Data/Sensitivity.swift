import Foundation

enum Sensitivity: String, CaseIterable, Identifiable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"

    var id: String { rawValue }

    var swiftDataValue: String {
        rawValue.lowercased()
    }

    init?(swiftDataValue: String) {
        switch swiftDataValue.lowercased() {
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        default: return nil
        }
    }

    var multiplier: Double {
        switch self {
        case .low: return 1.2
        case .medium: return 1.0
        case .high: return 0.8
        }
    }

    /// This user's daily ceiling in mg.
    ///
    /// K1. This USED TO be `multiplier * 400`, which showed a low-sensitivity
    /// user 480 mg/day as safe. Two things were wrong with that, and they are
    /// different problems:
    ///
    ///  * the ceiling is EFSA's adult population limit. It is not raised by
    ///    self-report, and `.low` means "caffeine leaves me jittery", which is
    ///    a reason to be MORE careful, not less.
    ///  * `multiplier` is a METABOLISM term. It belongs to the bedtime
    ///    threshold (`safeCaffeineAtBedtime`) and to the decay model, where
    ///    clearance rate is exactly the right input. Applied to a population
    ///    ceiling it was the right quantity in the wrong place -- the same
    ///    class as a clearance rate driving a dosage.
    ///
    /// So the ceiling is the ceiling. `multiplier` is untouched and still used
    /// where it belongs. Nothing here is user-tunable, deliberately: the moment
    /// a preference can raise a safety number, it will, by a user who does not
    /// know they have raised it.
    var dailyCeilingMg: Double {
        CaffeineConstants.dailyCeilingMg
    }

    var safeCaffeineAtBedtime: Double {
        switch self {
        case .low: return 100.0
        case .medium: return 50.0
        case .high: return 25.0
        }
    }

    var hoursBeforeBedForLastDose: Double {
        switch self {
        case .low: return 6.0
        case .medium: return 9.0
        case .high: return 12.0
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}
