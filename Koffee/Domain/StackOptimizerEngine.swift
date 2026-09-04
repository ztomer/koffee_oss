import Foundation

// MARK: - Actionable Recommendations

struct ActionableRecommendation: Identifiable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let message: String
    let priority: Int
    let scheduledTime: Date?
    let splitDoseCount: Int  // Number of split doses (e.g., 2 for 5000mg -> 2x2500mg)
    let recommendedDoseMg: Double?  // The dose recommended by the optimizer (if specified)

    init(type: RecommendationType, title: String, message: String, priority: Int,
         scheduledTime: Date?, splitDoseCount: Int = 1, recommendedDoseMg: Double? = nil) {
        self.type = type
        self.title = title
        self.message = message
        self.priority = priority
        self.scheduledTime = scheduledTime
        self.splitDoseCount = splitDoseCount
        self.recommendedDoseMg = recommendedDoseMg
    }

    // Raw values are display prefixes (notifications, recommendation rows).
    // House glyph policy: no decorative emoji - plain word prefixes.
    enum RecommendationType: String {
        case hydrate = "Hydrate"
        case takeCompound = "Take"
        case replaceCompound = "Swap"
        case avoidCompound = "Avoid"
        case caffeineCutoff = "Cutoff"
        case sleepPrep = "Sleep"
        case exercise = "Move"
    }
}

// MARK: - Physical Activity Types for Exercise Physiology

enum PhysicalActivityType: String, CaseIterable, Codable {
    case hiit = "HIIT"
    case zone2Cardio = "Zone 2 Cardio"
    case parasympatheticWalk = "Parasympathetic Walk"
    case strengthTraining = "Strength Training"
    case yoga = "Yoga"
    case stretching = "Stretching"

    /// Returns true if this activity maintains or improves hepatic blood flow
    /// HIIT shunts blood away from liver (reduces clearance)
    /// Zone 2 cardio and walks maintain/improve hepatic perfusion
    var maintainsHepaticPerfusion: Bool {
        switch self {
        case .hiit:
            return false  // Blood shunted to muscles, away from liver
        case .zone2Cardio, .parasympatheticWalk, .yoga, .stretching:
            return true  // Gentle movement maintains liver blood flow
        case .strengthTraining:
            return true  // Moderate, not intense enough to shunt
        }
    }

    /// Intensity factor for clearance calculation
    /// >1.0 = enhanced clearance, <1.0 = reduced clearance
    var clearanceMultiplier: Double {
        switch self {
        case .hiit:
            return 0.3  // Significantly reduces hepatic perfusion
        case .zone2Cardio:
            return 1.2  // Slightly enhances via improved circulation
        case .parasympatheticWalk:
            return 1.1  // Parasympathetic state aids liver function
        case .strengthTraining:
            return 0.8  // Moderate reduction during strain
        case .yoga, .stretching:
            return 1.0  // No significant effect
        }
    }
}

// MARK: - Stack Optimizer Engine with Neuroscience-Based Recommendations

class StackOptimizerEngine {
    private let goal: OptimizationGoal

    init(goal: OptimizationGoal) {
        self.goal = goal
    }

