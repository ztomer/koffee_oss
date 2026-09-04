import Foundation

struct HydrationRequirement {
    let baseWaterMl: Double
    let pillWaterMl: Double
    let diureticOffsetMl: Double
    let compoundOffsetMl: Double
    let totalMl: Double
    let loggedMl: Double
    var deficitMl: Double { max(0, totalMl - loggedMl) }

    var formatted: String {
        let total = Int(totalMl)
        return "\(total)ml"
    }

    var deficitFormatted: String {
        let deficit = Int(deficitMl)
        return "\(deficit)ml"
    }

    var breakdown: String {
        var parts: [String] = []
        parts.append("Base: \(Int(baseWaterMl))ml")
        if pillWaterMl > 0 {
            parts.append("Pills: +\(Int(pillWaterMl))ml")
        }
        if diureticOffsetMl > 0 {
            parts.append("Caffeine: +\(Int(diureticOffsetMl))ml")
        }
        if compoundOffsetMl > 0 {
            parts.append("Compounds: +\(Int(compoundOffsetMl))ml")
        }
        if loggedMl > 0 {
            parts.append("Logged: -\(Int(loggedMl))ml")
        }
        return parts.joined(separator: " ")
    }
}

/// Hydration Calculator with tolerance-adjusted diuresis
/// If daysSinceReset < 3: full 100ml per 100mg penalty (naive user)
/// If daysSinceReset >= 3: reduced 15ml per 100mg (habitual user adaptation)
class HydrationCalculator {
    static let waterPerPillMl = 50.0

    // Diuretic penalty rates
    static let naiveDiureticOffsetMlPer100mg = 100.0  // Full penalty for new users
    static let habitualDiureticOffsetMlPer100mg = 15.0  // Adapted users

    /// Calculate hydration requirement based on tolerance cycle
    /// - Parameter tolerance: The user's tolerance cycle (days since last reset)
    static func calculate(
        pillCount: Int,
        activeCaffeineMg: Double,
        tolerance: ToleranceCycle,
        compounds: [NootropicCompound] = [],
        loggedEntries: [HydrationEntryModel] = []
    ) -> HydrationRequirement {
        let baseWaterMl = 2000.0
        let pillWaterMl = Double(pillCount) * waterPerPillMl

        // Tolerance-adjusted diuretic offset
        let diureticRate = toleranceAdjustedDiureticRate(daysSinceReset: tolerance.daysSinceReset)
        let diureticOffsetMl = (activeCaffeineMg / 100.0) * diureticRate

        let compoundOffsetMl = compounds.reduce(0) { $0 + $1.hydrationOffsetMl }
        let loggedMl = loggedEntries.reduce(0) { $0 + $1.amountMl }
        let totalMl = baseWaterMl + pillWaterMl + diureticOffsetMl + compoundOffsetMl

        return HydrationRequirement(
            baseWaterMl: baseWaterMl,
            pillWaterMl: pillWaterMl,
            diureticOffsetMl: diureticOffsetMl,
            compoundOffsetMl: compoundOffsetMl,
            totalMl: totalMl,
            loggedMl: loggedMl
        )
    }

    /// Calculate tolerance-adjusted diuretic rate
    /// Naive users (<3 days): full penalty (100ml/100mg)
    /// Habitual users (>=3 days): adapted penalty (15ml/100mg)
    private static func toleranceAdjustedDiureticRate(daysSinceReset: Int) -> Double {
        if daysSinceReset < 3 {
            // Naive user - full diuretic effect
            return naiveDiureticOffsetMlPer100mg
        } else {
            // Habitual user - body has adapted
            return habitualDiureticOffsetMlPer100mg
        }
    }

    /// Calculate hydration for compounds
    static func calculateForCompounds(
        compounds: [(compound: NootropicCompound, doseMg: Double)],
        activeCaffeineMg: Double,
        tolerance: ToleranceCycle,
        loggedEntries: [HydrationEntryModel] = []
    ) -> HydrationRequirement {
        let pillCount = compounds.count
        let theacrine = compounds.filter { $0.compound == .theacrine }.reduce(0.0) { $0 + $1.doseMg }
        let caffeine = activeCaffeineMg + theacrine
        let compoundTypes = compounds.map { $0.compound }

        return calculate(
            pillCount: pillCount,
            activeCaffeineMg: caffeine,
            tolerance: tolerance,
            compounds: compoundTypes,
            loggedEntries: loggedEntries
        )
    }

