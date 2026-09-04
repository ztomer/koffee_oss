import Foundation
import Darwin

/// Pharmacokinetic Engine implementing true Michaelis-Menten kinetics for caffeine metabolism.
///
/// ## Algorithm Overview
/// Caffeine elimination follows **Michaelis-Menten kinetics** rather than simple first-order decay:
/// ```
/// dC/dt = (-Vmax * C) / (Km + C)
/// ```
/// Where:
/// - `C` = plasma concentration (mg/L)
/// - `Km` = 150 mg/L (concentration at half Vmax)
/// - `Vmax` = 50 mg/hour (maximum elimination rate)
///
/// At high concentrations, elimination is zero-order (constant rate).
/// At low concentrations, it approaches first-order (proportional to concentration).
/// This is more accurate than a fixed half-life model.
///
/// ## Volume of Distribution
/// Uses the **Watson Formula** to calculate Total Body Water (TBW), which approximates
/// caffeine's volume of distribution since caffeine is both hydrophilic and lipophilic.
///
/// ## Iteration
/// Decay is computed in 5-minute steps for accuracy, iterating from dose time to query time.
protocol MetabolismEngineProtocol {
    func calculateLevel(at time: Date, for doses: [(time: Date, mg: Double, delivery: DeliveryMethod)]) -> Double
    func calculateLevel(at time: Date, for doses: [(time: Date, mg: Double, delivery: DeliveryMethod)], interventions: [BiologicalIntervention]) -> Double
    func calculateHalfLife(dose: Double) -> Double
    func generateCurve(from startTime: Date, to endTime: Date,
                       doses: [(time: Date, mg: Double, delivery: DeliveryMethod)],
                       interventions: [BiologicalIntervention]) -> [PKCurvePoint]
    func calculateRiskLevel(currentLevel: Double, bedtimeLevel: Double) -> RiskLevel
}

/// Pharmacokinetic Engine implementing true Michaelis-Menten kinetics
/// Uses Volume of Distribution (Vd) calculated from Watson Formula for TBW
final class PharmacokineticEngine: MetabolismEngineProtocol {
    // MARK: - User Parameters
    private let age: Int
    private let heightCm: Double
    private let weightKg: Double
    private let biologicalSex: String
    private let metabolism: MetabolismRate
    private let sensitivity: Sensitivity

    // MARK: - Michaelis-Menten Parameters
    private let michaelisConstantKm: Double = 150.0  // mg/L - concentration at half Vmax
    private let maxEliminationRateVmax: Double = 50.0  // mg/hour - maximum elimination rate

    init(age: Int, heightCm: Double, weightKg: Double, biologicalSex: String, metabolism: MetabolismRate, sensitivity: Sensitivity) {
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.biologicalSex = biologicalSex
        self.metabolism = metabolism
        self.sensitivity = sensitivity
    }

    /// Calculates Total Body Water (TBW) using the Watson Formula
    /// For males: TBW = 2.447 - 0.09156*age + 0.1074*height + 0.3362*weight
    /// For females: TBW = -2.097 + 0.1069*height + 0.2466*weight
    /// Returns TBW in liters. Caffeine Vd ≈ TBW since it's hydrophilic and lipophilic.
    func calculateVolumeOfDistribution() -> Double {
        let tbw: Double
        let sexLower = biologicalSex.lowercased()

        if sexLower.contains("male") || sexLower == "m" {
            tbw = 2.447 - (0.09156 * Double(age)) + (0.1074 * heightCm) + (0.3362 * weightKg)
        } else {
            tbw = -2.097 + (0.1069 * heightCm) + (0.2466 * weightKg)
        }

        // Ensure positive and reasonable (minimum 20L for very small persons)
        return max(tbw, 20.0)
    }

    /// Converts absolute dose (mg) to plasma concentration (mg/L)
    /// C = Dose / Vd
    func concentrationFromDose(_ doseMg: Double) -> Double {
        let vd = calculateVolumeOfDistribution()
        return doseMg / vd
    }

