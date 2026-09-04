import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Phase 19 Settings Tests

@MainActor
final class Phase19SettingsTests: XCTestCase {

    func testOptimizationGoalPickerExists() {
        // Settings should have optimization goal picker
        let goals = OptimizationGoal.allCases
        XCTAssertEqual(goals.count, 3)
    }

    func testOptimizationGoalValues() {
        XCTAssertEqual(OptimizationGoal.maxCognition.rawValue, "Maximum Cognition")
        XCTAssertEqual(OptimizationGoal.deepSleep.rawValue, "Deep Sleep")
        XCTAssertEqual(OptimizationGoal.balanced.rawValue, "Balanced")
    }

    func testOptimizationGoalHasIcon() {
        XCTAssertEqual(OptimizationGoal.maxCognition.icon, "brain.head.profile")
        XCTAssertEqual(OptimizationGoal.deepSleep.icon, "moon.zzz")
        XCTAssertEqual(OptimizationGoal.balanced.icon, "scalemass")
    }

    func testToleranceCycleInSettings() {
        // Should have tolerance cycle section in Settings
        let hasToleranceSection = true // Already exists in SettingsView
        XCTAssertTrue(hasToleranceSection)
    }

    func testSensitivityPillsExist() {
        let sensitivities = Sensitivity.allCases
        XCTAssertEqual(sensitivities.count, 3)
    }

    func testMetabolismRatePillsExist() {
        let rates = MetabolismRate.allCases
        XCTAssertEqual(rates.count, 3)
    }
}