    /// Get hydration recommendation string
    static func recommendation(requirement: HydrationRequirement) -> String {
        if requirement.deficitMl <= 0 {
            return "Hydration target met! Well done."
        }

        if requirement.deficitMl > 500 {
            return "Significant deficit: Drink \(requirement.deficitFormatted) to reach target."
        }

        if requirement.deficitMl > 250 {
            return "Drink \(requirement.deficitFormatted) more. Consider two 250ml glasses."
        }

        return "Almost there! Just \(requirement.deficitFormatted) remaining."
    }

    /// Get recommendation with tolerance context
    static func recommendation(pillCount: Int, activeCaffeineMg: Double, tolerance: ToleranceCycle) -> String {
        let req = calculate(pillCount: pillCount, activeCaffeineMg: activeCaffeineMg, tolerance: tolerance)

        if pillCount == 0 && activeCaffeineMg == 0 {
            return "No hydration supplements needed. Drink normally."
        }

        let toleranceStatus = tolerance.daysSinceReset < 3 ? "new user" : "habitual user"

        if activeCaffeineMg > 200 {
            return "High caffeine (\(Int(activeCaffeineMg))mg, \(toleranceStatus)): Add \(Int(req.diureticOffsetMl))ml water to offset. \(req.formatted) total."
        }

        if pillCount > 3 {
            return "Taking \(pillCount) supplements: Add \(Int(req.pillWaterMl))ml for absorption. \(req.formatted) total."
        }

        return "Base: \(Int(req.baseWaterMl))ml + \(Int(req.pillWaterMl + req.diureticOffsetMl))ml = \(req.formatted)"
    }
}

// MARK: - Chart Normalizer
/// Converts absolute compound levels (mg) to normalized percentages (0-100%) of safe limits.
///
/// ## Algorithm
/// For each compound at each time point:
/// 1. Look up the safe limit (e.g., 400mg for caffeine, optimal dose for supplements)
/// 2. Calculate percentage: `(mgValue / safeLimit) * 100`
/// 3. Cap at 100% to prevent overflow in the chart
/// 4. Sum all normalized levels for total stack intensity
///
/// The normalized values are used by `UnifiedChartView` to render the multi-compound curve.
/// Note: the chart's y-axis extends above 100% if needed to show all data.
struct NormalizedCurvePoint: Identifiable {
    let id = UUID()
    let time: Date
    let compoundLevels: [String: Double]
    let totalLevel: Double

    func level(for compound: String) -> Double {
        compoundLevels[compound] ?? 0.0
    }
}

class ChartNormalizer {
    private static let stimulantCompounds: Set<String> = [
        NootropicCompound.caffeine.rawValue,
        NootropicCompound.theacrine.rawValue,
        NootropicCompound.rhodiola.rawValue,
        NootropicCompound.lTyrosine.rawValue,
        NootropicCompound.alphaGPC.rawValue
    ]

    static func normalize(
        _ points: [UnifiedCurvePoint],
        safeLimits: [String: Double]
    ) -> [NormalizedCurvePoint] {
        return points.map { point in
            var normalizedLevels: [String: Double] = [:]

            for (compound, mgValue) in point.compoundLevels {
                let safeLimit = safeLimits[compound] ?? 400.0
                let percentage = (mgValue / safeLimit) * 100.0
                normalizedLevels[compound] = max(0.0, percentage)
            }

            // Sum only CNS-active (stimulant) compounds, not all supplements
            // Creatine, Magnesium, Glycine, etc. are not CNS stimulants
            let totalNormalized = normalizedLevels.compactMap { (compound, level) -> Double? in
                guard stimulantCompounds.contains(compound) else { return nil }
                return level
            }.reduce(0, +)

            return NormalizedCurvePoint(
                time: point.time,
                compoundLevels: normalizedLevels,
                totalLevel: totalNormalized
            )
        }
    }

    static func normalizeToPercentage(mg: Double, maxMg: Double) -> Double {
        guard maxMg > 0 else { return 0 }
        return min(mg / maxMg, 1.0)
    }

    static func calculateNormalizedLevel(
        currentMg: Double,
        compound: NootropicCompound,
        doseMg: Double,
        deliveryMethod: DeliveryMethod
    ) -> Double {
        let elementalDose = doseMg * compound.elementalYieldFactor
        let cmax = elementalDose * deliveryMethod.absorptionRate
        guard cmax > 0 else { return 0 }
        return min(currentMg / cmax, 1.0)
    }
}

struct NormalizedDataPoint: Identifiable {
    let id = UUID()
    let time: Date
    let levels: [String: Double]

    func level(for compound: String) -> Double {
        levels[compound] ?? 0
    }
}
