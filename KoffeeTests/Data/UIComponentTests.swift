import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - UI Component Tests

@MainActor
final class UIComponentTests: XCTestCase {

    func testCaffeineCompoundHasOptimalDoseMg() {
        XCTAssertGreaterThan(NootropicCompound.caffeine.optimalDoseMg, 0, "Caffeine should have a valid dose")
    }

    func testCaffeineCompoundHasHalfLifeHours() {
        XCTAssertGreaterThan(NootropicCompound.caffeine.halfLifeHours, 0, "Caffeine should have valid half-life")
    }

    func testCaffeineCompoundProperties() {
        let caffeine = NootropicCompound.caffeine
        XCTAssertEqual(caffeine.optimalDoseMg, 95)
        XCTAssertEqual(caffeine.halfLifeHours, 5.0)
        XCTAssertFalse(caffeine.requiresFastedState)
    }

    func testCaffeineIsOnlyCompound() {
        XCTAssertEqual(NootropicCompound.allCases, [.caffeine])
    }

    func testBeverageSymbolNameMapsByCategory() {
        func symbol(for category: String) -> String {
            BeverageModel(name: "X", caffeineMg: 10, category: category, icon: category).symbolName
        }
        XCTAssertEqual(symbol(for: "Coffee"), "cup.and.saucer.fill")
        XCTAssertEqual(symbol(for: "Tea"), "leaf.fill")
        XCTAssertEqual(symbol(for: "Energy"), "bolt.fill")
        XCTAssertEqual(symbol(for: "Other"), "mug.fill")
        XCTAssertEqual(symbol(for: "coffee"), "cup.and.saucer.fill", "Mapping is case-insensitive")
    }
}
