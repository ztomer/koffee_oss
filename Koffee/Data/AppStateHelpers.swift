import Foundation
import GRDB
import Combine

/// Builds caffeine-only interventions for the pharmacokinetic engine:
/// today's caffeine plan items plus logged caffeine doses.
func buildTodayInterventions(
    dailyPlanItems: [DailyPlanItemModel],
    doses: [DoseModel]
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
        interventions.append(BiologicalIntervention(
            id: item.id,
            name: item.compoundName,
            scheduledTime: item.scheduledTime,
            type: .beverage,
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
                activeCaffeineMg: dose.caffeineMg
            ))
        }
    }

    return interventions.sorted { $0.scheduledTime < $1.scheduledTime }
}

func sumCaffeine(_ doses: [DoseModel]) -> Double {
    doses.reduce(0) { $0 + $1.caffeineMg }
}
