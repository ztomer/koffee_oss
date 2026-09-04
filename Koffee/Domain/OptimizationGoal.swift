import Foundation

enum OptimizationGoal: String, CaseIterable, Identifiable {
    case maxCognition = "Maximum Cognition"
    case deepSleep = "Deep Sleep"
    case balanced = "Balanced"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .maxCognition: return "brain.head.profile"
        case .deepSleep: return "moon.zzz"
        case .balanced: return "scalemass"
        }
    }

    var description: String {
        switch self {
        case .maxCognition: return "Prioritize alertness and focus"
        case .deepSleep: return "Prioritize sleep quality"
        case .balanced: return "Balance cognition and sleep"
        }
    }
}
