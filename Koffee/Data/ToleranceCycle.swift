import Foundation

struct ToleranceCycle: Equatable {
    let daysSinceReset: Int
    let resetDaysRequired: Int

    var shouldReset: Bool {
        daysSinceReset >= resetDaysRequired
    }

    var effectivenessMultiplier: Double {
        let toleranceFactor = min(Double(daysSinceReset) / Double(resetDaysRequired), 1.0)
        return 1.0 + (toleranceFactor * 0.5)
    }

    var daysUntilReset: Int {
        max(0, resetDaysRequired - daysSinceReset)
    }
}
