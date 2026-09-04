import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Integration Tests (end-to-end data flow through AppState)

@MainActor
final class IntegrationTests: XCTestCase {

    var db: DatabaseQueue!
    var appState: AppState!
    var doseRepo: DoseRepository!
    var hydrationRepo: HydrationRepository!
    var supplementRepo: SupplementLogRepository!
    var exerciseRepo: ExerciseRepository!

    override func setUp() async throws {
        db = try DatabaseQueue()
        try setupFullSchema(db)

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
        let c = appState.$doses.sink { doses in if doses.count > 0 { exp.fulfill() } }
        wait(for: [exp], timeout: timeout)
        c.cancel()
    }

    func wait(for repo: HydrationRepository, timeout: TimeInterval = 2.0) {
        let exp = expectation(description: "repo updated")
        exp.assertForOverFulfill = false
        let c = appState.$hydrationEntries.dropFirst().sink { _ in exp.fulfill() }
        wait(for: [exp], timeout: timeout)
        c.cancel()
    }

    func wait(for repo: SupplementLogRepository, timeout: TimeInterval = 2.0) {
        let exp = expectation(description: "repo updated")
        exp.assertForOverFulfill = false
        let c = appState.$supplementLogs.dropFirst().sink { _ in exp.fulfill() }
        wait(for: [exp], timeout: timeout)
        c.cancel()
    }

    func wait(for repo: ExerciseRepository, timeout: TimeInterval = 2.0) {
        let exp = expectation(description: "repo updated")
        exp.assertForOverFulfill = false
        let c = appState.$exerciseLogs.dropFirst().sink { _ in exp.fulfill() }
        wait(for: [exp], timeout: timeout)
        c.cancel()
    }