    /// Generate recommendations based on neuroscience and longevity protocols
    /// Implements:
    /// - Rule 1: 90-Minute Adenosine Clearance
    /// - Rule 2: Dynamic L-Theanine Ratio (1.5:1)
    /// - Rule 3: Circadian Adaptogen Placement (Ashwagandha after 2pm)
    /// - Rule 4: Creatine/Caffeine Interference
    /// - Rule 5: Magnesium Specificity for Sleep
    /// - Rule 9: Fiber Firewall (Absorption Blocker)
    /// - Rule 10: Amino Acid Transporter Competition
    /// - Rule 11: Recovery Penalty (Closed-Loop Feedback)
    /// - Rule 12: Deep Sleep Enhancer
    /// - Rule 13: ATP Fatigue Buffer
    /// - Rule 14: Shutdown Synergist
    func generateRecommendations(
        activeCaffeineMg: Double,
        currentDayInterventions: [BiologicalIntervention],
        wakeTime: Date,
        sleepTime: Date,
        hydrationDeficitMl: Double,
        hoursUntilBedtime: Double,
        tolerance: ToleranceCycle,
        biometrics: DailyBiometricsModel?
    ) -> [ActionableRecommendation] {
        var recommendations: [ActionableRecommendation] = []

        let currentStack = currentDayInterventions.compactMap { intervention -> NootropicCompound? in
            if intervention.type == .supplement, let compound = NootropicCompound(rawValue: intervention.name) {
                return compound
            }
            return nil
        }

        // Rule 11: Recovery Penalty (Closed-Loop Feedback)
        if let bio = biometrics, let sleepScore = bio.sleepScore, sleepScore < 70 {
            _ = activeCaffeineMg * 0.7
            let extendedDelay = wakeTime.addingTimeInterval(120 * 60)

            recommendations.append(ActionableRecommendation(
                type: .avoidCompound,
                title: "Recovery Penalty Applied",
                message: "Poor Recovery Detected (Sleep Score: \(Int(sleepScore))). Your nervous system is highly sensitized "
                    + "today. Reduce your total caffeine limit by 30% and extend your morning adenosine delay to 120 minutes.",
                priority: 1,
                scheduledTime: extendedDelay
            ))
        }

        // Rule 12: Deep Sleep Enhancer
        // If deep sleep < 60 min and no Glycine in stack, recommend Glycine
        if let bio = biometrics, let deepSleep = bio.deepSleepMinutes, deepSleep < 60 && !currentStack.contains(.glycine) {
            recommendations.append(ActionableRecommendation(
                type: .takeCompound,
                title: "Deep Sleep Enhancer",
                message: "Your deep sleep is only \(deepSleep) minutes. Take 3g of Glycine 60 min before bed to trigger "
                    + "peripheral vasodilation and drop core body temperature, deepening slow-wave sleep.",
                priority: 2,
                scheduledTime: sleepTime.addingTimeInterval(-60 * 60)
            ))
        }

        // Rule 13: ATP Fatigue Buffer
        // If sleep score < 65 and Creatine in stack, bump to 10g (2x5g split)
        if let bio = biometrics, let sleepScore = bio.sleepScore, sleepScore < 65 && currentStack.contains(.creatine) {
            let hasMorningCreatine = currentDayInterventions.contains { $0.name == "Creatine" && $0.scheduledTime < wakeTime.addingTimeInterval(4 * 3600) }
            if hasMorningCreatine {
                recommendations.append(ActionableRecommendation(
                    type: .replaceCompound,
                    title: "Acute Fatigue Buffer",
                    message: "Low sleep score (\(Int(sleepScore))) + Creatine detected. Increase daily Creatine to 10g "
                        + "(split into 2x5g) for ATP buffer against accumulated fatigue.",
                    priority: 2,
                    scheduledTime: wakeTime.addingTimeInterval(3600),
                    splitDoseCount: 2,
                    recommendedDoseMg: 2500  // 2.5g per dose = 5g total (half of base 5g for split dosing)
                ))
            }
        }

        // Rule 14: Shutdown Synergist
        // Group Magnesium + L-Theanine if hoursUntilBedtime < 2
        if hoursUntilBedtime < 2 && currentStack.contains(.magnesium) && !currentStack.contains(.lTheanine) {
            recommendations.append(ActionableRecommendation(
                type: .takeCompound,
                title: "Shutdown Synergist",
                message: "Take 200mg of L-Theanine with your Magnesium. This combo activates GABA pathways for synergistic relaxation and deeper sleep onset.",
                priority: 3,
                scheduledTime: Date()
            ))
        }

        recommendations.append(contentsOf: generateCompoundRules(
            activeCaffeineMg: activeCaffeineMg,
            currentDayInterventions: currentDayInterventions,
            currentStack: currentStack,
            wakeTime: wakeTime,
            sleepTime: sleepTime,
            hoursUntilBedtime: hoursUntilBedtime,
            hydrationDeficitMl: hydrationDeficitMl
        ))

        return recommendations.sorted { $0.priority < $1.priority }
    }

