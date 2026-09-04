import Foundation

enum InterventionType: String, CaseIterable {
    case supplement
    case beverage
    case physical
    case hydration

    var icon: String {
        switch self {
        case .supplement: return "pills.fill"
        case .beverage: return "cup.and.saucer.fill"
        case .physical: return "figure.walk"
        case .hydration: return "drop.fill"
        }
    }
}
