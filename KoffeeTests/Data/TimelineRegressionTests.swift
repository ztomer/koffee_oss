import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Timeline Regression Tests (caffeine schedule populates timeline)

@MainActor
final class TimelineRegressionTests: XCTestCase {

    var db: DatabaseQueue!
    var appState: AppState!
    var profileRepo: UserProfileRepository!
    var doseRepo: DoseRepository!
    var planRepo: DailyPlanRepository!

    private func setupFullSchema(_ db: DatabaseQueue) throws {
        try DatabaseManager.makeMigrator().migrate(db)
    }

    override func setUp() async throws {
        db = try DatabaseQueue()
        try setupFullSchema(db)

        profileRepo = UserProfileRepository(db: db)
        doseRepo = DoseRepository(db: db)
        let beverageRepo = BeverageRepository(db: db)
        planRepo = DailyPlanRepository(db: db)

        var profile = try profileRepo.getOrCreate()
        profile.stackCompounds = ["caffeine"]
        profile.wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        profile.sleepTime = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        try profileRepo.save(profile)

        appState = AppState(
            profileRepo: profileRepo,
            doseRepo: doseRepo,
            beverageRepo: beverageRepo,
            planRepo: planRepo
        )
    }

    func testRefreshDailyPlanCreatesPlanItems() throws {
        for item in planRepo.items {
            _ = try? db.write { db in try item.delete(db) }
        }

        // Wait for AppState to observe profile changes
        let exp = expectation(description: "Profile observed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        try appState.refreshDailyPlan()

        // Verify items are in the database
        let items = try db.read { db in try DailyPlanItemModel.fetchAll(db) }
        XCTAssertFalse(items.isEmpty, "refreshDailyPlan should create plan items")
    }

    func testAddDoseStoredCorrectly() throws {
        try appState.addDose(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")

        let doses = (try? doseRepo.dosesForDate(Date())) ?? []
        XCTAssertEqual(doses.count, 1)
        XCTAssertEqual(doses[0].caffeineMg, 95.0)
    }

    func testDailyPlanItemsFilteredByToday() throws {
        let dayKey = DailyPlanItemModel.dayKey(for: Date())

        let item = DailyPlanItemModel(
            compoundName: "Test",
            scheduledTime: Date(),
            status: .pending,
            dayKey: dayKey
        )
        try planRepo.save(item)

        let items = try planRepo.itemsForDay(Date())
        XCTAssertTrue(items.contains { $0.compoundName == "Test" })
    }

    // MARK: - Caffeine Schedule Regression Tests

    func testRefreshCreatesSingleCaffeineItem() throws {
        // Clear existing plan items
        for item in planRepo.items {
            _ = try? db.write { db in try item.delete(db) }
        }

        try appState.refreshDailyPlan()

        // Verify: refresh creates exactly the caffeine schedule item
        let items = try db.read { db in try DailyPlanItemModel.fetchAll(db) }
        let caffeineItems = items.filter { $0.compoundUuid == "caffeine" }

        XCTAssertEqual(caffeineItems.count, 1, "Refresh should create single caffeine item")
        XCTAssertEqual(caffeineItems[0].doseMg, 95, "Caffeine item should have default 95mg dose")
        XCTAssertEqual(caffeineItems[0].source, .baseStack)
    }

    func testRefreshDoesNotDuplicateCaffeineItem() throws {
        try appState.refreshDailyPlan()
        try appState.refreshDailyPlan()

        let items = try db.read { db in try DailyPlanItemModel.fetchAll(db) }
        let caffeineItems = items.filter { $0.compoundUuid == "caffeine" }

        XCTAssertEqual(caffeineItems.count, 1, "Double refresh should not duplicate the caffeine item")
    }
}
