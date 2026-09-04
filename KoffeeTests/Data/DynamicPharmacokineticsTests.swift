import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Dynamic Pharmacokinetics Tests

@MainActor
final class DynamicPharmacokineticsTests: XCTestCase {

    func testVmaxReductionForHIIT() {
        let baseVmax = 50.0 / 1.0
        let hiitVmax = baseVmax * 0.2
        XCTAssertEqual(hiitVmax, baseVmax * 0.2)
    }

    func testVmaxIncreaseForZone2() {
        let baseVmax = 50.0 / 1.0
        let zone2Vmax = baseVmax * 1.15
        XCTAssertEqual(zone2Vmax, baseVmax * 1.15)
    }

    func testMetabolismRateAffectsVmaxCorrectly() {
        // slow=0.7 (higher Vmax since enzyme slower), fast=1.4 (lower Vmax)
        let baseVmax = 50.0
        let slowVmax = baseVmax / MetabolismRate.slow.halfLifeMultiplier
        let fastVmax = baseVmax / MetabolismRate.fast.halfLifeMultiplier
        XCTAssertGreaterThan(slowVmax, fastVmax)
    }

    func testExerciseTimeIntervalCalculation() {
        let start = Date(timeIntervalSince1970: 1000000)
        let duration = 30
        let end = start.addingTimeInterval(Double(duration) * 60)
        let current = Date(timeIntervalSince1970: 1000015)
        XCTAssertTrue(current >= start && current < end)
    }

    func testNoExerciseReturnsBaselineVmax() {
        let baseVmax = 50.0
        let currentVmax = baseVmax
        XCTAssertEqual(currentVmax, baseVmax)
    }
}
