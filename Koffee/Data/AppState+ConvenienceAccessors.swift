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

    var takenPlanItemIds: Set<String> {
        let today = DateHelper.startOfDay()
        let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
        return Set(dailyPlanItems.filter {
            $0.status == .taken && $0.scheduledTime >= today && $0.scheduledTime < tomorrow
        }.map { $0.id })
    }

    var skippedPlanItemIds: Set<String> {
        let today = DateHelper.startOfDay()
        let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
        return Set(dailyPlanItems.filter {
            $0.status == .skipped && $0.scheduledTime >= today && $0.scheduledTime < tomorrow
        }.map { $0.id })
    }

    var pendingPlanItemsToday: [DailyPlanItemModel] {
        let today = DateHelper.startOfDay()
        let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
        return dailyPlanItems.filter {
            $0.status == .pending && $0.scheduledTime >= today && $0.scheduledTime < tomorrow
        }
    }

func pendingPlanItemsByCompound(_ compoundUuid: String) -> [DailyPlanItemModel] {
        let today = DateHelper.startOfDay()
        let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
        return dailyPlanItems.filter {
            $0.compoundUuid == compoundUuid &&
            $0.status == .pending &&
            $0.scheduledTime >= today &&
            $0.scheduledTime < tomorrow
        }
    }

    func pendingPlanItemsByStatus(_ status: PlanItemStatus) -> [DailyPlanItemModel] {
        let today = DateHelper.startOfDay()
        let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
        return dailyPlanItems.filter {
            $0.status == status &&
            $0.scheduledTime >= today &&
            $0.scheduledTime < tomorrow
        }
    }

    func pendingPlanItemsTodayByCompound(_ compoundUuid: String) -> [DailyPlanItemModel] {
        let today = DateHelper.startOfDay()
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

    var visiblePlanItems: [DailyPlanItemModel] {
        let today = DateHelper.startOfDay()
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

    /// Most-logged beverageId over all doses; ties go to the most recent dose.
    /// Nil when no dose carries a beverageId. Data-driven: derived from `doses`.
    var usualBeverageId: String? {
        var counts: [String: Int] = [:]
        var lastSeen: [String: Date] = [:]
        for dose in doses {
            guard let bid = dose.beverageId, !bid.isEmpty else { continue }
            counts[bid, default: 0] += 1
            if let prev = lastSeen[bid] {
                if dose.timestamp > prev { lastSeen[bid] = dose.timestamp }
            } else {
                lastSeen[bid] = dose.timestamp
            }
        }
        guard !counts.isEmpty else { return nil }
        let bestCount = counts.values.max() ?? 0
        let tied = counts.filter { $0.value == bestCount }.map { $0.key }
        guard tied.count > 1 else { return tied.first }
        return tied.max { (lastSeen[$0] ?? .distantPast) < (lastSeen[$1] ?? .distantPast) }
    }

    /// Bedtime projection for today doses plus one hypothetical beverage dose
    /// at `at`. Uses the single decay funnel `projectBedtimeCaffeine`.
    func projectedBedtimeCaffeine(byAdding beverage: BeverageModel, at: Date = DateHelper.now) -> Double {
        let now = DateHelper.now
        let todayDoses = dosesForDate(now).map { ($0.timestamp, $0.caffeineMg) }
        var combined = todayDoses
        combined.append((at, Double(beverage.caffeineMg)))
        let metabolism = MetabolismRate(swiftDataValue: profile?.metabolismRate ?? "") ?? .medium
        let wakeTime = profile?.wakeTime ?? DateHelper.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = profile?.sleepTime ?? DateHelper.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        return projectBedtimeCaffeine(doses: combined, wakeTime: wakeTime, sleepTime: sleepTime, metabolism: metabolism)
    }

    /// Consecutive days with at least one dose, ending today. Data-driven from `doses`.
    var consecutiveMorningStreak: Int {
        consecutiveDayStreak(doses: doses, calendar: DateHelper.calendar)
    }
}

/// Consecutive days with at least one dose, ending today. Pure for testing.
func consecutiveDayStreak(doses: [DoseModel], calendar: Calendar, now: Date = DateHelper.now) -> Int {
    var streak = 0
    for offset in 0..<365 {
        guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { break }
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { break }
        let hasDose = doses.contains { $0.timestamp >= start && $0.timestamp < end }
        if hasDose {
            streak += 1
        } else if offset == 0 {
            continue
        } else {
            break
        }
    }
    return streak
}

/// Human streak line. Pure for testing.
func streakLine(_ count: Int) -> String {
    count == 1 ? "1 morning in a row" : "\(count) mornings in a row"
}
