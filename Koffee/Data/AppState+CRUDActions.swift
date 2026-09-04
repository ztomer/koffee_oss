import Foundation
import Combine
import GRDB

@MainActor
extension AppState {
    // MARK: - CRUD Actions
    // Actions - all throw properly
    func addDose(beverageId: String? = nil, timestamp: Date, caffeineMg: Double, beverageName: String? = nil) throws {
        try doseRepo.add(beverageId: beverageId, timestamp: timestamp, caffeineMg: caffeineMg, beverageName: beverageName)
    }

    func removeDose(_ dose: DoseModel) throws {
        try doseRepo.delete(dose)
    }

    func removeHydration(_ entry: HydrationEntryModel) throws {
        try hydrationRepo.delete(entry)
    }

    func removeSupplement(_ log: SupplementLogModel) throws {
        try supplementRepo.delete(log)
    }

    func removeExercise(_ log: ExerciseLogModel) throws {
        try exerciseRepo.delete(log)
    }

    func addSupplement(compoundName: String, status: PlanItemStatus = .taken) throws {
        try supplementRepo.add(compoundName: compoundName, status: status)
    }

    func addHydration(amountMl: Double) throws {
        try hydrationRepo.add(amountMl: amountMl)
    }

    func addExercise(activityName: String, durationMinutes: Int? = nil) throws {
        try exerciseRepo.add(activityName: activityName, durationMinutes: durationMinutes)
    }

    func saveProfile(_ profile: UserProfileModel) throws {
        try profileRepo.save(profile)
    }

    // MARK: - Data Access Methods (for Views)

    func dosesForDate(_ date: Date) -> [DoseModel] {
        let calendar = DateHelper.calendar
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return doses.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    func hydrationForDate(_ date: Date) -> [HydrationEntryModel] {
        let calendar = DateHelper.calendar
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return hydrationEntries.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    func supplementsForDate(_ date: Date) -> [SupplementLogModel] {
        let calendar = DateHelper.calendar
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return supplementLogs.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    func exercisesForDate(_ date: Date) -> [ExerciseLogModel] {
        let calendar = DateHelper.calendar
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return exerciseLogs.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    func planItemsForDate(_ date: Date) -> [DailyPlanItemModel] {
        let calendar = DateHelper.calendar
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return dailyPlanItems.filter { $0.scheduledTime >= start && $0.scheduledTime < end }
    }

    func dosesInRange(start: Date, end: Date) -> [DoseModel] {
        return doses.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    func hydrationInRange(start: Date, end: Date) -> [HydrationEntryModel] {
        return hydrationEntries.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    func supplementsInRange(start: Date, end: Date) -> [SupplementLogModel] {
        return supplementLogs.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    func exercisesInRange(start: Date, end: Date) -> [ExerciseLogModel] {
        return exerciseLogs.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    func getOrCreateProfile() throws -> UserProfileModel {
        try profileRepo.getOrCreate()
    }

    func summaryForDate(_ date: Date) -> DailySummary {
        queryService.summaryForDate(date)
    }

    func caffeineCurveForDay(_ date: Date) -> [(time: Date, cumulativeMg: Double)] {
        queryService.caffeineCurveForDay(date)
    }
}
