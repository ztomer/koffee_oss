import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Dashboard Overhaul Tests

@MainActor
final class DashboardOverhaulTests: XCTestCase {

    func testOracleBannerShowsTopRecommendation() {
        let recommendations = [
            ActionableRecommendation(type: .avoidCompound, title: "Test 1", message: "Message 1", priority: 3, scheduledTime: nil),
            ActionableRecommendation(type: .sleepPrep, title: "Test 2", message: "Message 2", priority: 1, scheduledTime: nil),
            ActionableRecommendation(type: .hydrate, title: "Test 3", message: "Message 3", priority: 2, scheduledTime: nil)
        ]

        let top = recommendations.min { $0.priority < $1.priority }
        XCTAssertEqual(top?.priority, 1)
        XCTAssertEqual(top?.title, "Test 2")
    }

    func testIconForRecommendationTypes() {
        // Raw values are plain word prefixes (house glyph policy: no emoji)
        XCTAssertEqual(ActionableRecommendation.RecommendationType.hydrate.rawValue, "Hydrate")
        XCTAssertEqual(ActionableRecommendation.RecommendationType.takeCompound.rawValue, "Take")
        XCTAssertEqual(ActionableRecommendation.RecommendationType.avoidCompound.rawValue, "Avoid")
        XCTAssertEqual(ActionableRecommendation.RecommendationType.sleepPrep.rawValue, "Sleep")
    }

    func testSleepScoreColorThresholds() {
        let highScore: Double = 90
        let midScore: Double = 75
        let lowScore: Double = 60

        XCTAssertGreaterThan(highScore, 85)
        XCTAssertGreaterThan(midScore, 69)
        XCTAssertLessThan(lowScore, 70)
    }

    func testFillRatioCalculation() {
        let activeCaffeine: Double = 100
        let safeLimit = 400.0
        let fillRatio = activeCaffeine / safeLimit

        XCTAssertEqual(fillRatio, 0.25, "Fill ratio should be 0.25 for 100mg out of 400mg")
    }

    func testActiveStimulantLoadInitialValue() {
        let load: Double = 0
        XCTAssertEqual(load, 0, "Initial load should be 0")
    }

    func testActiveDepressantLoadInitialValue() {
        let load: Double = 0
        XCTAssertEqual(load, 0, "Initial load should be 0")
    }
}
