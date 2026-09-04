import Foundation
import Combine
import GRDB

// MARK: - Convenience Accessors
@MainActor
extension AppState {
    // MARK: - Convenience Accessors

    func findDose(byId id: String) -> DoseModel? {
        doses.first { $0.id == id }
    }

    func findHydration(byId id: String) -> HydrationEntryModel? {
        hydrationEntries.first { $0.id == id }
    }

    func findSupplement(byId id: String) -> SupplementLogModel? {
        supplementLogs.first { $0.id == id }
    }

    func findExercise(byId id: String) -> ExerciseLogModel? {
        exerciseLogs.first { $0.id == id }
    }

    var takenPlanItemIds: Set<String> {
        let today = DateHelper.calendar.startOfDay(for: Date())
        let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
        return Set(dailyPlanItems.filter {
            $0.status == .taken && $0.scheduledTime >= today && $0.scheduledTime < tomorrow
        }.map { $0.id })
    }

    var skippedPlanItemIds: Set<String> {
        let today = DateHelper.calendar.startOfDay(for: Date())
        let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
        return Set(dailyPlanItems.filter {
            $0.status == .skipped && $0.scheduledTime >= today && $0.scheduledTime < tomorrow
        }.map { $0.id })
    }

    var pendingPlanItemsToday: [DailyPlanItemModel] {
        let today = DateHelper.calendar.startOfDay(for: Date())
        let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
        return dailyPlanItems.filter {
            $0.status == .pending && $0.scheduledTime >= today && $0.scheduledTime < tomorrow
        }
    }

func pendingPlanItemsByCompound(_ compoundUuid: String) -> [DailyPlanItemModel] {
        let today = DateHelper.calendar.startOfDay(for: Date())
        let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
        return dailyPlanItems.filter {
            $0.compoundUuid == compoundUuid &&
            $0.status == .pending &&
            $0.scheduledTime >= today &&
            $0.scheduledTime < tomorrow
        }
    }

    func pendingPlanItemsByStatus(_ status: PlanItemStatus) -> [DailyPlanItemModel] {
        let today = DateHelper.calendar.startOfDay(for: Date())
        let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
        return dailyPlanItems.filter {
            $0.status == status &&
            $0.scheduledTime >= today &&
            $0.scheduledTime < tomorrow
        }
    }

    func pendingPlanItemsTodayByCompound(_ compoundUuid: String) -> [DailyPlanItemModel] {
        let today = DateHelper.calendar.startOfDay(for: Date())
        let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
        return dailyPlanItems.filter {
            $0.compoundUuid == compoundUuid &&
            $0.status == .pending &&
            $0.scheduledTime >= today &&
            $0.scheduledTime < tomorrow
        }
    }

    func pendingPlanItemsByCompoundToday(_ compoundUuid: String) -> [DailyPlanItemModel] {
        pendingPlanItemsTodayByCompound(compoundUuid)
    }

    func pendingNonCaffeineItemsToday() -> [DailyPlanItemModel] {
        let today = DateHelper.calendar.startOfDay(for: Date())
        let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
        return dailyPlanItems.filter {
            $0.compoundUuid != "caffeine" &&
            $0.status == .pending &&
            $0.scheduledTime >= today &&
            $0.scheduledTime < tomorrow
        }
    }

    var visiblePlanItems: [DailyPlanItemModel] {
        let today = DateHelper.calendar.startOfDay(for: Date())
        let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
        return dailyPlanItems.filter {
            $0.status != .optimizedAway &&
            $0.scheduledTime >= today &&
            $0.scheduledTime < tomorrow
        }
    }

    func findPlanItem(byId id: String) -> DailyPlanItemModel? {
        dailyPlanItems.first { $0.id == id }
    }

    func findBeverage(byId id: String) -> BeverageModel? {
        beverages.first { $0.id == id }
    }
}