    // Integration: full day workflow
    func testFullDayWorkflow() throws {
        var profile = try appState.getOrCreateProfile()
        profile.wakeTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0))!
        profile.sleepTime = Calendar.current.date(from: DateComponents(hour: 23, minute: 0))!
        profile.stackCompounds = ["L-Theanine", "Creatine"]
        try appState.saveProfile(profile)

        let profileExp = expectation(description: "profile set")
        profileExp.assertForOverFulfill = false
        let pc = appState.$profile.dropFirst().sink { p in
            if p?.stackCompounds.count == 2 { profileExp.fulfill() }
        }
        wait(for: [profileExp], timeout: 2.0)
        pc.cancel()

        try appState.addDose(timestamp: Date(), caffeineMg: 95.0, beverageName: "Espresso")
        wait(for: doseRepo)

        try appState.addHydration(amountMl: 250.0)
        let hydExp = expectation(description: "hydration logged")
        hydExp.assertForOverFulfill = false
        let hc = hydrationRepo.$entries.dropFirst().sink { _ in hydExp.fulfill() }
        wait(for: [hydExp], timeout: 2.0)
        hc.cancel()

        try appState.addSupplement(compoundName: "L-Theanine")
        let supExp = expectation(description: "supplement logged")
        supExp.assertForOverFulfill = false
        let sc = supplementRepo.$logs.dropFirst().sink { _ in supExp.fulfill() }
        wait(for: [supExp], timeout: 2.0)
        sc.cancel()

        try appState.addExercise(activityName: "Zone 2 Cardio")
        let exExp = expectation(description: "exercise logged")
        exExp.assertForOverFulfill = false
        let ec = exerciseRepo.$logs.dropFirst().sink { _ in exExp.fulfill() }
        wait(for: [exExp], timeout: 2.0)
        ec.cancel()

        let summary = appState.summaryForDate(Date())
        XCTAssertEqual(summary.doseCount, 1)
        XCTAssertEqual(summary.totalCaffeineMg, 95.0)
        XCTAssertEqual(summary.totalHydrationMl, 250.0)
        XCTAssertEqual(summary.supplementCount, 1)
        XCTAssertEqual(summary.exerciseCount, 1)

        XCTAssertEqual(appState.profile?.stackCompounds, ["L-Theanine", "Creatine"])
    }

    // Integration: adding and removing doses
    func testDoseAddRemoveCycle() throws {
        try appState.addDose(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")
        let e1 = expectation(description: "dose 1")
        e1.assertForOverFulfill = false
        let c1 = appState.$doses.dropFirst().sink { d in if d.count == 1 { e1.fulfill() } }
        wait(for: [e1], timeout: 2.0)
        c1.cancel()

        try appState.addDose(timestamp: Date(), caffeineMg: 50.0, beverageName: "Tea")
        let e2 = expectation(description: "dose 2")
        e2.assertForOverFulfill = false
        let c2 = appState.$doses.dropFirst().sink { d in if d.count == 2 { e2.fulfill() } }
        wait(for: [e2], timeout: 2.0)
        c2.cancel()

        XCTAssertEqual(appState.doses.count, 2)

        let doseToRemove = appState.doses[0]
        try appState.removeDose(doseToRemove)
        let e3 = expectation(description: "dose removed")
        e3.assertForOverFulfill = false
        let c3 = appState.$doses.dropFirst().sink { d in if d.count == 1 { e3.fulfill() } }
        wait(for: [e3], timeout: 2.0)
        c3.cancel()

        XCTAssertEqual(appState.doses.count, 1)
        XCTAssertEqual(appState.doses[0].caffeineMg, 50.0)
    }

    // Integration: validation prevents bad data
    func testValidationPreventsBadData() throws {
        XCTAssertThrowsError(try appState.addDose(timestamp: Date(), caffeineMg: -10))
        XCTAssertThrowsError(try appState.addDose(timestamp: Date(), caffeineMg: 2000))
        XCTAssertThrowsError(try appState.addHydration(amountMl: 0))
        XCTAssertThrowsError(try appState.addHydration(amountMl: 10000))
        XCTAssertThrowsError(try appState.addSupplement(compoundName: ""))
        XCTAssertThrowsError(try appState.addExercise(activityName: ""))
        XCTAssertThrowsError(try appState.addExercise(activityName: "Running", durationMinutes: 0))
        XCTAssertThrowsError(try appState.addExercise(activityName: "Running", durationMinutes: 500))

        XCTAssertEqual(appState.doses.count, 0)
        XCTAssertEqual(appState.hydrationEntries.count, 0)
        XCTAssertEqual(appState.supplementLogs.count, 0)
        XCTAssertEqual(appState.exerciseLogs.count, 0)
    }

    // Integration: multi-day data isolation
    func testMultiDayDataIsolation() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        try appState.addDose(timestamp: yesterday, caffeineMg: 100.0, beverageName: "Yesterday")
        try appState.addDose(timestamp: today, caffeineMg: 95.0, beverageName: "Today")
        try appState.addDose(timestamp: tomorrow, caffeineMg: 50.0, beverageName: "Tomorrow")

        let doseExp = expectation(description: "all doses loaded")
        doseExp.assertForOverFulfill = false
        var count = 0
        let dc = doseRepo.$doses.dropFirst().sink { _ in
            count += 1
            if count >= 3 { doseExp.fulfill() }
        }
        wait(for: [doseExp], timeout: 2.0)
        dc.cancel()

        let todaySummary = appState.summaryForDate(Date())
        XCTAssertEqual(todaySummary.doseCount, 1)
        XCTAssertEqual(todaySummary.totalCaffeineMg, 95.0)

        let yesterdaySummary = appState.summaryForDate(yesterday)
        XCTAssertEqual(yesterdaySummary.doseCount, 1)
        XCTAssertEqual(yesterdaySummary.totalCaffeineMg, 100.0)

        let tomorrowSummary = appState.summaryForDate(tomorrow)
        XCTAssertEqual(tomorrowSummary.doseCount, 1)
        XCTAssertEqual(tomorrowSummary.totalCaffeineMg, 50.0)
    }

    // Integration: caffeine curve computation
    func testCaffeineCurveComputation() throws {
        let now = Date()
        try appState.addDose(timestamp: now, caffeineMg: 95.0, beverageName: "Coffee")
        try appState.addDose(timestamp: now.addingTimeInterval(3600), caffeineMg: 50.0, beverageName: "Tea")
        try appState.addDose(timestamp: now.addingTimeInterval(7200), caffeineMg: 30.0, beverageName: "Green Tea")

        let doseExp = expectation(description: "doses loaded")
        doseExp.assertForOverFulfill = false
        var count = 0
        let dc = doseRepo.$doses.dropFirst().sink { _ in
            count += 1
            if count >= 3 { doseExp.fulfill() }
        }
        wait(for: [doseExp], timeout: 2.0)
        dc.cancel()

        let curve = appState.caffeineCurveForDay(Date())
        XCTAssertEqual(curve.count, 3)
        XCTAssertEqual(curve[0].cumulativeMg, 95.0)
        XCTAssertEqual(curve[1].cumulativeMg, 145.0)
        XCTAssertEqual(curve[2].cumulativeMg, 175.0)
    }

    // Integration: profile updates propagate
    func testProfileUpdatesPropagate() throws {
        var profile = try appState.getOrCreateProfile()
        profile.sensitivity = "high"
        profile.metabolismRate = "slow"
        profile.optimizationGoal = "deepSleep"
        profile.weight = 85.0
        try appState.saveProfile(profile)

        let exp = expectation(description: "profile updated")
        exp.assertForOverFulfill = false
        let c = appState.$profile.dropFirst().sink { p in
            if p?.sensitivity == "high" { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()

        XCTAssertEqual(appState.profile?.sensitivity, "high")
        XCTAssertEqual(appState.profile?.metabolismRate, "slow")
        XCTAssertEqual(appState.profile?.optimizationGoal, "deepSleep")
        XCTAssertEqual(appState.profile?.weight, 85.0)
    }

    private func setupFullSchema(_ db: DatabaseQueue) throws {
        try DatabaseManager.makeMigrator().migrate(db)
    }
}
