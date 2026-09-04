import Foundation

struct FocusWindow: Equatable {
    let start: Date
    let end: Date
    let peakLevel: Double

    var isActive: Bool {
        let now = Date()
        return start <= now && now <= end
    }
}

struct ToleranceAlert: Equatable {
    let compound: String
    let daysConsecutive: Int
    let recommendedCyclingDays: Int
    let message: String
    let urgency: AlertUrgency
}

enum AlertUrgency: String {
    case low
    case medium
    case high
}
