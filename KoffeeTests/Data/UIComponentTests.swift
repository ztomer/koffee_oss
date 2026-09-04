import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - UI Component Tests

@MainActor
final class UIComponentTests: XCTestCase {

    func testAllNootropicCompoundsHaveOptimalDoseMg() {
        // Custom compound has 0 dose by design (user-defined)
        let compoundsWithDose = NootropicCompound.allCases.filter { $0 != .custom }
        for compound in compoundsWithDose {
            let dose = compound.optimalDoseMg
            XCTAssertGreaterThan(dose, 0, "Compound \(compound.rawValue) should have a valid dose")
        }
    }

    func testActiveNootropicCompoundsHaveHalfLifeHours() {
        // Only active compounds should have half-life; Custom and Psyllium Husk are 0
        let activeCompounds = NootropicCompound.allCases.filter { $0 != .custom && $0 != .psylliumHusk }
        for compound in activeCompounds {
            let halfLife = compound.halfLifeHours
            XCTAssertGreaterThan(halfLife, 0, "Compound \(compound.rawValue) should have valid half-life")
        }
    }

    func testGlycineCompoundExists() {
        XCTAssertTrue(NootropicCompound.allCases.contains(where: { $0 == .glycine }))
    }

    func testGlycineProperties() {
        let glycine = NootropicCompound.glycine
        XCTAssertEqual(glycine.optimalDoseMg, 3000)
        XCTAssertEqual(glycine.halfLifeHours, 2.0)
        XCTAssertFalse(glycine.requiresFastedState)
    }

    func testGlycineInStackBuilder() {
        let stackCompounds = NootropicCompound.allCases
        XCTAssertTrue(stackCompounds.contains(.glycine))
    }
}
