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
            if let item = item {
                if item.compoundUuid == "caffeine" {
                    let todayDoses = try doseRepo.dosesForDate(Date())
                    let alreadyLogged = todayDoses.contains { $0.id == id }
                    if !alreadyLogged {
                        try addDoseWithId(id: id, timestamp: Date(), caffeineMg: item.doseMg, beverageName: "Coffee")
                    }
                } else {
                    let todayLogs = try supplementRepo.logsForDate(Date())
                    let alreadyLogged = todayLogs.contains { $0.id == id }
                    if !alreadyLogged {
                        try addSupplementWithId(id: id, compoundName: item.compoundName, status: .taken)
                    }
                }
            }
        }

        if status == .skipped {
            let item = planRepo.items.first { $0.id == id }
            if let item = item {
                if item.compoundUuid == "caffeine" {
                    let todayDoses = try doseRepo.dosesForDate(Date())
                    if let doseToRemove = todayDoses.first(where: { $0.id == id }) {
                        try doseRepo.delete(doseToRemove)
                    }
                } else {
                    let todayLogs = try supplementRepo.logsForDate(Date())
                    if let logToRemove = todayLogs.first(where: { $0.id == id }) {
                        try supplementRepo.delete(logToRemove)
                    }
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

    private func addSupplementWithId(id: String, compoundName: String, status: PlanItemStatus = .taken) throws {
        try supplementRepo.addWithId(id: id, compoundName: compoundName, status: status)
}

    func importNutritionTemplate(_ template: NutritionTemplateModel) throws {
        var mutableTemplate = template
        mutableTemplate.id = UUID().uuidString
        try DatabaseManager.shared.queue().write { db in
            try mutableTemplate.insert(db)
        }
    }
}
