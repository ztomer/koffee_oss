import Foundation

/// A caffeine event on the timeline: either a logged dose or a scheduled
/// caffeine plan item. The former nutrition / supplement / exercise
/// intervention kinds were removed in the coffee-only strip.
struct BiologicalIntervention: Identifiable, Equatable {
    let id: String
    let name: String
    let scheduledTime: Date
    let type: InterventionType
    let activeCaffeineMg: Double

    enum InterventionType: String, CaseIterable {
        case beverage
    }

    init(
        id: String,
        name: String,
        scheduledTime: Date,
        type: InterventionType = .beverage,
        activeCaffeineMg: Double = 0
    ) {
        self.id = id
        self.name = name
        self.scheduledTime = scheduledTime
        self.type = type
        self.activeCaffeineMg = activeCaffeineMg
    }
}