    /// Calculates caffeine level at given time using iterative Michaelis-Menten decay
    /// dC/dt = (-Vmax * C) / (Km + C)
    /// Iterates in 5-minute steps for accuracy
    func calculateLevel(at time: Date, for doses: [(time: Date, mg: Double, delivery: DeliveryMethod)]) -> Double {
        guard !doses.isEmpty else { return 0 }

        var totalConcentration: Double = 0.0
        let stepMinutes = 5.0
        let vd = calculateVolumeOfDistribution()

        for dose in doses {
            guard dose.time <= time else { continue }

            let peakOffset = dose.delivery.peakOffsetMinutes
            let hoursElapsed = time.timeIntervalSince(dose.time) / 3600
            let effectivePeakHours = peakOffset / 60.0

            // Absorption phase: rise to Cmax
            if hoursElapsed < effectivePeakHours {
                let riseProgress = hoursElapsed / effectivePeakHours
                let absorbedDose = dose.mg * dose.delivery.absorptionRate * min(riseProgress, 1.0)
                totalConcentration += absorbedDose / vd
            } else {
                // Post-absorption: iterative Michaelis-Menten decay
                let timeSincePeak = hoursElapsed - effectivePeakHours
                let doseConcentration = (dose.mg * dose.delivery.absorptionRate) / vd

                let decayedConcentration = iterativeDecay(
                    initialConcentration: doseConcentration,
                    timeHours: timeSincePeak,
                    stepMinutes: stepMinutes
                )

                totalConcentration += decayedConcentration
            }
        }

        // Convert back to mg from concentration
        return totalConcentration * vd
    }

    /// Calculates caffeine level with dynamic Vmax based on exercise interventions
    func calculateLevel(at time: Date,
                        for doses: [(time: Date, mg: Double, delivery: DeliveryMethod)],
                        interventions: [BiologicalIntervention] = []) -> Double {
        guard !doses.isEmpty else { return 0 }

        var totalConcentration: Double = 0.0
        let stepMinutes = 5.0
        let vd = calculateVolumeOfDistribution()

        for dose in doses {
            guard dose.time <= time else { continue }

            let peakOffset = dose.delivery.peakOffsetMinutes
            let hoursElapsed = time.timeIntervalSince(dose.time) / 3600
            let effectivePeakHours = peakOffset / 60.0

            // Absorption phase: rise to Cmax
            if hoursElapsed < effectivePeakHours {
                let riseProgress = hoursElapsed / effectivePeakHours
                let absorbedDose = dose.mg * dose.delivery.absorptionRate * min(riseProgress, 1.0)
                totalConcentration += absorbedDose / vd
            } else {
                // Post-absorption: iterative Michaelis-Menten decay with dynamic Vmax
                let timeSincePeak = hoursElapsed - effectivePeakHours
                let doseConcentration = (dose.mg * dose.delivery.absorptionRate) / vd

                let decayedConcentration = iterativeDecayWithExercise(
                    initialConcentration: doseConcentration,
                    timeHours: timeSincePeak,
                    stepMinutes: stepMinutes,
                    doseTime: dose.time,
                    interventions: interventions
                )

                totalConcentration += decayedConcentration
            }
        }

        // Convert back to mg from concentration
        return totalConcentration * vd
    }

