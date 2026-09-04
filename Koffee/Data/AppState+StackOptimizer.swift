import Foundation
import Combine
import GRDB

@MainActor
extension AppState {
    // MARK: - Stack Optimizer
    // Public method to apply optimizations (called from UI)
    func applyOptimizations() {
        guard let profile = profile else { return }

        let optimizer = StackOptimizerEngine(goal: OptimizationGoal(rawValue: profile.optimizationGoal) ?? .balanced)

        let currentInterventions = todayInterventions
        let hoursUntilBedtime = profile.sleepTime.timeIntervalSince(Date()) / TimeConstants.secondsPerHour

        let recommendations = optimizer.generateRecommendations(
            activeCaffeineMg: 0,
            currentDayInterventions: currentInterventions,
            wakeTime: profile.wakeTime,
            sleepTime: profile.sleepTime,
            hydrationDeficitMl: 0,
            hoursUntilBedtime: hoursUntilBedtime,
            tolerance: ToleranceCycle(daysSinceReset: profile.toleranceDaysSinceReset, resetDaysRequired: profile.toleranceResetDaysRequired),
            biometrics: todayBiometrics
        )

        let dayKey = DailyPlanItemModel.dayKey(for: Date())

        // Get all replaceCompound recommendations upfront
        let replaceRecs = recommendations.filter { $0.type == .replaceCompound }

        debugLog("=== APPLY: Found \(replaceRecs.count) replaceCompound recommendations")
        for rec in replaceRecs {
            debugLog("=== APPLY: - \(rec.title), dose=\(rec.recommendedDoseMg ?? 0)")
        }

        // Mark ALL existing items for compounds with replaceCompound recommendations as optimizedAway
        // (instead of deleting them - we keep audit trail)
        let compoundsToReplace = Set(replaceRecs.map { extractCompoundName(from: $0).lowercased() })

        for compoundName in compoundsToReplace {
            let existingItems = planRepo.items.filter { item in
                item.dayKey == dayKey &&
                item.compoundName.lowercased() == compoundName &&
                item.status != .optimizedAway  // Don't re-mark already optimized items
            }
            debugLog("=== APPLY: Marking \(existingItems.count) items as optimizedAway for \(compoundName)")
            for item in existingItems {
                debugLog("=== APPLY: Marking \(item.id) as optimizedAway")
                try? planRepo.updateStatus(id: item.id, status: .optimizedAway)
            }
        }

        // Now create new optimizer replacement items
        for (recIndex, recommendation) in replaceRecs.enumerated() {
            guard let scheduledTime = recommendation.scheduledTime else { continue }

            let compoundName = extractCompoundName(from: recommendation)
            guard let compound = NootropicCompound.allCases.first(where: { matchesCompound($0, name: compoundName) }) else { continue }

            let totalDose = recommendation.recommendedDoseMg ?? compound.optimalDoseMg
            let splitCount = recommendation.splitDoseCount

            debugLog("=== APPLY: Creating \(compound.rawValue), totalDose=\(totalDose)mg, splitCount=\(splitCount)")

            // Handle split doses - create multiple items if splitDoseCount > 1
            // NOTE: If multiple recommendations exist for the same compound (morning + afternoon),
            // each recommendation represents ONE of the split doses, so we only create ONE item per recommendation
            // The splitDoseCount indicates how many times THIS specific recommendation should be split
            // But in practice, when we have multiple recommendations (morning + afternoon), 
            // each recommendation already represents one of the splits

            // If we have multiple recommendations for this compound with different times,
            // each recommendation is already a separate dose - no need to split further
            let sameCompoundRecs = replaceRecs.filter { extractCompoundName(from: $0).lowercased() == compoundName.lowercased() }
            let shouldSplitFurther = splitCount > 1 && sameCompoundRecs.count == 1

            if shouldSplitFurther {
                // Multiple split doses needed for this single recommendation
                for i in 0..<splitCount {
                    let dose = totalDose / Double(splitCount)
                    let itemTime = scheduledTime.addingTimeInterval(Double(i) * TimeConstants.fourHourSeconds)

                    let itemId = "\(compound.rawValue.uppercased())-\(dayKey)-\(recIndex)-\(i)"

                    debugLog("=== APPLY: Creating split \(i+1)/\(splitCount) at hour=\(DateHelper.hour(of: itemTime)), dose=\(dose)mg, id=\(itemId)")

                    let item = DailyPlanItemModel(
                        id: itemId,
                        compoundUuid: compound.rawValue.lowercased(),
                        dayKey: dayKey,
                        compoundName: compound.rawValue,
                        doseMg: dose,
                        source: .optimizer,
                        status: .pending,
                        scheduledTime: itemTime
                    )
                    do {
                        try planRepo.save(item)
                        debugLog("=== APPLY: Successfully saved \(compound.rawValue) split \(i+1)")
                    } catch {
                        debugLog("=== APPLY: FAILED to save \(compound.rawValue): \(error)")
                    }
                }
            } else {
                // Each recommendation is already a separate dose - save as-is
                let itemId = "\(compound.rawValue.uppercased())-\(dayKey)-\(recIndex)"

                debugLog("=== APPLY: Creating \(compound.rawValue) at hour=\(DateHelper.hour(of: scheduledTime)), dose=\(totalDose)mg, id=\(itemId)")

                let item = DailyPlanItemModel(
                    id: itemId,
                    compoundUuid: compound.rawValue.lowercased(),
                    dayKey: dayKey,
                    compoundName: compound.rawValue,
                    doseMg: totalDose,
                    source: .optimizer,
                    status: .pending,
                    scheduledTime: scheduledTime
                )
                do {
                    try planRepo.save(item)
                    debugLog("=== APPLY: Successfully saved \(compound.rawValue)")
                } catch {
                    debugLog("=== APPLY: FAILED to save \(compound.rawValue): \(error)")
                }
            }
        }
    }

private func autoScheduleRecommendations() {
    }
    // MARK: - Intervention Mapping
    var todayInterventions: [BiologicalIntervention] {
        buildTodayInterventions(
            // Read the repo (write-through, DB-backed) rather than the
            // @Published mirror - the mirror lags writes by one main-queue
            // hop, which left applyOptimizations seeing stale plan items.
            dailyPlanItems: planRepo.items,
            doses: doses,
            supplements: supplementLogs,
            hydration: hydrationEntries,
            exercise: exerciseLogs
        )
    }

    var todayRecommendations: [ActionableRecommendation] {
        guard let profile = profile else { return [] }

        let optimizer = StackOptimizerEngine(goal: OptimizationGoal(rawValue: profile.optimizationGoal) ?? .balanced)
        let hoursUntilBedtime = profile.sleepTime.timeIntervalSince(Date()) / TimeConstants.secondsPerHour

        return optimizer.generateRecommendations(
            activeCaffeineMg: 0,
            currentDayInterventions: todayInterventions,
            wakeTime: profile.wakeTime,
            sleepTime: profile.sleepTime,
            hydrationDeficitMl: 0,
            hoursUntilBedtime: hoursUntilBedtime,
            tolerance: ToleranceCycle(daysSinceReset: profile.toleranceDaysSinceReset, resetDaysRequired: profile.toleranceResetDaysRequired),
            biometrics: todayBiometrics
        )
    }

var semanticBlocks: [SemanticProtocolBlock] {
        let interventions = todayInterventions
        let blocks = SemanticBlockClusterer.generateSemanticBlocks(from: interventions)
        return blocks
    }

    // MARK: - Biometrics
    func saveBiometrics(_ biometrics: DailyBiometricsModel) {
        try? biometricRepo.save(biometrics)
    }
}