    /// Compound-timing and interaction rules plus exercise clearance advice
    /// (Rules 1-10). Split from generateRecommendations to keep each rule
    /// list readable; appends to the shared recommendation list.
    private func generateCompoundRules(
        activeCaffeineMg: Double,
        currentDayInterventions: [BiologicalIntervention],
        currentStack: [NootropicCompound],
        wakeTime: Date,
        sleepTime: Date,
        hoursUntilBedtime: Double,
        hydrationDeficitMl: Double
    ) -> [ActionableRecommendation] {
        var recommendations: [ActionableRecommendation] = []

        // Rule 1: 90-Minute Adenosine Clearance
        let minutesSinceWake = Date().timeIntervalSince(wakeTime) / 60
        if activeCaffeineMg > 0 && minutesSinceWake < 90 {
            recommendations.append(ActionableRecommendation(
                type: .avoidCompound,
                title: "Adenosine Clearance Delay",
                message: "Delay caffeine intake. You woke up less than 90 minutes ago. Allow natural morning cortisol to "
                    + "clear residual adenosine to prevent a severe afternoon crash.",
                priority: 1,
                scheduledTime: wakeTime.addingTimeInterval(90 * 60)
            ))
        }

        // Rule 2: Dynamic L-Theanine Ratio (1.5:1 caffeine ratio)
        if activeCaffeineMg > 0 && !currentStack.contains(.lTheanine) {
            let targetTheanine = activeCaffeineMg * 1.5
            recommendations.append(ActionableRecommendation(
                type: .takeCompound,
                title: "Optimal L-Theanine Ratio",
                message: "Based on your active caffeine load, take \(Int(targetTheanine))mg of L-Theanine. This 1.5:1 ratio "
                    + "is clinically proven to blunt sympathetic arousal and jitters while maintaining focus.",
                priority: 2,
                scheduledTime: Date().addingTimeInterval(300)
            ))
        }

        // Rule 3: Circadian Adaptogen Placement (Ashwagandha)
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        let isAfternoonOrEvening = currentHour >= 14  // After 2pm
        let hasHighCaffeine = activeCaffeineMg > 75

        if isAfternoonOrEvening && (goal == .deepSleep || hasHighCaffeine) {
            recommendations.append(ActionableRecommendation(
                type: .takeCompound,
                title: "Afternoon Cortisol Clearance",
                message: "Take 300mg of Ashwagandha KSM-66 now. This will begin lowering cortisol levels to counter your "
                    + "stimulant load and prepare your body for optimal evening wind-down.",
                priority: 3,
                scheduledTime: Date()
            ))
        }

        // Rule 4: Creatine / Caffeine Interference
        if currentStack.contains(.creatine) && activeCaffeineMg > 150 {
            recommendations.append(ActionableRecommendation(
                type: .avoidCompound,
                title: "Absorption Interference",
                message: "Separate your Creatine and high-dose Caffeine intake by at least 2 hours. Taking them simultaneously "
                    + "competes for absorption and increases gastrointestinal distress.",
                priority: 2,
                scheduledTime: Date()
            ))
        }

        // Rule 5: Magnesium Specificity (within 2 hours of bedtime)
        if hoursUntilBedtime < 2 && !currentStack.contains(.magnesium) {
            recommendations.append(ActionableRecommendation(
                type: .sleepPrep,
                title: "Targeted Magnesium",
                message: "Take 400mg of Magnesium Glycinate or L-Threonate for deep sleep. Avoid Citrate or Oxide forms, as "
                    + "they act as laxatives and do not effectively cross the blood-brain barrier.",
                priority: 3,
                scheduledTime: Date()
            ))
        }

        // Rule 6: Dopamine Replenishment (L-Tyrosine)
        let totalCaffeine = activeCaffeineMg // Could also include planned caffeine
        if totalCaffeine > 200 && !currentStack.contains(.lTyrosine) {
            recommendations.append(ActionableRecommendation(
                type: .takeCompound,
                title: "Dopamine Replenishment",
                message: "High stimulant load detected. Take 500mg of L-Tyrosine to replenish dopamine and norepinephrine "
                    + "precursors and prevent neurotransmitter burnout.",
                priority: 2,
                scheduledTime: Date().addingTimeInterval(1800)
            ))
        }

        // Rule 7: Split-Dosing Protocol (Creatine)
        if currentStack.contains(.creatine) {
            // Morning dose - 2.5g (half of 5g daily total)
            recommendations.append(ActionableRecommendation(
                type: .replaceCompound,
                title: "Creatine Dose 1 (Morning)",
                message: "Take 2.5g of Creatine. Splitting the 5g dose prevents GI distress and maximizes cellular uptake.",
                priority: 3,
                scheduledTime: wakeTime.addingTimeInterval(3600), // 1 hour after wake
                recommendedDoseMg: 2500  // Half of daily 5g dose
            ))
            // Afternoon dose (6 hours later) - 2.5g
            recommendations.append(ActionableRecommendation(
                type: .replaceCompound,
                title: "Creatine Dose 2 (Afternoon)",
                message: "Take 2.5g of Creatine (Second Dose). Complete your daily 5g allocation for optimal cognitive endurance.",
                priority: 3,
                scheduledTime: wakeTime.addingTimeInterval(7 * 3600), // 7 hours after wake
                recommendedDoseMg: 2500  // Half of daily 5g dose
            ))
        }

        // Rule 8: Bioavailability / Lipid Carrier Warning
        let fatSolubleCompounds = currentStack.filter { $0.requiresLipid }
        if !fatSolubleCompounds.isEmpty {
            let compoundNames = fatSolubleCompounds.map { $0.rawValue }.joined(separator: ", ")
            recommendations.append(ActionableRecommendation(
                type: .avoidCompound,
                title: "Bioavailability Warning",
                message: "Your stack contains fat-soluble compounds (\(compoundNames)). You MUST take this with a meal or a "
                    + "fat source (like fish oil or nuts) otherwise it will not be properly absorbed.",
                priority: 2,
                scheduledTime: Date()
            ))
        }

        recommendations.append(contentsOf: generateIntakeInteractionRules(
            activeCaffeineMg: activeCaffeineMg,
            currentDayInterventions: currentDayInterventions,
            hoursUntilBedtime: hoursUntilBedtime,
            hydrationDeficitMl: hydrationDeficitMl
        ))

        return recommendations
    }