    /// Iterative Michaelis-Menten decay with dynamic Vmax based on exercise interventions
    private func iterativeDecayWithExercise(
        initialConcentration: Double,
        timeHours: Double,
        stepMinutes: Double,
        doseTime: Date,
        interventions: [BiologicalIntervention]
    ) -> Double {
        var concentration = initialConcentration
        let baseVmax = maxEliminationRateVmax / metabolism.halfLifeMultiplier
        let stepHours = stepMinutes / 60.0
        let steps = Int(timeHours / stepHours)

        for stepIndex in 0..<steps {
            let currentStepTime = doseTime.addingTimeInterval(Double(stepIndex) * stepMinutes * 60)

            // Calculate current Vmax based on exercise interventions
            var currentVmax = baseVmax

            // Find any exercise interventions active at this time
            for intervention in interventions where intervention.type == .exercise {
                let exerciseStart = intervention.scheduledTime
                let exerciseEnd = exerciseStart.addingTimeInterval(Double(intervention.durationMinutes ?? 30) * 60)

                if currentStepTime >= exerciseStart && currentStepTime < exerciseEnd {
                    // Apply exercise-based Vmax modification
                    if intervention.maintainsHepaticPerfusion {
                        // Zone 2, walking, yoga - increases circulation
                        currentVmax *= 1.15
                    } else {
                        // HIIT, heavy lifting - blood shunted to muscles, reduces clearance
                        currentVmax *= 0.2
                    }
                    break // Only one exercise can be active at a time
                }
            }

            // Michaelis-Menten: rate = (Vmax * C) / (Km + C)
            let rate = (currentVmax * concentration) / (michaelisConstantKm + concentration)
            let change = rate * stepHours
            concentration = max(0, concentration - change)
        }

        return concentration
    }

    /// Iterative Michaelis-Menten decay calculation
    /// dC/dt = (-Vmax * C) / (Km + C)
    /// Uses 5-minute steps for numerical accuracy
    private func iterativeDecay(initialConcentration: Double, timeHours: Double, stepMinutes: Double) -> Double {
        var concentration = initialConcentration
        let adjustedVmax = maxEliminationRateVmax / metabolism.halfLifeMultiplier
        let stepHours = stepMinutes / 60.0
        let steps = Int(timeHours / stepHours)

        for _ in 0..<steps {
            // Michaelis-Menten: rate = (Vmax * C) / (Km + C)
            let rate = (adjustedVmax * concentration) / (michaelisConstantKm + concentration)
            let change = rate * stepHours
            concentration = max(0, concentration - change)
        }

        return concentration
    }

    func calculateHalfLife(dose: Double) -> Double {
        let concentration = concentrationFromDose(dose)

        // At low concentrations, first-order: t1/2 = ln(2) * Km / Vmax
        // At high concentrations (saturation): approaches Vmax/Km (zero-order)
        let firstOrderHalfLife = (0.6931471805599453 * michaelisConstantKm) / maxEliminationRateVmax

        // Adjust for metabolism
        let metabolismAdjusted = firstOrderHalfLife / metabolism.halfLifeMultiplier

        // For very high doses, half-life extends due to saturation
        if concentration > michaelisConstantKm {
            return metabolismAdjusted * 1.5
        }

        return metabolismAdjusted
    }

    func generateCurve(from startTime: Date, to endTime: Date,
                       doses: [(time: Date, mg: Double, delivery: DeliveryMethod)],
                       interventions: [BiologicalIntervention] = []) -> [PKCurvePoint] {
        var points: [PKCurvePoint] = []
        var currentTime = startTime

        while currentTime <= endTime {
            let level = calculateLevel(at: currentTime, for: doses, interventions: interventions)
            let totalDose = doses.reduce(0) { $0 + $1.mg }
            let confidence = calculateConfidenceBand(level: level, dose: totalDose, timeHours: currentTime.timeIntervalSince(startTime) / 3600)

            points.append(PKCurvePoint(
                time: currentTime,
                expected: level,
                upper: level + confidence,
                lower: max(0, level - confidence)
            ))

            currentTime = currentTime.addingTimeInterval(1800)
        }

        return points
    }

    func calculateRiskLevel(currentLevel: Double, bedtimeLevel: Double) -> RiskLevel {
        let safeLimit = sensitivity.safeCaffeineAtBedtime

        if bedtimeLevel > safeLimit * 1.5 || currentLevel > safeLimit * 2 {
            return .critical
        } else if bedtimeLevel > safeLimit || currentLevel > safeLimit * 1.5 {
            return .high
        } else if bedtimeLevel > safeLimit * 0.5 {
            return .medium
        } else {
            return .low
        }
    }

    private func calculateConfidenceBand(level: Double, dose: Double, timeHours: Double) -> Double {
        let baseVariance = 0.2
        let doseVariance = min(dose / 500.0, 0.3)
        let timeDecay = max(0.5, 1.0 - (timeHours / 24.0))
        return level * (baseVariance + doseVariance) * timeDecay * 0.15
    }
}

