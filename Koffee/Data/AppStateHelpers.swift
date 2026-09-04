import Foundation
import GRDB
import Combine

func buildTodayInterventions(
    dailyPlanItems: [DailyPlanItemModel],
    doses: [DoseModel],
    supplements: [SupplementLogModel],
    hydration: [HydrationEntryModel],
    exercise: [ExerciseLogModel]
) -> [BiologicalIntervention] {
    let calendar = Calendar.current
    let now = Date()
    let todayStart = calendar.startOfDay(for: now)
    let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!

    let todayStartTs = todayStart.timeIntervalSince1970
    let todayEndTs = todayEnd.timeIntervalSince1970

    var interventions: [BiologicalIntervention] = []

    let planItems = dailyPlanItems.filter { item in
        let itemTs = item.scheduledTime.timeIntervalSince1970
        return itemTs >= todayStartTs && itemTs < todayEndTs
    }

    for item in planItems {
        let type: BiologicalIntervention.InterventionType
        if item.nutritionTemplateId != nil {
            type = .nutrition
        } else if item.exerciseTemplateId != nil {
            type = .exercise
        } else if item.compoundUuid == "caffeine" {
            type = .beverage
        } else {
            type = .supplement
        }

        interventions.append(BiologicalIntervention(
            id: item.id,
            name: item.compoundName,
            scheduledTime: item.scheduledTime,
            type: type,
            isAbsorptionBlocker: false,
            requiresFastedState: false,
            activeCaffeineMg: item.doseMg
        ))
    }

    for dose in doses {
        let doseTs = dose.timestamp.timeIntervalSince1970
        if doseTs >= todayStartTs && doseTs < todayEndTs {
            interventions.append(BiologicalIntervention(
                id: dose.id,
                name: dose.beverageName ?? NootropicCompound.caffeine.rawValue,
                scheduledTime: dose.timestamp,
                type: .beverage,
                isAbsorptionBlocker: false,
                requiresFastedState: false,
                activeCaffeineMg: dose.caffeineMg
            ))
        }
    }

    for log in supplements {
        let logTs = log.timestamp.timeIntervalSince1970
        if logTs >= todayStartTs && logTs < todayEndTs {
            interventions.append(BiologicalIntervention(
                id: log.id,
                name: log.compoundName,
                scheduledTime: log.timestamp,
                type: .supplement,
                isAbsorptionBlocker: false,
                requiresFastedState: false,
                activeCaffeineMg: 0
            ))
        }
    }

    for entry in hydration {
        let entryTs = entry.timestamp.timeIntervalSince1970
        if entryTs >= todayStartTs && entryTs < todayEndTs {
            interventions.append(BiologicalIntervention(
                id: entry.id,
                name: "Water",
                scheduledTime: entry.timestamp,
                type: .nutrition,
                isAbsorptionBlocker: false,
                requiresFastedState: false,
                activeCaffeineMg: 0
            ))
        }
    }

    for log in exercise {
        let logTs = log.timestamp.timeIntervalSince1970
        if logTs >= todayStartTs && logTs < todayEndTs {
            let maintainsPerfusion = determineHepaticPerfusion(activityName: log.activityName)
            interventions.append(BiologicalIntervention(
                id: log.id,
                name: log.activityName,
                scheduledTime: log.timestamp,
                type: .exercise,
                isAbsorptionBlocker: false,
                requiresFastedState: false,
                activeCaffeineMg: 0,
                durationMinutes: log.durationMinutes,
                maintainsHepaticPerfusion: maintainsPerfusion
            ))
        }
    }

    return interventions.sorted { $0.scheduledTime < $1.scheduledTime }
}

func determineHepaticPerfusion(activityName: String) -> Bool {
    let lowPerfusionActivities = ["HIIT", "high intensity", "heavy", "sprint", "intense"]
    let nameLower = activityName.lowercased()
    return !lowPerfusionActivities.contains { nameLower.contains($0.lowercased()) }
}

func extractCompoundName(from recommendation: ActionableRecommendation) -> String {
    let title = recommendation.title.lowercased()
    if title.contains("glycine") { return "Glycine" }
    if title.contains("creatine") { return "Creatine" }
    if title.contains("magnesium") { return "Magnesium" }
    if title.contains("l-theanine") { return "L-Theanine" }
    if title.contains("caffeine") { return NootropicCompound.caffeine.rawValue }
    if title.contains("sleep") { return "Magnesium" }
    return recommendation.title
}

func sumCaffeine(_ doses: [DoseModel]) -> Double {
    doses.reduce(0) { $0 + $1.caffeineMg }
}

func sumHydration(_ entries: [HydrationEntryModel]) -> Double {
    entries.reduce(0) { $0 + $1.amountMl }
}

func matchesCompound(_ compound: NootropicCompound, name: String) -> Bool {
    compound.rawValue.lowercased() == name.lowercased()
}
