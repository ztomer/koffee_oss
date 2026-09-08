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

    func planItemsForDate(_ date: Date) -> [DailyPlanItemModel] {
        let calendar = DateHelper.calendar
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return dailyPlanItems.filter { $0.scheduledTime >= start && $0.scheduledTime < end }
    }

    func dosesInRange(start: Date, end: Date) -> [DoseModel] {
        return doses.filter { $0.timestamp >= start && $0.timestamp < end }
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
