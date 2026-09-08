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

    override func setUp() async throws {
        db = try DatabaseQueue()
        try setupFullSchema(db)

        let profileRepo = UserProfileRepository(db: db)
        doseRepo = DoseRepository(db: db)
        let beverageRepo = BeverageRepository(db: db)
        let planRepo = DailyPlanRepository(db: db)

        appState = AppState(
            profileRepo: profileRepo,
            doseRepo: doseRepo,
            beverageRepo: beverageRepo,
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

    // Integration: full day workflow
    func testFullDayWorkflow() throws {
        var profile = try appState.getOrCreateProfile()
        profile.wakeTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0))!
        profile.sleepTime = Calendar.current.date(from: DateComponents(hour: 23, minute: 0))!
        profile.stackCompounds = ["Caffeine"]
        try appState.saveProfile(profile)

        let profileExp = expectation(description: "profile set")
        profileExp.assertForOverFulfill = false
        let pc = appState.$profile.dropFirst().sink { p in
            if p?.stackCompounds.count == 1 { profileExp.fulfill() }
        }
        wait(for: [profileExp], timeout: 2.0)
        pc.cancel()

        try appState.addDose(timestamp: Date(), caffeineMg: 95.0, beverageName: "Espresso")
        wait(for: doseRepo)

        let summary = appState.summaryForDate(Date())
        XCTAssertEqual(summary.doseCount, 1)
        XCTAssertEqual(summary.totalCaffeineMg, 95.0)

        XCTAssertEqual(appState.profile?.stackCompounds, ["Caffeine"])
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

        XCTAssertEqual(appState.doses.count, 0)
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
        XCTAssertEqual(appState.profile?.weight, 85.0)
    }

    private func setupFullSchema(_ db: DatabaseQueue) throws {
        try DatabaseManager.makeMigrator().migrate(db)
    }
}
