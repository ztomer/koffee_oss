import Foundation

enum NootropicCompound: String, CaseIterable, Identifiable {
    case caffeine = "Caffeine"
    case lTheanine = "L-Theanine"
    case magnesium = "Magnesium"
    case ashwagandha = "Ashwagandha"
    case vitaminB = "Vitamin B"
    case rhodiola = "Rhodiola"
    case theacrine = "Theacrine"
    case creatine = "Creatine"
    case alphaGPC = "Alpha-GPC"
    case lTyrosine = "L-Tyrosine"
    case psylliumHusk = "Psyllium Husk"
    case glycine = "Glycine"
    case custom = "Custom"

    var id: String { rawValue }

    var optimalDoseMg: Double {
        switch self {
        case .caffeine: return 95
        case .lTheanine: return 200
        case .magnesium: return 2000
        case .ashwagandha: return 600
        case .vitaminB: return 100
        case .rhodiola: return 200
        case .theacrine: return 100
        case .creatine: return 5000
        case .alphaGPC: return 300
        case .lTyrosine: return 1000
        case .psylliumHusk: return 5000
        case .glycine: return 3000
        case .custom: return 0
        }
    }

    var safeLimitMg: Double {
        switch self {
        case .caffeine: return 400
        case .lTheanine: return 400
        case .magnesium: return 4000
        case .ashwagandha: return 600
        case .vitaminB: return 100
        case .rhodiola: return 600
        case .theacrine: return 300
        case .creatine: return 5000
        case .alphaGPC: return 600
        case .lTyrosine: return 3000
        case .psylliumHusk: return 5000
        case .glycine: return 3000
        case .custom: return 0
        }
    }

    var peakTimeMinutes: Double {
        switch self {
        case .caffeine: return 45
        case .lTheanine: return 45
        case .magnesium: return 90
        case .ashwagandha: return 120
        case .vitaminB: return 60
        case .rhodiola: return 90
        case .theacrine: return 60
        case .creatine: return 120
        case .alphaGPC: return 60
        case .lTyrosine: return 45
        case .psylliumHusk: return 0
        case .glycine: return 30
        case .custom: return 60
        }
    }

    var halfLifeHours: Double {
        switch self {
        case .caffeine: return 5.0
        case .lTheanine: return 4.0
        case .magnesium: return 6.0
        case .ashwagandha: return 4.5
        case .vitaminB: return 8.0
        case .rhodiola: return 3.0
        case .theacrine: return 7.0
        case .creatine: return 3.0
        case .alphaGPC: return 6.0
        case .lTyrosine: return 2.5
        case .psylliumHusk: return 0
        case .glycine: return 2.0
        case .custom: return 0
        }
    }

    var synergyBenefit: String? {
        switch self {
        case .caffeine: return "Primary stimulant, increases alertness and focus"
        case .lTheanine: return "Reduces caffeine jitters, extends focus"
        case .magnesium: return "Improves sleep quality, reduces tolerance"
        case .ashwagandha: return "Reduces cortisol, improves recovery"
        case .vitaminB: return "Energy metabolism support"
        case .rhodiola: return "Reduces fatigue, improves endurance"
        case .theacrine: return "Longer lasting than caffeine, no tolerance"
        case .creatine: return "ATP buffer, enhances cognitive endurance"
        case .alphaGPC: return "Increases acetylcholine, enhances memory encoding"
        case .lTyrosine: return "Dopamine precursor, buffers stress-induced depletion"
        case .psylliumHusk: return "Fiber for gut health and satiety"
        case .glycine: return "Deep Sleep Architecture & Core Temperature Regulation"
        case .custom: return nil
        }
    }

    var recommendedTimingMinutes: Double {
        switch self {
        case .caffeine: return 90
        case .lTheanine: return -45
        case .magnesium: return 60
        case .ashwagandha: return 120
        case .vitaminB: return 0
        case .rhodiola: return -30
        case .theacrine: return 0
        case .creatine: return 0
        case .alphaGPC: return -30
        case .lTyrosine: return -30
        case .psylliumHusk: return 0
        case .glycine: return 60 // 60 min before bed
        case .custom: return 0
        }
    }

    /// Requires lipid/fat for absorption (fat-soluble compounds)
    var requiresLipid: Bool {
        switch self {
        case .ashwagandha: return true
        case .glycine: return false
        default: return false
        }
    }

