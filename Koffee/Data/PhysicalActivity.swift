import Foundation

enum PhysicalActivity: String, CaseIterable, Identifiable {
    case hiit = "HIIT"
    case zone2Cardio = "Zone 2 Cardio"
    case parasympatheticWalk = "Parasympathetic Walk"
    case breathwork = "Breathwork"
    case coldExposure = "Cold Exposure"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .hiit: return "flame.fill"
        case .zone2Cardio: return "heart.fill"
        case .parasympatheticWalk: return "figure.walk"
        case .breathwork: return "wind"
        case .coldExposure: return "snowflake"
        }
    }

    var durationMinutes: Int {
        switch self {
        case .hiit: return 20
        case .zone2Cardio: return 45
        case .parasympatheticWalk: return 20
        case .breathwork: return 10
        case .coldExposure: return 5
        }
    }

    var pkEffect: PKEffect {
        switch self {
        case .hiit:
            return PKEffect(
                caffeineClearanceMultiplier: 1.3,
                cortisolSpike: true,
                halfLifeImpact: -1.5,
                description: "HIIT spikes cortisol and temporarily increases caffeine absorption rate. Avoid within 4h of bedtime."
            )
        case .zone2Cardio:
            return PKEffect(
                caffeineClearanceMultiplier: 1.2,
                cortisolSpike: false,
                halfLifeImpact: -1.0,
                description: "Zone 2 cardio gently accelerates metabolic clearance. Can help evening caffeine clearance."
            )
        case .parasympatheticWalk:
            return PKEffect(
                caffeineClearanceMultiplier: 1.1,
                cortisolSpike: false,
                halfLifeImpact: -0.5,
                description: "Vagal stimulation promotes parasympathetic state, aiding caffeine metabolism and sleep readiness."
            )
        case .breathwork:
            return PKEffect(
                caffeineClearanceMultiplier: 1.05,
                cortisolSpike: false,
                halfLifeImpact: -0.3,
                description: "Controlled breathing activates parasympathetic nervous system, reducing stress and aiding clearance."
            )
        case .coldExposure:
            return PKEffect(
                caffeineClearanceMultiplier: 1.15,
                cortisolSpike: true,
                halfLifeImpact: -0.8,
                description: "Cold shower/shock increases alertness and marginally accelerates metabolism. Avoid late evening."
            )
        }
    }

    var explanation: String {
        switch self {
        case .hiit:
            return "High-Intensity Interval Training. Elevates heart rate to 80-95% max, creating metabolic demand "
                 + "that accelerates caffeine clearance. Best performed 4+ hours before bed."
        case .zone2Cardio:
            return "Low-intensity steady-state cardio (heart rate 60-70% max). Promotes blood flow and enzymatic "
                 + "activity that processes caffeine. Can be done in evening for gentle clearance."
        case .parasympatheticWalk:
            return "A gentle 15-20 minute walk in nature or around the block. Activates vagal tone, reduces cortisol, "
                 + "and supports the transition to evening wind-down."
        case .breathwork:
            return "Controlled breathing exercises (box breathing, 4-7-8). Direct parasympathetic activation that helps process caffeine and prepare for sleep."
        case .coldExposure:
            return "Cold shower, ice bath, or cold water face immersion. Triggers dopamine release and metabolic spike. Best morning or early afternoon."
        }
    }

    var optimalTimingMinutes: Double {
        switch self {
        case .hiit: return -240 // 4 hours before bedtime
        case .zone2Cardio: return -180 // 3 hours before bedtime
        case .parasympatheticWalk: return -60 // 1 hour before bedtime
        case .breathwork: return -30 // 30 min before bedtime
        case .coldExposure: return 120 // 2 hours after waking
        }
    }
}
