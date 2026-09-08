import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
final class AppStateTests: XCTestCase {

    var appState: AppState!
    var doseRepo: DoseRepository!

    override func setUp() async throws {
        let db = try DatabaseQueue()
        try DatabaseManager.makeMigrator().migrate(db)

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
        let c = repo.$doses.sink { doses in if doses.count > 0 { exp.fulfill() } }
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
    }

    func testQueryServiceThroughAppState() throws {
        try appState.addDose(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")
        try appState.addDose(timestamp: Date(), caffeineMg: 50.0, beverageName: "Tea")

        let summary = appState.summaryForDate(Date())
        XCTAssertEqual(summary.doseCount, 2)
        XCTAssertEqual(summary.totalCaffeineMg, 145.0)
    }

    func testDailyCaffeineLimitFollowsSensitivity() throws {
        // Bedtime limit and daily limit are different quantities: the gauge
        // compares today's total against the daily ceiling (multiplier * 400),
        // never against the bedtime projection limit.
        var profile = try appState.getOrCreateProfile()
        profile.sensitivity = Sensitivity.high.swiftDataValue
        try appState.saveProfile(profile)

        let exp = expectation(description: "profile updated")
        exp.assertForOverFulfill = false
        let c = appState.$profile.dropFirst().sink { p in
            if p?.sensitivity == Sensitivity.high.swiftDataValue { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()

        XCTAssertEqual(appState.dailyCaffeineLimit, 0.8 * 400, accuracy: 0.001)
        XCTAssertNotEqual(appState.dailyCaffeineLimit, appState.safeCaffeineLimit)
    }
}
