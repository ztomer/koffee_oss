import Foundation
import Combine
import GRDB

@MainActor
extension AppState {
    // MARK: - Daily Plan Management

    func refreshDailyPlan() throws {
        guard let profile = profile else {
            debugLog("refreshDailyPlan: profile is nil, cannot generate plan")
            return
        }

        let calendar = DateHelper.calendar
        let now = DateHelper.now
        let dayKey = DailyPlanItemModel.dayKey(for: now)
        let wakeTime = profile.wakeTime

        debugLog("refreshDailyPlan: now=\(now.timeIntervalSince1970), dayKey=\(dayKey), wakeTime=\(wakeTime.timeIntervalSince1970)")

        // Delete ONLY today's baseStack items (will regenerate the caffeine schedule)
        // Preserve: manual items and other days' items
        let todayItems = planRepo.items.filter { item in
            item.dayKey == dayKey
        }

        let baseStackItems = todayItems.filter { $0.source == .baseStack }

        debugLog("refreshDailyPlan: regenerating \(baseStackItems.count) baseStack items")

        for item in baseStackItems {
            debugLog("refreshDailyPlan: deleting baseStack item \(item.id) \(item.dayKey)")
            _ = try? dbWrite { db in try item.delete(db) }
        }

        // Also delete items with malformed dayKeys (like "year: 2026 month: 4 day: 8")
        let malformedItems = planRepo.items.filter { !$0.dayKey.contains("-") }
        for item in malformedItems {
            debugLog("refreshDailyPlan: deleting malformed item \(item.id)")
            _ = try? dbWrite { db in try item.delete(db) }
        }

        // Generate the caffeine schedule: one item 90 min after wake,
        // but only when caffeine is in the user's stack
        let includesCaffeine = profile.stackCompounds.contains { $0.lowercased() == "caffeine" }

        debugLog("refreshDailyPlan: stack compounds = \(profile.stackCompounds)")

        if includesCaffeine {
            let firstDoseTime = wakeTime.addingTimeInterval(TimeConstants.firstDoseDelaySeconds) // 90 min after wake
            let caffeineId = "CAFFEINE-\(dayKey)"
            let todayDoses = try doseRepo.dosesForDate(now)
            let caffeineLogged = todayDoses.contains { $0.id == caffeineId }

            debugLog("refreshDailyPlan: creating caffeine item, scheduledTime=\(firstDoseTime.timeIntervalSince1970)")

            let caffeineItem = DailyPlanItemModel(
                id: caffeineId,
                compoundUuid: "caffeine",
                dayKey: dayKey,
                compoundName: NootropicCompound.caffeine.rawValue,
                doseMg: CaffeineConstants.defaultDoseMg,
                source: .baseStack,
                status: caffeineLogged ? .taken : .pending,
                scheduledTime: firstDoseTime
            )
            try planRepo.save(caffeineItem)
        }

        debugLog("=== REFRESH: Total items after refresh = \(planRepo.items.count)")
    }

    private func dbWrite(_ block: (Database) throws -> Void) throws {
        try DatabaseManager.shared.queue().write(block)
    }
}
