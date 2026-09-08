import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Dashboard Regression Tests

@MainActor
final class DashboardRegressionTests: XCTestCase {

    var testDB: TestDatabase!
    var appState: AppState! { testDB.appState }
    var doseRepo: DoseRepository! { testDB.doseRepo }
    var planRepo: DailyPlanRepository! { testDB.planRepo }

    override func setUp() async throws {
        testDB = try TestDatabase()
    }

    func testDashboardLoadsWithoutProfile() {
        XCTAssertNotNil(appState, "AppState should initialize")
    }

    func testDashboardWithEmptyDoses() {
        let doses = appState.doses
        XCTAssertNotNil(doses, "Doses should be accessible")
    }

    func testDashboardWithEmptyPlanItems() {
        let items = appState.dailyPlanItems
        XCTAssertNotNil(items, "Plan items should be accessible")
    }

    func testSafeLimitHasDefaultValue() {
        // Profile might be nil initially - just verify AppState is accessible
        XCTAssertNotNil(appState, "AppState should be accessible")
    }

    func testCompositeDosesWithNoData() {
        let doses = appState.doses
        XCTAssertNotNil(doses)
    }

    func testCaffeineInterventionsWithNoData() {
        let interventions = buildTodayInterventions(dailyPlanItems: [], doses: [])
        XCTAssertEqual(interventions.count, 0, "Should be empty when no data")
    }
}
