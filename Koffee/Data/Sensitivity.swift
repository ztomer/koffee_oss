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

    /// The gap before bed that this reader's own model requires of a given dose.
    ///
    /// K3. Replaced a fixed 6 / 9 / 12 hour table with a derivation, because the
    /// table was dose-blind and could therefore certify a dose as safe that the
    /// reader's own threshold called unsafe.
    ///
    /// `halfLifeHours` is the **effective** half-life — the reader's base half-life
    /// already multiplied by their metabolism rate.
    ///
    /// Returns the LONGER of the two, never the shorter, and never an average:
    /// where the Gardiner floor binds the empirics do the work, and where the
    /// derivation binds the reader's own threshold does.
    func hoursBeforeBedForLastDose(doseMg: Double, halfLifeHours: Double) -> Double {
        return max(
            CaffeinePK.hoursToDecay(
                doseMg: doseMg,
                toMilligrams: safeCaffeineAtBedtime,
                halfLifeHours: halfLifeHours
            ),
            CaffeinePK.floorHours(doseMg: doseMg)
        )
    }

    var displayName: String {
        rawValue.capitalized
    }
}
