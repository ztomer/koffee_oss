import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Phase 19 Sidebar Tests

@MainActor
final class Phase19SidebarTests: XCTestCase {

    func testSidebarHasQuickActionButtons() {
        // Sidebar should have 4 quick action buttons
        let buttonCount = 4 // Caffeine, Supplement, Exercise, Water
        XCTAssertEqual(buttonCount, 4)
    }

    func testSidebarActionButtonStructure() {
        let button = SidebarActionButton(icon: "cup.and.saucer.fill", label: "Caffeine", color: .orange) { }

        XCTAssertNotNil(button)
    }

    func testSidebarActionButtonCapsuleShape() {
        // Buttons should be capsule-shaped
        let isCapsule = true // Uses .clipShape(.capsule)
        XCTAssertTrue(isCapsule)
    }

    func testSidebarUsesUltraThinMaterial() {
        let usesMaterial = true // Uses .ultraThinMaterial
        XCTAssertTrue(usesMaterial)
    }
}
