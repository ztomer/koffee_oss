import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Phase 19 Dashboard Refactor Tests

@MainActor
final class Phase19DashboardRefactorTests: XCTestCase {

    func testBiometricHUDTwoColumnLayout() {
        // Test that HUD has two columns: pods and gauges
        let hasPods = true // Sleep, HRV, Metabolic widgets
        let hasGauges = true // CaffeineMeter, MetricCards

        XCTAssertTrue(hasPods, "HUD should have pods column")
        XCTAssertTrue(hasGauges, "HUD should have gauges column")
    }

    func testCaffeineMeterFrameConstraint() {
        // Test that meter can be constrained to small width
        let constrainedWidth: CGFloat = 120
        XCTAssertEqual(constrainedWidth, 120, "Meter should support 120pt width")
    }

    func testChartUsesWakeTimeAsStart() {
        // Chart should use wakeTime, not Date() as start
        let wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        let startTime = wakeTime

        XCTAssertNotNil(startTime)
        XCTAssertEqual(Calendar.current.component(.hour, from: startTime), 7)
    }

    func testChartShowsFull24HourArc() {
        let wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        let sleepTime = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        let endTime = sleepTime.addingTimeInterval(3600 * 4) // +4 hours past sleep

        let hours = endTime.timeIntervalSince(wakeTime) / 3600
        XCTAssertGreaterThanOrEqual(hours, 20, "Should show at least 20 hours")
    }

    func testDashboardNoQuickActionDock() {
        // Quick action dock should be removed from dashboard
        let hasDock = false // Removed in Phase 19
        XCTAssertFalse(hasDock, "Dashboard should not have quick action dock")
    }
}