extension PharmacokineticEngine {
    /// Factory method to create engine from individual user parameters
    static func create(
        age: Int,
        heightCm: Double,
        weightKg: Double,
        biologicalSex: String,
        metabolism: MetabolismRate,
        sensitivity: Sensitivity
    ) -> PharmacokineticEngine {
        return PharmacokineticEngine(
            age: age,
            heightCm: heightCm,
            weightKg: weightKg,
            biologicalSex: biologicalSex,
            metabolism: metabolism,
            sensitivity: sensitivity
        )
    }
}

// MARK: - Risk Analyzer

class RiskAnalyzer {
    private let sensitivity: Sensitivity
    private let weightKg: Double

    init(sensitivity: Sensitivity, weightKg: Double) {
        self.sensitivity = sensitivity
        self.weightKg = weightKg
    }

    func analyze(
        currentLevel: Double,
        bedtimeLevel: Double,
        dailyTotal: Double
    ) -> (risk: RiskLevel, warnings: [WarningType], suggestions: [String]) {
        var warnings: [WarningType] = []
        var suggestions: [String] = []

        let safeLimit = sensitivity.safeCaffeineAtBedtime
        let dailyLimit = sensitivity.multiplier * 400
        let mgPerKg = weightKg > 0 ? dailyTotal / weightKg : 0

        let risk: RiskLevel
        if bedtimeLevel > safeLimit * 1.5 || mgPerKg > 8 || dailyTotal > dailyLimit {
            risk = .critical
            warnings.append(.approachingLimit)
            suggestions.append("Critical: Reduce caffeine intake immediately")
        } else if bedtimeLevel > safeLimit || mgPerKg > 6 || dailyTotal > dailyLimit * 0.9 {
            risk = .high
            warnings.append(.excessiveCaffeine)
            suggestions.append("Consider reducing by 25%")
        } else if bedtimeLevel > safeLimit * 0.5 || mgPerKg > 4 || dailyTotal > dailyLimit * 0.7 {
            risk = .medium
            suggestions.append("Monitor your intake")
        } else {
            risk = .low
        }

        if mgPerKg > 6 {
            warnings.append(.caffeinePerKgWarning)
            suggestions.append("Your dose (\(Int(mgPerKg))mg/kg) exceeds recommended limit")
        }

        return (risk, warnings, suggestions)
    }
}

// MARK: - Caffeine Calculator Compatibility Layer

extension PharmacokineticEngine {
    /// Calculate caffeine level at bedtime - for backward compatibility
    static let caffeineHalfLifeHours: Double = 5.0

    static func calculateCaffeineAtBedtime(doses: [Dose], wakeTime: Date, sleepTime: Date) -> Double {
        var adjustedSleepTime = sleepTime
        if sleepTime <= wakeTime {
            adjustedSleepTime = Calendar.current.date(byAdding: .day, value: 1, to: sleepTime) ?? sleepTime
        }

        var adjustedDoses: [(Date, Double)] = []
        for dose in doses {
            guard let doseTime = dose.time, dose.amount > 0 else { continue }
            var adjustedDoseTime = doseTime
            if doseTime <= wakeTime {
                adjustedDoseTime = Calendar.current.date(byAdding: .day, value: 1, to: doseTime) ?? doseTime
            }
            adjustedDoses.append((adjustedDoseTime, dose.amount))
        }

        return calculateCaffeineAtTime(doses: adjustedDoses, targetTime: adjustedSleepTime)
    }

    static func calculateCaffeineAtTime(doses: [(Date, Double)], targetTime: Date) -> Double {
        var total: Double = 0.0
        for (doseTime, amount) in doses {
            guard doseTime <= targetTime else { continue }
            let hoursElapsed = targetTime.timeIntervalSince(doseTime) / 3600
            let remaining = amount * pow(0.5, hoursElapsed / caffeineHalfLifeHours)
            total += remaining
        }
        return total
    }
}
