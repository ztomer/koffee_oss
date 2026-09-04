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

        // Delete ONLY today's baseStack items (will regenerate from stack)
        // Preserve: optimizer items, manual items, optimizedAway items, other days' items
        let todayItems = planRepo.items.filter { item in
            item.dayKey == dayKey
        }

        // Separate:
        // - baseStack items: can be regenerated  
        // - optimizer items: should be preserved
        // - manual items: preserved
        // - optimizedAway items: should NOT be regenerated (they've been replaced)
        // CRITICAL: Don't delete items that were optimized away (source==baseStack but status==optimizedAway)
        let baseStackItems = todayItems.filter { $0.source == .baseStack && $0.status != .optimizedAway }
        let preservedItems = todayItems.filter { $0.source != .baseStack && $0.status != .optimizedAway }
        let optimizedAwayItems = todayItems.filter { $0.status == .optimizedAway }

        debugLog("refreshDailyPlan: preserving \(preservedItems.count) optimizer/manual items")
        debugLog("refreshDailyPlan: preserving \(optimizedAwayItems.count) optimizedAway items (will not regenerate)")

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

        // Generate new plan from stack compounds (case-insensitive match)
        // Skip compounds that already have optimizedAway items for today
        let stack = profile.stackCompounds.compactMap { raw -> NootropicCompound? in
            let lowercased = raw.lowercased()
            return NootropicCompound.allCases.first { $0.rawValue.lowercased() == lowercased }
        }

        // Find compounds that were optimized away - don't regenerate these
        let optimizedCompoundNames = Set(optimizedAwayItems.map { $0.compoundName.lowercased() })
        let compoundsToRegenerate = stack.filter { !optimizedCompoundNames.contains($0.rawValue.lowercased()) }

        debugLog("refreshDailyPlan: stack compounds = \(stack.map { $0.rawValue })")
        debugLog("refreshDailyPlan: skipping \(optimizedCompoundNames) (optimized away)")

        // Add caffeine if it's in user's stack AND not optimized away
        let includesCaffeine = stack.contains { $0 == .caffeine }
        let caffeineOptimizedAway = optimizedAwayItems.contains { $0.compoundName.lowercased() == "caffeine" }
        if includesCaffeine && !caffeineOptimizedAway {
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

        // Add stack compounds (excluding caffeine and optimized away compounds)
        for compound in compoundsToRegenerate where compound != .caffeine {
            let minutes = Int(compound.recommendedTimingMinutes)
            let scheduledTime: Date
            let firstDoseTime = wakeTime.addingTimeInterval(TimeConstants.firstDoseDelaySeconds)

            if minutes < 0 {
                scheduledTime = calendar.date(byAdding: .minute, value: minutes, to: firstDoseTime) ?? firstDoseTime
            } else {
                scheduledTime = calendar.date(byAdding: .minute, value: minutes, to: wakeTime) ?? wakeTime
            }

            debugLog("=== REFRESH: Creating \(compound.rawValue) at scheduledTime=\(scheduledTime.timeIntervalSince1970) "
                     + "(hour=\(DateHelper.hour(of: scheduledTime))), doseMg=\(compound.optimalDoseMg)")

            // Create single item with full dose
            let compoundId = "\(compound.rawValue.uppercased())-\(dayKey)"
            let todayLogs = try supplementRepo.logsForDate(now)
            let alreadyLogged = todayLogs.contains { $0.id == compoundId }

            debugLog("=== REFRESH: Saving item id=\(compoundId), compoundName=\(compound.rawValue), "
                     + "scheduledTime hour=\(DateHelper.hour(of: scheduledTime)), doseMg=\(compound.optimalDoseMg)")

            let item = DailyPlanItemModel(
                id: compoundId,
                compoundUuid: compound.rawValue.lowercased(),
                dayKey: dayKey,
                compoundName: compound.rawValue,
                doseMg: compound.optimalDoseMg,
                source: .baseStack,
                status: alreadyLogged ? .taken : .pending,
                scheduledTime: scheduledTime
            )
            try planRepo.save(item)
            debugLog("=== REFRESH: Item saved successfully")
        }

        debugLog("=== REFRESH: Total items after refresh = \(planRepo.items.count)")

        // NOTE: Do NOT auto-schedule AI recommendations here
        // Only run autoScheduleRecommendations when user explicitly clicks "Apply"
        // This prevents duplicates between base stack and optimizer items
    }

    // MARK: - Public method to add optimization items without full refresh
    func addOptimizationItems(_ items: [DailyPlanItemModel]) throws {
        for item in items {
            try planRepo.save(item)
        }
    }

    private func dbWrite(_ block: (Database) throws -> Void) throws {
        try DatabaseManager.shared.queue().write(block)
    }
}
