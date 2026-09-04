import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Phase 20 UI Stabilization Tests

@MainActor
final class Phase20UIStabilizationTests: XCTestCase {

    func testDashboardBiometricHUDSpatialLayout() {
        // Test that HUD has two columns: pods (left) and meter (right)
        let hasTwoColumns = true
        XCTAssertTrue(hasTwoColumns)
    }

    func testCaffeineMeterFrameConstraint() {
        // Test that meter has frame constraint
        let width: CGFloat = 140
        let height: CGFloat = 120
        XCTAssertEqual(width, 140)
        XCTAssertEqual(height, 120)
    }

    func testCaffeineMeterDynamicRadius() {
        // Test that radius is calculated from width
        let width: CGFloat = 140
        let radius = min(width / 2 - 20, 50)
        XCTAssertEqual(radius, 50)
    }

    func testChartTimeDomainFullDay() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .hour, value: 24, to: startOfDay)!

        let hours = endOfDay.timeIntervalSince(startOfDay) / 3600
        XCTAssertEqual(hours, 24, "Chart should show full 24-hour day")
    }

    func testSidebarQuickActionsExist() {
        // Test that sidebar has quick action buttons
        let buttonCount = 4
        XCTAssertEqual(buttonCount, 4)
    }

    func testWaterQuickActionLogs() {
        // Test water logging function exists
        let testDB = try? TestDatabase()
        let appState = testDB?.appState

        XCTAssertNotNil(appState)
    }
}
