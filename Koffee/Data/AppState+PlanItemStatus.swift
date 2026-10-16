import Foundation
import Combine
import GRDB

@MainActor
extension AppState {
    // MARK: - Plan Item Status
    func updatePlanItemStatus(id: String, status: PlanItemStatus) throws {
        try planRepo.updateStatus(id: id, status: status)

        if status == .taken {
            let item = planRepo.items.first { $0.id == id }
            if let item = item, item.compoundUuid == "caffeine" {
                let todayDoses = try doseRepo.dosesForDate(DateHelper.now)
                let alreadyLogged = todayDoses.contains { $0.id == id }
                if !alreadyLogged {
                    try addDoseWithId(id: id, timestamp: DateHelper.now, caffeineMg: item.doseMg, beverageName: "Coffee")
                }
            }
        }

        if status == .skipped {
            let item = planRepo.items.first { $0.id == id }
            if let item = item, item.compoundUuid == "caffeine" {
                let todayDoses = try doseRepo.dosesForDate(DateHelper.now)
                if let doseToRemove = todayDoses.first(where: { $0.id == id }) {
                    try doseRepo.delete(doseToRemove)
                }
            }
            // NOTE: skipping RETAINS the plan item with status .skipped. The UI
            // (ProtocolTimelineView / skippedPlanItemIds) reads skipped state from
            // persisted rows, so deleting the row here made "skipped" unrepresentable.
            // Row deletion is refreshDailyPlan's job, not a status transition.
        }
    }

    func skipPlanItem(id: String) throws {
        try updatePlanItemStatus(id: id, status: .skipped)
    }

    private func addDoseWithId(id: String, timestamp: Date, caffeineMg: Double, beverageName: String) throws {
        try doseRepo.addWithId(id: id, beverageId: nil, timestamp: timestamp, caffeineMg: caffeineMg, beverageName: beverageName)
    }
}
