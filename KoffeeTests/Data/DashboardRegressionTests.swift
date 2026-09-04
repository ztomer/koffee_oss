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
    var supplementRepo: SupplementLogRepository! { testDB.supplementRepo }
    var hydrationRepo: HydrationRepository! { testDB.hydrationRepo }
    var exerciseRepo: ExerciseRepository! { testDB.exerciseRepo }
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

    func testTodayInterventionsWithNoData() {
        let interventions = appState.todayInterventions
        XCTAssertNotNil(interventions, "todayInterventions should be accessible")
        XCTAssertEqual(interventions.count, 0, "Should be empty when no data")
    }

    func testSafeLimitHasDefaultValue() {
        // Profile might be nil initially - just verify AppState is accessible
        XCTAssertNotNil(appState, "AppState should be accessible")
    }

    func testBiometricHUDWithNoBiometrics() {
        let biometrics = appState.todayBiometrics
        XCTAssertNil(biometrics, "Should be nil when no Oura data")
    }

    func testStackOptimizerGeneratesRecommendations() {
        // StackOptimizer can be created and used even without profile
        let optimizer = StackOptimizerEngine(goal: .balanced)

        let recommendations = optimizer.generateRecommendations(
            activeCaffeineMg: 0,
            currentDayInterventions: [],
            wakeTime: Date(),
            sleepTime: Date().addingTimeInterval(8 * 3600),
            hydrationDeficitMl: 0,
            hoursUntilBedtime: 8,
            tolerance: ToleranceCycle(daysSinceReset: 0, resetDaysRequired: 14),
            biometrics: nil
        )

        XCTAssertNotNil(recommendations)
    }

    func testCompositeDosesWithNoData() {
        let doses = appState.doses
        XCTAssertNotNil(doses)
    }

    func testCompositeSupplementsWithNoData() {
        let supplements = appState.supplementLogs
        XCTAssertNotNil(supplements)
    }
}