    /// Creatine is better absorbed when split into two doses
    var isSplitDoseRecommended: Bool {
        switch self {
        case .creatine: return true
        case .glycine: return false
        default: return false
        }
    }

    /// Blocks absorption of other compounds (e.g., fiber/psyllium)
    var isAbsorptionBlocker: Bool {
        switch self {
        case .glycine: return false
        default: return false
        }
    }

    /// Requires fasted state for optimal absorption (amino acids)
    var requiresFastedState: Bool {
        switch self {
        case .lTyrosine: return true
        case .glycine: return false
        default: return false
        }
    }

    var interactionType: NootropicInteractionType {
        switch self {
        case .caffeine: return .stimulant
        case .lTheanine: return .calming
        case .magnesium: return .absorptionInhibitor
        case .ashwagandha: return .cortisolModulator
        case .vitaminB: return .metabolismSupport
        case .rhodiola: return .stimulant
        case .theacrine: return .caffeineAlternative
        case .creatine: return .metabolismSupport
        case .alphaGPC: return .cognitiveEnhancer
        case .lTyrosine: return .stressBuffer
        case .psylliumHusk: return .absorptionInhibitor
        case .glycine: return .calming
        case .custom: return .metabolismSupport
        }
    }

    var elementalYieldFactor: Double {
        switch self {
        case .caffeine: return 1.0
        case .lTheanine: return 1.0
        case .magnesium: return 0.14
        case .ashwagandha: return 1.0
        case .vitaminB: return 1.0
        case .rhodiola: return 1.0
        case .theacrine: return 1.0
        case .creatine: return 1.0
        case .alphaGPC: return 0.40
        case .lTyrosine: return 1.0
        case .psylliumHusk: return 1.0
        case .glycine: return 1.0
        case .custom: return 1.0
        }
    }

    var elementalYieldDescription: String {
        switch self {
        case .caffeine: return "100% active compound"
        case .magnesium: return "Contains ~14% elemental magnesium (280mg per 2000mg compound)"
        case .alphaGPC: return "Contains ~40% choline by weight (120mg per 300mg compound)"
        case .glycine: return "100% active compound"
        default: return "100% active compound"
        }
    }

    var category: CompoundCategory {
        switch self {
        case .caffeine: return .stimulant
        case .lTheanine: return .depressant
        case .magnesium: return .depressant
        case .ashwagandha: return .depressant
        case .vitaminB: return .support
        case .rhodiola: return .stimulant
        case .theacrine: return .stimulant
        case .creatine: return .support
        case .alphaGPC: return .cognitive
        case .lTyrosine: return .support
        case .psylliumHusk: return .support
        case .glycine: return .depressant
        case .custom: return .support
        }
    }

    var intendedPurpose: String {
        switch self {
        case .caffeine: return "Alertness and focus"
        case .lTheanine: return "Calm focus, reduce jitters"
        case .magnesium: return "Sleep quality, muscle recovery"
        case .ashwagandha: return "Stress reduction, cortisol control"
        case .vitaminB: return "Energy metabolism"
        case .rhodiola: return "Endurance, fatigue resistance"
        case .theacrine: return "Sustained energy, no crash"
        case .creatine: return "Cognitive endurance, ATP support"
        case .alphaGPC: return "Memory, learning enhancement"
        case .lTyrosine: return "Stress resilience, dopamine support"
        case .psylliumHusk: return "Gut health, fiber intake"
        case .glycine: return "Deep Sleep & Core Temperature Regulation"
        case .custom: return "Custom supplement"
        }
    }

    var mechanismOfAction: String {
        switch self {
        case .caffeine: return "Adenosine receptor antagonist"
        case .lTheanine: return "Increases GABA, serotonin, dopamine"
        case .magnesium: return "NMDA receptor modulation, GABA agonist"
        case .ashwagandha: return "HPA axis modulation, cortisol reduction"
        case .vitaminB: return "Coenzyme in energy metabolism"
        case .rhodiola: return "MAO inhibition, adaptogenic"
        case .theacrine: return "Adenosine + dopamine receptor modulation"
        case .creatine: return "Phosphocreatine ATP regeneration"
        case .alphaGPC: return "Choline donor, increases acetylcholine"
        case .lTyrosine: return "Dopamine/norepinephrine precursor"
        case .psylliumHusk: return "Soluble fiber, gel formation in gut"
        case .glycine: return "NMDA co-agonist in SCN, triggers peripheral vasodilation"
        case .custom: return "Custom compound mechanism"
        }
    }

