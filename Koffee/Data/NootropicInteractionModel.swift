import Foundation

struct NootropicInteractionModel {
    let compounds: [NootropicCompound]
    let caffeineDoseMg: Double

    var activeInteractions: [(compound: NootropicCompound, extensionHours: Double, description: String)] {
        compounds.compactMap { compound in
            let hours: Double
            let description: String
            switch compound {
            case .caffeine:
                return nil
            case .lTheanine:
                hours = 1.5
                description = "L-Theanine extends caffeine effect"
            case .magnesium:
                return nil
            case .ashwagandha:
                return nil
            case .vitaminB:
                return nil
            case .rhodiola:
                hours = 1.0
                description = "Rhodiola extends caffeine effect"
            case .theacrine:
                hours = 2.0
                description = "Theacrine extends caffeine effect"
            case .creatine:
                hours = 0.5
                description = "Creatine enhances cognitive endurance"
            case .alphaGPC:
                hours = 1.0
                description = "Alpha-GPC enhances focus"
            case .lTyrosine:
                hours = 0.5
                description = "L-Tyrosine supports alertness"
            case .psylliumHusk:
                return nil
            case .custom:
                return nil
            case .glycine:
                return nil
            }
            return (compound: compound, extensionHours: hours, description: description)
        }.filter { $0.extensionHours > 0 }
    }

    var totalExtensionHours: Double {
        activeInteractions.reduce(0) { $0 + $1.extensionHours }
    }
}
