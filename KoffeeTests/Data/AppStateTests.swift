import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
final class AppStateTests: XCTestCase {

    var appState: AppState!
    var doseRepo: DoseRepository!
    var hydrationRepo: HydrationRepository!
    var supplementRepo: SupplementLogRepository!
    var exerciseRepo: ExerciseRepository!

    override func setUp() async throws {
        let db = try DatabaseQueue()
        try DatabaseManager.makeMigrator().migrate(db)

        let profileRepo = UserProfileRepository(db: db)
        doseRepo = DoseRepository(db: db)
        let beverageRepo = BeverageRepository(db: db)
        supplementRepo = SupplementLogRepository(db: db)
        hydrationRepo = HydrationRepository(db: db)
        exerciseRepo = ExerciseRepository(db: db)
        let planRepo = DailyPlanRepository(db: db)

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

    func wait(for repo: HydrationRepository, timeout: TimeInterval = 2.0) {
        let exp = expectation(description: "repo updated")
        exp.assertForOverFulfill = false
        let c = repo.$entries.dropFirst().sink { _ in exp.fulfill() }
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

    func testAddDoseThroughAppState() throws {
        try appState.addDose(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")
        wait(for: doseRepo)

        let doses = try doseRepo.dosesForDate(Date())
        XCTAssertEqual(doses.count, 1)
        XCTAssertEqual(doses[0].caffeineMg, 95.0)
    }

    func testAddHydrationThroughAppState() throws {
        try appState.addHydration(amountMl: 300.0)
        wait(for: hydrationRepo)

        let entries = try hydrationRepo.entriesForDate(Date())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].amountMl, 300.0)
    }

    func testAddSupplementThroughAppState() throws {
        try appState.addSupplement(compoundName: "L-Theanine")
        wait(for: supplementRepo)

        let logs = try supplementRepo.logsForDate(Date())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].compoundName, "L-Theanine")
    }

    func testAddExerciseThroughAppState() throws {
        try appState.addExercise(activityName: "Yoga", durationMinutes: 45)
        wait(for: exerciseRepo)

        let logs = try exerciseRepo.logsForDate(Date())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].activityName, "Yoga")
        XCTAssertEqual(logs[0].durationMinutes, 45)
    }

    func testRemoveDose() throws {
        try appState.addDose(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")
        wait(for: doseRepo)

        let doses = try doseRepo.dosesForDate(Date())
        XCTAssertEqual(doses.count, 1)

        try appState.removeDose(doses[0])
        wait(for: doseRepo)

        let remainingDoses = try doseRepo.dosesForDate(Date())
        XCTAssertEqual(remainingDoses.count, 0)
    }

    func testValidationPropagatesThroughAppState() {
        XCTAssertThrowsError(try appState.addDose(timestamp: Date(), caffeineMg: -5.0))
        XCTAssertThrowsError(try appState.addHydration(amountMl: 0))
        XCTAssertThrowsError(try appState.addSupplement(compoundName: ""))
    }

    func testQueryServiceThroughAppState() throws {
        try appState.addDose(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")
        try appState.addDose(timestamp: Date(), caffeineMg: 50.0, beverageName: "Tea")
        try appState.addHydration(amountMl: 250.0)

        let summary = appState.summaryForDate(Date())
        XCTAssertEqual(summary.doseCount, 2)
        XCTAssertEqual(summary.totalCaffeineMg, 145.0)
        XCTAssertEqual(summary.totalHydrationMl, 250.0)
    }
}
