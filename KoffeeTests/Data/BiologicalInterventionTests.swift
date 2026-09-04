import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Biological Intervention Tests

@MainActor
final class BiologicalInterventionTests: XCTestCase {

    func testBiologicalInterventionInitWithExercise() {
        let intervention = BiologicalIntervention(
            id: "1",
            name: "HIIT",
            scheduledTime: Date(),
            type: .exercise,
            durationMinutes: 30,
            maintainsHepaticPerfusion: false
        )

        XCTAssertEqual(intervention.id, "1")
        XCTAssertEqual(intervention.name, "HIIT")
        XCTAssertEqual(intervention.type, .exercise)
        XCTAssertEqual(intervention.durationMinutes, 30)
        XCTAssertFalse(intervention.maintainsHepaticPerfusion)
    }

    func testBiologicalInterventionDefaultDuration() {
        let intervention = BiologicalIntervention(
            id: "2",
            name: "Running",
            scheduledTime: Date(),
            type: .exercise
        )

        XCTAssertNil(intervention.durationMinutes)
        XCTAssertTrue(intervention.maintainsHepaticPerfusion) // default is true
    }

    func testBiologicalInterventionSupplementsHaveNoDuration() {
        let intervention = BiologicalIntervention(
            id: "3",
            name: "Caffeine",
            scheduledTime: Date(),
            type: .supplement
        )

        XCTAssertNil(intervention.durationMinutes)
        XCTAssertTrue(intervention.maintainsHepaticPerfusion)
    }

    func testBiologicalInterventionZone2CardioMaintainsPerfusion() {
        let intervention = BiologicalIntervention(
            id: "4",
            name: "Zone 2 Cardio",
            scheduledTime: Date(),
            type: .exercise,
            durationMinutes: 45,
            maintainsHepaticPerfusion: true
        )

        XCTAssertTrue(intervention.maintainsHepaticPerfusion)
        XCTAssertEqual(intervention.type, .exercise)
    }

    func testBiologicalInterventionHIITDoesNotMaintainPerfusion() {
        let intervention = BiologicalIntervention(
            id: "5",
            name: "HIIT",
            scheduledTime: Date(),
            type: .exercise,
            durationMinutes: 20,
            maintainsHepaticPerfusion: false
        )

        XCTAssertFalse(intervention.maintainsHepaticPerfusion)
    }
}
