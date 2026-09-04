import Foundation

struct BiologicalIntervention: Identifiable, Equatable {
    let id: String
    let name: String
    let scheduledTime: Date
    let type: InterventionType
    let isAbsorptionBlocker: Bool
    let requiresFastedState: Bool
    let activeCaffeineMg: Double
    let durationMinutes: Int?
    let maintainsHepaticPerfusion: Bool

    enum InterventionType: String, CaseIterable {
        case beverage
        case supplement
        case nutrition
        case exercise
    }

    init(
        id: String,
        name: String,
        scheduledTime: Date,
        type: InterventionType,
        isAbsorptionBlocker: Bool = false,
        requiresFastedState: Bool = false,
        activeCaffeineMg: Double = 0,
        durationMinutes: Int? = nil,
        maintainsHepaticPerfusion: Bool = true
    ) {
        self.id = id
        self.name = name
        self.scheduledTime = scheduledTime
        self.type = type
        self.isAbsorptionBlocker = isAbsorptionBlocker
        self.requiresFastedState = requiresFastedState
        self.activeCaffeineMg = activeCaffeineMg
        self.durationMinutes = durationMinutes
        self.maintainsHepaticPerfusion = maintainsHepaticPerfusion
    }
}

struct SemanticProtocolBlock: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let targetTime: Date
    let primaryGoal: String
    let interventions: [BiologicalIntervention]

    var sortedInterventions: [BiologicalIntervention] {
        interventions.sorted { $0.scheduledTime < $1.scheduledTime }
    }
}

struct SemanticBlockClusterer {
    static func generateSemanticBlocks(from interventions: [BiologicalIntervention]) -> [SemanticProtocolBlock] {
        guard !interventions.isEmpty else { return [] }

        let sorted = interventions.sorted { $0.scheduledTime < $1.scheduledTime }

        var blocks: [SemanticProtocolBlock] = []
        var currentBlock: [BiologicalIntervention] = []
        var currentBlockTime: Date?

        let clusteringWindow: TimeInterval = 60 * 60 // 60 minutes

        for intervention in sorted {
            if let blockStart = currentBlockTime {
                let timeDiff = abs(intervention.scheduledTime.timeIntervalSince(blockStart))

                if timeDiff <= clusteringWindow {
                    currentBlock.append(intervention)
                } else {
                    if !currentBlock.isEmpty {
                        blocks.append(createBlock(from: currentBlock))
                    }
                    currentBlock = [intervention]
                    currentBlockTime = intervention.scheduledTime
                }
            } else {
                currentBlock = [intervention]
                currentBlockTime = intervention.scheduledTime
            }
        }

        if !currentBlock.isEmpty {
            blocks.append(createBlock(from: currentBlock))
        }

        return blocks
    }

    private static func createBlock(from interventions: [BiologicalIntervention]) -> SemanticProtocolBlock {
        let calendar = Calendar.current
        let firstTime = interventions.first!.scheduledTime
        let hour = calendar.component(.hour, from: firstTime)

        var blockName: String
        var primaryGoal: String

        let hasAbsorptionBlocker = interventions.contains { $0.isAbsorptionBlocker }
        let hasExercise = interventions.contains { $0.type == .exercise }

        if hasAbsorptionBlocker {
            blockName = "The Fiber Firewall"
            primaryGoal = "Gut Health & Satiety"
        } else if hasExercise {
            blockName = "The Metabolic Block"
            primaryGoal = "Performance & EPOC"
        } else if hour < 10 {
            blockName = "The Activation Block"
            primaryGoal = "Wakefulness & Baseline Nutrients"
        } else if hour >= 18 {
            blockName = "The Shutdown Block"
            primaryGoal = "Deep Sleep Architecture"
        } else if hour < 14 {
            blockName = "The Focus Block"
            primaryGoal = "Cognitive Optimization"
        } else {
            blockName = "The Maintenance Block"
            primaryGoal = "Sustained Performance"
        }

        return SemanticProtocolBlock(
            name: blockName,
            targetTime: firstTime,
            primaryGoal: primaryGoal,
            interventions: interventions
        )
    }
}
