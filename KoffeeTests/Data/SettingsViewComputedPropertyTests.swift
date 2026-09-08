import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Settings View Computed Properties Tests

@MainActor
final class SettingsViewComputedPropertyTests: XCTestCase {

    func testSensitivityDisplayNames() {
        XCTAssertEqual(Sensitivity.low.displayName, "Low")
        XCTAssertEqual(Sensitivity.medium.displayName, "Medium")
        XCTAssertEqual(Sensitivity.high.displayName, "High")
    }

    func testMetabolismRateDisplayNames() {
        // Display names include genetic info
        XCTAssertTrue(MetabolismRate.slow.displayName.contains("Slow"))
        XCTAssertTrue(MetabolismRate.medium.displayName.contains("Medium"))
        XCTAssertTrue(MetabolismRate.fast.displayName.contains("Fast"))
    }

    func testSensitivitySafeCaffeineAtBedtime() {
        XCTAssertEqual(Sensitivity.high.safeCaffeineAtBedtime, 25)
        XCTAssertEqual(Sensitivity.medium.safeCaffeineAtBedtime, 50)
        XCTAssertEqual(Sensitivity.low.safeCaffeineAtBedtime, 100)
    }

    func testBiologicalSexCases() {
        XCTAssertEqual(BiologicalSex.allCases.count, 2)
        XCTAssertTrue(BiologicalSex.allCases.contains(.male))
        XCTAssertTrue(BiologicalSex.allCases.contains(.female))
    }
}
