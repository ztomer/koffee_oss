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
    var supplementRepo: SupplementLogRepository!
    var hydrationRepo: HydrationRepository!
    var exerciseRepo: ExerciseRepository!
    var planRepo: DailyPlanRepository!

    override func setUp() async throws {
        db = try DatabaseQueue()
        try setupFullSchema(db)

        let profileRepo = UserProfileRepository(db: db)
        doseRepo = DoseRepository(db: db)
        let beverageRepo = BeverageRepository(db: db)
        supplementRepo = SupplementLogRepository(db: db)
        hydrationRepo = HydrationRepository(db: db)
        exerciseRepo = ExerciseRepository(db: db)
        planRepo = DailyPlanRepository(db: db)

        appState = AppState(
            profileRepo: profileRepo,
            doseRepo: doseRepo,
            beverageRepo: beverageRepo,
            supplementRepo: supplementRepo,
            hydrationRepo: hydrationRepo,
            exerciseRepo: exerciseRepo,
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

    func testSupplementCompletionTracking() throws {
        // Default add records a COMPLETED (taken) supplement
        try appState.addSupplement(compoundName: "L-Theanine")
        let exp = expectation(description: "supplement logged")
        exp.assertForOverFulfill = false
        let c = appState.$supplementLogs.sink { logs in
            if logs.count > 0 { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()
        let todayLogs = try supplementRepo.logsForDate(Date())
        XCTAssertEqual(todayLogs.count, 1)
        XCTAssertEqual(todayLogs[0].compoundName, "L-Theanine")
        XCTAssertEqual(todayLogs[0].status, .taken)
    }

    func testSupplementSkipTracking() throws {
        try appState.addSupplement(compoundName: "Creatine", status: .skipped)
        let exp = expectation(description: "supplement skipped")
        exp.assertForOverFulfill = false
        let c = appState.$supplementLogs.sink { logs in
            if logs.count > 0 && logs[0].status == .skipped { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()
        let todayLogs = try supplementRepo.logsForDate(Date())
        XCTAssertEqual(todayLogs.count, 1)
        XCTAssertEqual(todayLogs[0].status, .skipped)
    }

    func testAllCompoundsCanBeLogged() throws {
        for compound in NootropicCompound.allCases {
            try appState.addSupplement(compoundName: compound.rawValue)
        }
        let exp = expectation(description: "all supplements logged")
        exp.assertForOverFulfill = false
        var count = 0
        let c = appState.$supplementLogs.dropFirst().sink { _ in
            count += 1
            if count >= NootropicCompound.allCases.count { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()
        XCTAssertEqual(appState.supplementLogs.count, NootropicCompound.allCases.count)
        let loggedNames = Set(appState.supplementLogs.map { $0.compoundName })
        let allNames = Set(NootropicCompound.allCases.map { $0.rawValue })
        XCTAssertEqual(loggedNames, allNames)
    }

    func testCompoundsCanBeSortedByTiming() throws {
        let compounds = NootropicCompound.allCases
        let sorted = compounds.sorted { $0.recommendedTimingMinutes < $1.recommendedTimingMinutes }
        XCTAssertFalse(sorted.map { $0.rawValue } == compounds.map { $0.rawValue }.sorted())
        for compound in compounds {
            XCTAssertFalse(compound.recommendedTimingMinutes.isNaN)
        }
    }

    func testSupplementLogsIncludeTimestamps() throws {
        let beforeLog = Date().addingTimeInterval(-1)
        try appState.addSupplement(compoundName: "Magnesium")
        let exp = expectation(description: "supplement logged")
        exp.assertForOverFulfill = false
        let c = appState.$supplementLogs.dropFirst().sink { _ in exp.fulfill() }
        wait(for: [exp], timeout: 2.0)
        c.cancel()
        let logs = try supplementRepo.logsForDate(Date())
        XCTAssertEqual(logs.count, 1)
        XCTAssertGreaterThanOrEqual(logs[0].timestamp, beforeLog)
    }

    func testExerciseLogsIncludeTimestamps() throws {
        let beforeLog = Date().addingTimeInterval(-1)
        try appState.addExercise(activityName: "Running", durationMinutes: 30)
        let exp = expectation(description: "exercise logged")
        exp.assertForOverFulfill = false
        let c = appState.$exerciseLogs.dropFirst().sink { _ in exp.fulfill() }
        wait(for: [exp], timeout: 2.0)
        c.cancel()
        let logs = try exerciseRepo.logsForDate(Date())
        XCTAssertEqual(logs.count, 1)
        XCTAssertGreaterThanOrEqual(logs[0].timestamp, beforeLog)
        XCTAssertEqual(logs[0].durationMinutes, 30)
    }

    func testHydrationLogsIncludeTimestamps() throws {
        let beforeLog = Date().addingTimeInterval(-1)
        try appState.addHydration(amountMl: 500.0)
        let exp = expectation(description: "hydration logged")
        exp.assertForOverFulfill = false
        let c = appState.$hydrationEntries.dropFirst().sink { _ in exp.fulfill() }
        wait(for: [exp], timeout: 2.0)
        c.cancel()
        let logs = try hydrationRepo.entriesForDate(Date())
        XCTAssertEqual(logs.count, 1)
        XCTAssertGreaterThanOrEqual(logs[0].timestamp, beforeLog)
        XCTAssertEqual(logs[0].amountMl, 500.0)
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
            compoundUuid: "l-theanine",
            dayKey: "2026-04-05",
            compoundName: "L-Theanine",
            doseMg: 200,
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
        XCTAssertEqual(planRepo.items[0].compoundName, "L-Theanine")
        XCTAssertEqual(planRepo.items[0].status, .pending)
    }

    // Plan item status updates correctly
    func testPlanItemStatusUpdate() throws {
        let item = DailyPlanItemModel(
            compoundUuid: "creatine",
            dayKey: "2026-04-05",
            compoundName: "Creatine",
            doseMg: 5000,
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

    // History detail includes hydration with time and amount
    func testHistoryDetailIncludesHydrationDetails() throws {
        try appState.addHydration(amountMl: 500.0)
        let exp = expectation(description: "hydration logged")
        exp.assertForOverFulfill = false
        let c = appState.$hydrationEntries.sink { entries in
            if entries.count > 0 { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()

        XCTAssertEqual(appState.hydrationEntries.count, 1)
        XCTAssertEqual(appState.hydrationEntries[0].amountMl, 500.0)
    }

    // History detail includes exercise with time and duration
    func testHistoryDetailIncludesExerciseDetails() throws {
        try appState.addExercise(activityName: "Running", durationMinutes: 30)
        let exp = expectation(description: "exercise logged")
        exp.assertForOverFulfill = false
        let c = appState.$exerciseLogs.sink { logs in
            if logs.count > 0 { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()

        XCTAssertEqual(appState.exerciseLogs.count, 1)
        XCTAssertEqual(appState.exerciseLogs[0].activityName, "Running")
        XCTAssertEqual(appState.exerciseLogs[0].durationMinutes, 30)
    }

    // Caffeine is in NootropicCompound.allCases
    func testCaffeineInAllCompounds() throws {
        let allCases = NootropicCompound.allCases
        XCTAssertTrue(allCases.contains(.caffeine))
        XCTAssertEqual(NootropicCompound.caffeine.optimalDoseMg, 95)
        XCTAssertEqual(NootropicCompound.caffeine.halfLifeHours, 5.0)
        XCTAssertEqual(NootropicCompound.caffeine.recommendedTimingMinutes, 90)
    }

    // Stack compounds sorted by timing
    func testStackCompoundsSortedByTiming() throws {
        let compounds = NootropicCompound.allCases
        let sorted = compounds.sorted { $0.recommendedTimingMinutes < $1.recommendedTimingMinutes }

        // Caffeine (90 min) should come after L-Theanine (-45 min)
        let caffeineIndex = sorted.firstIndex { $0 == .caffeine }!
        let theanineIndex = sorted.firstIndex { $0 == .lTheanine }!
        XCTAssertGreaterThan(caffeineIndex, theanineIndex)
    }

    private func setupFullSchema(_ db: DatabaseQueue) throws {
        try DatabaseManager.makeMigrator().migrate(db)
    }
}
