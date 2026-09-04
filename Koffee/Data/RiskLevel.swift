import Foundation

enum RiskLevel: String, Equatable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }

    var description: String {
        switch self {
        case .low: return "Optimal for sleep"
        case .medium: return "Acceptable, monitor"
        case .high: return "May affect sleep"
        case .critical: return "Will likely disrupt sleep"
        }
    }
}
