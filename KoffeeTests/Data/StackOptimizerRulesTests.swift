import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Stack Optimizer Rules Tests

@MainActor
final class StackOptimizerRulesTests: XCTestCase {

    func testGlycineIncludedInNootropicCompound() {
        let allCompounds = NootropicCompound.allCases
        XCTAssertTrue(allCompounds.contains(.glycine))
    }

    func testGlycineHasCorrectProperties() {
        let glycine = NootropicCompound.glycine
        XCTAssertEqual(glycine.optimalDoseMg, 3000)
        XCTAssertEqual(glycine.peakTimeMinutes, 30)
        XCTAssertEqual(glycine.halfLifeHours, 2.0)
    }

    func testNootropicCompoundSynergyBenefit() {
        let caffeine = NootropicCompound.caffeine
        let ltheanine = NootropicCompound.lTheanine

        XCTAssertNotNil(caffeine.synergyBenefit)
        XCTAssertNotNil(ltheanine.synergyBenefit)
    }

    func testMagnesiumInteractionTypeIsAbsorptionInhibitor() {
        XCTAssertEqual(NootropicCompound.magnesium.interactionType, .absorptionInhibitor)
    }
}