    var explanation: String {
        switch self {
        case .caffeine: return "Primary stimulant. Blocks adenosine to increase alertness. Best taken 90 min after waking to avoid afternoon crash."
        case .lTheanine: return "Amino acid found in green tea. Promotes relaxed alertness without sedation. Pairs synergistically with caffeine."
        case .magnesium: return "Essential mineral. Supports 300+ enzymatic reactions. Improves sleep architecture and reduces caffeine tolerance."
        case .ashwagandha: return "Adaptogenic herb. Reduces cortisol by up to 30%. Best taken consistently for cumulative stress-buffering effects."
        case .vitaminB: return "Water-soluble vitamins. Critical cofactors for neurotransmitter synthesis and cellular energy production."
        case .rhodiola: return "Adaptogenic herb. Inhibits MAO enzymes, extending catecholamine activity. Reduces perceived fatigue during stress."
        case .theacrine: return "Purine alkaloid similar to caffeine but with longer half-life and no tolerance buildup. Clean, sustained energy."
        case .creatine: return "Organic acid that regenerates ATP. Well-researched for physical performance; emerging evidence for cognitive benefits."
        case .alphaGPC: return "Choline compound that crosses the blood-brain barrier. Direct precursor to acetylcholine, the learning neurotransmitter."
        case .lTyrosine: return "Amino acid precursor to dopamine and norepinephrine. Most effective during acute stress when catecholamine stores deplete."
        case .psylliumHusk: return "Soluble fiber that forms a gel in the gut. Promotes satiety and gut motility but can bind to nutrients."
        case .glycine: return "Acts as NMDA co-agonist in the suprachiasmatic nucleus (SCN), triggering peripheral vasodilation "
             + "to drop core body temperature, accelerating sleep onset and deepening slow-wave sleep."
        case .custom: return "Custom supplement with user-defined properties."
        }
    }

    var hydrationOffsetMl: Double {
        switch self {
        case .caffeine: return 100
        case .creatine: return 200
        case .magnesium: return 50
        case .psylliumHusk: return 0
        case .custom: return 0
        default: return 0
        }
    }

    var colorForCompound: String {
        switch self {
        case .caffeine: return "orange"
        case .lTheanine: return "green"
        case .magnesium: return "blue"
        case .ashwagandha: return "purple"
        case .vitaminB: return "yellow"
        case .rhodiola: return "red"
        case .theacrine: return "teal"
        case .creatine: return "pink"
        case .alphaGPC: return "cyan"
        case .lTyrosine: return "brown"
        case .psylliumHusk: return "gray"
        case .glycine: return "lavender"
        case .custom: return "black"
        }
    }
}

// MARK: - Warnings & Contraindications

enum WarningLevel: String {
    case none, low, medium, high
}

extension NootropicCompound {
    var sideEffectWarnings: [String] {
        switch self {
        case .lTheanine:
            return ["May cause drowsiness when taken alone", "May cause sleep at high doses"]
        case .creatine:
            return ["Requires loading phase (20g/day for 5-7 days)", "Take with food to avoid GI issues"]
        case .magnesium:
            return ["May cause loose stools at high doses", "Best taken in evening"]
        case .ashwagandha:
            return ["May cause drowsiness", "May affect thyroid function"]
        case .rhodiola:
            return ["May cause vivid dreams", "Avoid if prone to anxiety"]
        case .caffeine:
            return ["May cause jitters", "Can disrupt sleep if late", "Tolerance develops with daily use"]
        case .alphaGPC:
            return ["May cause vivid dreams", "May cause headaches"]
        case .psylliumHusk:
            return ["Take with plenty of water", "May cause bloating initially"]
        case .lTyrosine:
            return ["Do not take with food", "May cause headaches at high doses"]
        default:
            return []
        }
    }

    var contraindications: [NootropicCompound]? {
        switch self {
        case .psylliumHusk:
            return [.magnesium, .creatine]
        default:
            return nil
        }
    }

    var warningLevel: WarningLevel {
        switch self {
        case .caffeine, .lTyrosine: return .medium
        case .ashwagandha: return .low
        default: return .none
        }
    }
}