    /// Data-collision and absorption rules (Rules 9-10) plus exercise
    /// clearance and hydration advice. Split from generateCompoundRules.
    private func generateIntakeInteractionRules(
        activeCaffeineMg: Double,
        currentDayInterventions: [BiologicalIntervention],
        hoursUntilBedtime: Double,
        hydrationDeficitMl: Double
    ) -> [ActionableRecommendation] {
        var recommendations: [ActionableRecommendation] = []

        // Rule 9: Fiber Firewall (Absorption Blocker)
        // Scan interventions for any absorption blockers and check for collisions
        let blockerInterventions = currentDayInterventions.filter { $0.isAbsorptionBlocker }
        for blocker in blockerInterventions {
            let collisionWindow: TimeInterval = 2 * 3600 // +/- 2 hours in seconds
            let collidingInterventions = currentDayInterventions.filter { intervention in
                guard intervention.id != blocker.id else { return false }
                let timeDiff = abs(intervention.scheduledTime.timeIntervalSince(blocker.scheduledTime))
                return timeDiff <= collisionWindow
            }

            if !collidingInterventions.isEmpty {
                let collidedNames = collidingInterventions.map { $0.name }.joined(separator: ", ")
                recommendations.append(ActionableRecommendation(
                    type: .avoidCompound,
                    title: "Fiber Firewall Alert",
                    message: "Fiber detected in \(blocker.name) will block absorption of \(collidedNames). Separate by at least 2 hours.",
                    priority: 1,
                    scheduledTime: blocker.scheduledTime
                ))
            }
        }

        // Rule 10: Amino Acid Transporter Competition
        // If requiresFastedState (like L-Tyrosine) and nutrition within 1 hour = competition
        let fastedInterventions = currentDayInterventions.filter { $0.requiresFastedState }
        for fasted in fastedInterventions {
            let competitionWindow: TimeInterval = 1 * 3600 // +/- 1 hour in seconds
            let nutritionCollisions = currentDayInterventions.filter { intervention in
                guard intervention.id != fasted.id else { return false }
                guard intervention.type == .nutrition else { return false }
                let timeDiff = abs(intervention.scheduledTime.timeIntervalSince(fasted.scheduledTime))
                return timeDiff <= competitionWindow
            }

            if !nutritionCollisions.isEmpty {
                let mealNames = nutritionCollisions.map { $0.name }.joined(separator: ", ")
                recommendations.append(ActionableRecommendation(
                    type: .avoidCompound,
                    title: "Transporter Competition",
                    message: "\(fasted.name) requires fasted state but conflicts with meals (\(mealNames)). "
                        + "Separate by at least 1 hour for optimal absorption.",
                    priority: 2,
                    scheduledTime: fasted.scheduledTime
                ))
            }
        }

        // Exercise physiology: clearance advice based on stimulant load
        let highStimulantLoad = activeCaffeineMg > 100
        let needsClearance = hoursUntilBedtime < 6 && activeCaffeineMg > 50

        if needsClearance {
            recommendations.append(contentsOf: exerciseClearanceRecommendations(
                highStimulantLoad: highStimulantLoad,
                hoursUntilBedtime: hoursUntilBedtime
            ))
        }

        // Hydration recommendations
        if hydrationDeficitMl > 100 {
            recommendations.append(ActionableRecommendation(
                type: .hydrate,
                title: "Hydration Deficit",
                message: "Drink \(Int(hydrationDeficitMl))ml to maintain cognitive performance. Dehydration reduces focus by up to 15%.",
                priority: 4,
                scheduledTime: Date()
            ))
        }

        // Caffeine cutoff warning
        if activeCaffeineMg > 25 && hoursUntilBedtime < 4 {
            recommendations.append(ActionableRecommendation(
                type: .caffeineCutoff,
                title: "Sleep Quality Warning",
                message: "\(Int(activeCaffeineMg))mg active caffeine with only \(Int(hoursUntilBedtime))h until bedtime. "
                    + "Consider tapering to protect sleep quality.",
                priority: 2,
                scheduledTime: Date()
            ))
        }

        return recommendations
    }

