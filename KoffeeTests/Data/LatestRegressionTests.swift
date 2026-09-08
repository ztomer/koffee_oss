import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Regression Tests for Latest Fixes

@MainActor
final class LatestRegressionTests: XCTestCase {

    var db: DatabaseQueue!
    var appState: AppState!
    var doseRepo: DoseRepository!
    var planRepo: DailyPlanRepository!

    override func setUp() async throws {
        db = try DatabaseQueue()
        try setupFullSchema(db)

        let profileRepo = UserProfileRepository(db: db)
        doseRepo = DoseRepository(db: db)
        let beverageRepo = BeverageRepository(db: db)
        planRepo = DailyPlanRepository(db: db)

        appState = AppState(
            profileRepo: profileRepo,
            doseRepo: doseRepo,
            beverageRepo: beverageRepo,
            planRepo: planRepo
        )
    }

    func testPublishedDosesUpdatesOnAdd() throws {
        XCTAssertEqual(appState.doses.count, 0)
        try appState.addDose(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")
        let exp = expectation(description: "doses published")
        exp.assertForOverFulfill = false
        let c = appState.$doses.sink { doses in
            if doses.count > 0 { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()
    }

    func testDoseLogsIncludeTimestamps() throws {
        let beforeLog = Date().addingTimeInterval(-1)
        try appState.addDose(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")
        let exp = expectation(description: "dose logged")
        exp.assertForOverFulfill = false
        let c = appState.$doses.dropFirst().sink { _ in exp.fulfill() }
        wait(for: [exp], timeout: 2.0)
        c.cancel()
        let logs = try doseRepo.dosesForDate(Date())
        XCTAssertEqual(logs.count, 1)
        XCTAssertGreaterThanOrEqual(logs[0].timestamp, beforeLog)
        XCTAssertEqual(logs[0].caffeineMg, 95.0)
    }

    func wait(for repo: DoseRepository, timeout: TimeInterval = 2.0) {
        let exp = expectation(description: "repo updated")
        exp.assertForOverFulfill = false
        let c = appState.$doses.sink { doses in if doses.count > 0 { exp.fulfill() } }
        wait(for: [exp], timeout: timeout)
        c.cancel()
    }

    // DailyPlanItemModel persists and retrieves correctly
    func testDailyPlanItemPersistence() throws {
        let item = DailyPlanItemModel(
            compoundUuid: "caffeine",
            dayKey: "2026-04-05",
            compoundName: "Caffeine",
            doseMg: 95,
            source: .baseStack,
            status: .pending,
            scheduledTime: Date()
        )
        try planRepo.save(item)

        let exp = expectation(description: "plan item saved")
        exp.assertForOverFulfill = false
        let c = planRepo.$items.dropFirst().sink { items in
            if items.count > 0 { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()

        XCTAssertEqual(planRepo.items.count, 1)
        XCTAssertEqual(planRepo.items[0].compoundName, "Caffeine")
        XCTAssertEqual(planRepo.items[0].status, .pending)
    }

    // Plan item status updates correctly
    func testPlanItemStatusUpdate() throws {
        let item = DailyPlanItemModel(
            compoundUuid: "caffeine",
            dayKey: "2026-04-05",
            compoundName: "Caffeine",
            doseMg: 95,
            source: .baseStack,
            status: .pending,
            scheduledTime: Date()
        )
        try planRepo.save(item)

        let saveExp = expectation(description: "item saved")
        saveExp.assertForOverFulfill = false
        let c1 = planRepo.$items.dropFirst().sink { items in
            if items.count > 0 { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c1.cancel()

        let itemId = planRepo.items[0].id
        try planRepo.updateStatus(id: itemId, status: .taken)

        let updateExp = expectation(description: "status updated")
        updateExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if items.first?.status == .taken { updateExp.fulfill() }
        }
        wait(for: [updateExp], timeout: 2.0)
        c2.cancel()

        XCTAssertEqual(planRepo.items[0].status, .taken)
    }

    // Plan items filtered by day key
    func testPlanItemsFilteredByDay() throws {
        let today = Calendar.current.dateComponents([.year, .month, .day], from: Date()).description
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowKey = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow).description

        try planRepo.save(DailyPlanItemModel(compoundUuid: "morning", dayKey: today, compoundName: "Morning",
                                             doseMg: 0, source: .baseStack, status: .pending, scheduledTime: Date()))
        try planRepo.save(DailyPlanItemModel(compoundUuid: "tomorrow", dayKey: tomorrowKey, compoundName: "Tomorrow",
                                             doseMg: 0, source: .baseStack, status: .pending, scheduledTime: tomorrow))

        let exp = expectation(description: "items saved")
        exp.assertForOverFulfill = false
        var count = 0
        let c = planRepo.$items.dropFirst().sink { _ in
            count += 1
            if count >= 2 { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()

        let todayItems = try planRepo.itemsForDay(Date())
        XCTAssertEqual(todayItems.count, 1)
        XCTAssertEqual(todayItems[0].compoundName, "Morning")
    }

    // Delete all plan items for a day
    func testDeleteAllPlanItemsForDay() throws {
        let today = Calendar.current.dateComponents([.year, .month, .day], from: Date()).description

        try planRepo.save(DailyPlanItemModel(compoundUuid: "item1", dayKey: today, compoundName: "Item1",
                                             doseMg: 0, source: .baseStack, status: .pending, scheduledTime: Date()))
        try planRepo.save(DailyPlanItemModel(compoundUuid: "item2", dayKey: today, compoundName: "Item2",
                                             doseMg: 0, source: .baseStack, status: .pending, scheduledTime: Date().addingTimeInterval(3600)))

        let saveExp = expectation(description: "items saved")
        saveExp.assertForOverFulfill = false
        var count = 0
        let c1 = planRepo.$items.dropFirst().sink { _ in
            count += 1
            if count >= 2 { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c1.cancel()

        try planRepo.deleteAllForDay(today)

        let deleteExp = expectation(description: "items deleted")
        deleteExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            XCTAssertEqual(items.count, 0)
            deleteExp.fulfill()
        }
        wait(for: [deleteExp], timeout: 2.0)
        c2.cancel()
    }

    // Caffeine plan item
    func testCaffeinePlanItem() throws {
        let item = DailyPlanItemModel(
            compoundName: "Caffeine",
            scheduledTime: Date(),
            status: .pending,
            dayKey: "2026-04-05",
            compoundUuid: "caffeine",
            doseMg: 95
        )
        try planRepo.save(item)

        let exp = expectation(description: "caffeine item saved")
        exp.assertForOverFulfill = false
        let c = planRepo.$items.dropFirst().sink { items in
            if items.count > 0 { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()

        XCTAssertEqual(planRepo.items[0].compoundUuid, "caffeine")
        XCTAssertEqual(planRepo.items[0].doseMg, 95)
    }

    // History detail includes doses with time and beverage name
    func testHistoryDetailIncludesDoseDetails() throws {
        try appState.addDose(timestamp: Date(), caffeineMg: 95.0, beverageName: "Espresso")
        wait(for: doseRepo)

        // Verify dose is in AppState.doses
        XCTAssertEqual(appState.doses.count, 1)
        XCTAssertEqual(appState.doses[0].caffeineMg, 95.0)
        XCTAssertEqual(appState.doses[0].beverageName, "Espresso")
    }

    // Caffeine is in NootropicCompound.allCases
    func testCaffeineInAllCompounds() throws {
        let allCases = NootropicCompound.allCases
        XCTAssertTrue(allCases.contains(.caffeine))
        XCTAssertEqual(NootropicCompound.caffeine.optimalDoseMg, 95)
        XCTAssertEqual(NootropicCompound.caffeine.halfLifeHours, 5.0)
        XCTAssertEqual(NootropicCompound.caffeine.recommendedTimingMinutes, 90)
    }

    private func setupFullSchema(_ db: DatabaseQueue) throws {
        try DatabaseManager.makeMigrator().migrate(db)
    }
}
