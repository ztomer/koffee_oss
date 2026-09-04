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
