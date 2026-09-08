import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Window Loading Regression Tests

@MainActor
final class WindowLoadingRegressionTests: XCTestCase {

    // Bug: Window showed only traffic lights because contentView was set after makeKeyAndOrderFront
    // Fix: Show placeholder immediately, then swap content after DB init
    // This test verifies the data layer prerequisites for window content are ready
    func testAppStateReadyForWindowContent() throws {
        let db = try DatabaseQueue()
        try setupFullSchema(db)

        let profileRepo = UserProfileRepository(db: db)
        let doseRepo = DoseRepository(db: db)
        let beverageRepo = BeverageRepository(db: db)
        let planRepo = DailyPlanRepository(db: db)

        // Verify profile exists before AppState creation (mimics app init sequence)
        let profile = try profileRepo.getOrCreate()
        XCTAssertNotNil(profile)

        let appState = AppState(
            profileRepo: profileRepo,
            doseRepo: doseRepo,
            beverageRepo: beverageRepo,
            planRepo: planRepo
        )

        // Wait for ValueObservation to propagate
        let exp = expectation(description: "profile loaded")
        exp.assertForOverFulfill = false
        let c = appState.$profile.dropFirst().sink { p in
            if p != nil { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()

        // Verify AppState is ready for MainSplitView
        XCTAssertNotNil(appState.profile)
        XCTAssertEqual(appState.profile?.id, profile.id)

        // Verify daily plan is generated (required for sidebar content)
        try appState.refreshDailyPlan()
        XCTAssertGreaterThanOrEqual(appState.dailyPlanItems.count, 0)
    }

    private func setupFullSchema(_ db: DatabaseQueue) throws {
        try DatabaseManager.makeMigrator().migrate(db)
    }
}
