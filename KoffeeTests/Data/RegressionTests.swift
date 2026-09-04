import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Regression Tests for Bug Fixes

@MainActor
final class RegressionTests: XCTestCase {

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

    func wait(for repo: DoseRepository, timeout: TimeInterval = 2.0) {
        let exp = expectation(description: "repo updated")
        exp.assertForOverFulfill = false
        let c = repo.$doses.sink { doses in if doses.count > 0 { exp.fulfill() } }
        wait(for: [exp], timeout: timeout)
        c.cancel()
    }

    func wait(for repo: SupplementLogRepository, timeout: TimeInterval = 2.0) {
        let exp = expectation(description: "repo updated")
        exp.assertForOverFulfill = false
        let c = repo.$logs.dropFirst().sink { _ in exp.fulfill() }
        wait(for: [exp], timeout: timeout)
        c.cancel()
    }

    func wait(for repo: ExerciseRepository, timeout: TimeInterval = 2.0) {
        let exp = expectation(description: "repo updated")
        exp.assertForOverFulfill = false
        let c = repo.$logs.dropFirst().sink { _ in exp.fulfill() }
        wait(for: [exp], timeout: timeout)
        c.cancel()
    }

    // Bug 3: Stack compounds saved and retrieved from profile
    func testStackCompoundsPersistedInProfile() throws {
        var profile = try appState.getOrCreateProfile()
        profile.stackCompounds = ["L-Theanine", "Creatine"]
        try appState.saveProfile(profile)

        // Wait for ValueObservation to propagate
        let exp = expectation(description: "profile updated")
        exp.assertForOverFulfill = false
        let c = appState.$profile.sink { p in
            if p?.stackCompounds == ["L-Theanine", "Creatine"] {
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()

        XCTAssertEqual(appState.profile?.stackCompounds, ["L-Theanine", "Creatine"])
    }

    // Bug 5: Supplements logged to DB and retrievable
    func testSupplementLoggedToDB() throws {
        try appState.addSupplement(compoundName: "L-Theanine")
        wait(for: supplementRepo)

        let logs = try supplementRepo.logsForDate(Date())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].compoundName, "L-Theanine")
    }

    // Bug 5: Exercise logged to DB and retrievable
    func testExerciseLoggedToDB() throws {
        try appState.addExercise(activityName: "Running", durationMinutes: 30)
        wait(for: exerciseRepo)

        let logs = try exerciseRepo.logsForDate(Date())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].activityName, "Running")
        XCTAssertEqual(logs[0].durationMinutes, 30)
    }

    // Bug 6: History computed from actual data
    func testHistoryComputedFromActualData() throws {
        try appState.addDose(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")
        wait(for: doseRepo)

        try appState.addHydration(amountMl: 250.0)
        try appState.addSupplement(compoundName: "Creatine")
        try appState.addExercise(activityName: "Yoga", durationMinutes: 45)

        let summary = appState.summaryForDate(Date())
        XCTAssertEqual(summary.doseCount, 1)
        XCTAssertEqual(summary.totalCaffeineMg, 95.0)
        XCTAssertEqual(summary.totalHydrationMl, 250.0)
        XCTAssertEqual(summary.supplementCount, 1)
        XCTAssertEqual(summary.exerciseCount, 1)
    }

    // Bug 6: History for date with no data returns empty
    func testHistoryEmptyForDateWithNoData() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let summary = appState.summaryForDate(yesterday)
        XCTAssertEqual(summary.doseCount, 0)
        XCTAssertEqual(summary.totalCaffeineMg, 0)
    }

    // Bug 4: Beverages seeded and retrievable
    func testBeveragesSeededAndRetrievable() throws {
        let bevDb = try DatabaseQueue()
        try setupFullSchema(bevDb)

        let beverageRepo = BeverageRepository(db: bevDb)
        try beverageRepo.seed([
            BeverageModel(id: UUID().uuidString, name: "Espresso", caffeineMg: 63, category: "Coffee", icon: "Coffee"),
            BeverageModel(id: UUID().uuidString, name: "Green Tea", caffeineMg: 28, category: "Tea", icon: "Tea")
        ])

        // Seed triggers ValueObservation - wait for it
        let exp = expectation(description: "beverages loaded")
        exp.assertForOverFulfill = false
        let c = beverageRepo.$beverages.sink { beverages in
            if beverages.count == 2 {
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()

        XCTAssertEqual(beverageRepo.beverages.count, 2)
        XCTAssertEqual(beverageRepo.beverages[0].name, "Espresso")
    }

    private func setupFullSchema(_ db: DatabaseQueue) throws {
        try DatabaseManager.makeMigrator().migrate(db)
    }

}
