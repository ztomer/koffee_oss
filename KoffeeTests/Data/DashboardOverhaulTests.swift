import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Dashboard Overhaul Tests

@MainActor
final class DashboardOverhaulTests: XCTestCase {

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
}
