import Foundation

/// Caffeine is the only compound Koffee models. The former nootropic stack
/// (L-Theanine, Magnesium, Creatine, ...) was removed in the coffee-only strip.
enum NootropicCompound: String, CaseIterable, Identifiable {
    case caffeine = "Caffeine"

    var id: String { rawValue }

    var optimalDoseMg: Double { 95 }

    var safeLimitMg: Double { 400 }

    var peakTimeMinutes: Double { 45 }

    var halfLifeHours: Double { 5.0 }

    var synergyBenefit: String? { "Primary stimulant, increases alertness and focus" }

    var recommendedTimingMinutes: Double { 90 }

    /// Requires lipid/fat for absorption (fat-soluble compounds)
    var requiresLipid: Bool { false }

    /// Creatine is better absorbed when split into two doses
    var isSplitDoseRecommended: Bool { false }

    /// Blocks absorption of other compounds (e.g., fiber/psyllium)
    var isAbsorptionBlocker: Bool { false }

    /// Requires fasted state for optimal absorption (amino acids)
    var requiresFastedState: Bool { false }

    var elementalYieldFactor: Double { 1.0 }

    var elementalYieldDescription: String { "100% active compound" }

    var intendedPurpose: String { "Alertness and focus" }

    var mechanismOfAction: String { "Adenosine receptor antagonist" }

    var explanation: String {
        "Primary stimulant. Blocks adenosine to increase alertness. Best taken 90 min after waking to avoid afternoon crash."
    }

    var colorForCompound: String { "orange" }
}

// MARK: - Warnings & Contraindications

enum WarningLevel: String {
    case none, low, medium, high
}

extension NootropicCompound {
    var sideEffectWarnings: [String] {
        ["May cause jitters", "Can disrupt sleep if late", "Tolerance develops with daily use"]
    }

    var contraindications: [NootropicCompound]? { nil }

    var warningLevel: WarningLevel { .medium }
}