    /// Exercise recommendations for caffeine clearance
    /// HIIT: pauses hepatic clearance (reduced hepatic perfusion)
    /// Zone 2 / Parasympathetic: maintains/improves liver blood flow
    private func exerciseClearanceRecommendations(
        highStimulantLoad: Bool,
        hoursUntilBedtime: Double
    ) -> [ActionableRecommendation] {
        var recs: [ActionableRecommendation] = []

        if highStimulantLoad && hoursUntilBedtime < 6 {
            // HIGH STIMULANT LOAD + NEEDS SLEEP = AVOID HIIT
            recs.append(ActionableRecommendation(
                type: .exercise,
                title: "Avoid HIIT",
                message: "HIIT shunts blood away from liver, PAUSING caffeine clearance. With high stimulant load, choose gentler exercise.",
                priority: 5,
                scheduledTime: Date()
            ))

            recs.append(ActionableRecommendation(
                type: .exercise,
                title: "Try Zone 2 Cardio",
                message: "Zone 2 cardio maintains hepatic blood flow, helping clear caffeine. Aim for 30-45 min at conversational pace.",
                priority: 6,
                scheduledTime: Date().addingTimeInterval(1800)
            ))

            recs.append(ActionableRecommendation(
                type: .exercise,
                title: "Or Take a Walk",
                message: "A parasympathetic walk (20-30 min) activates rest-digest, supporting liver function and caffeine clearance.",
                priority: 7,
                scheduledTime: Date().addingTimeInterval(1800)
            ))
        } else if highStimulantLoad {
            recs.append(ActionableRecommendation(
                type: .exercise,
                title: "Consider Cardio",
                message: "Light cardio can help metabolize caffeine. Avoid intense exercise.",
                priority: 8,
                scheduledTime: nil
            ))
        }

        return recs
    }
}
