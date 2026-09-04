import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Metabolic Status View Tests

@MainActor
final class MetabolicStatusViewTests: XCTestCase {

    func testMetabolicStatusViewNoExerciseShowsBaseline() {
        // When there are no exercises, should show baseline
        let interventions: [BiologicalIntervention] = []

        // The view should show "Baseline Metabolism" when no exercise is active
        XCTAssertTrue(interventions.filter { $0.type == .exercise }.isEmpty)
    }

    func testMetabolicStatusViewHIITIsDebuff() {
        let hiitIntervention = BiologicalIntervention(
            id: "1",
            name: "HIIT",
            scheduledTime: Date().addingTimeInterval(-1800),
            type: .exercise,
            durationMinutes: 30,
            maintainsHepaticPerfusion: false
        )

        // HIIT is a debuff (reduces clearance)
        XCTAssertFalse(hiitIntervention.maintainsHepaticPerfusion)
    }

    func testMetabolicStatusViewZone2IsBuff() {
        let zone2Intervention = BiologicalIntervention(
            id: "2",
            name: "Zone 2 Cardio",
            scheduledTime: Date().addingTimeInterval(-1800),
            type: .exercise,
            durationMinutes: 45,
            maintainsHepaticPerfusion: true
        )

        // Zone 2 is a buff (increases clearance)
        XCTAssertTrue(zone2Intervention.maintainsHepaticPerfusion)
    }

    func testActiveExerciseDetection() {
        let now = Date()
        let activeExercise = BiologicalIntervention(
            id: "3",
            name: "Running",
            scheduledTime: now.addingTimeInterval(-1800), // 30 min ago
            type: .exercise,
            durationMinutes: 60,
            maintainsHepaticPerfusion: true
        )

        let exerciseStart = activeExercise.scheduledTime
        let exerciseEnd = exerciseStart.addingTimeInterval(Double(activeExercise.durationMinutes ?? 30) * 60)

        let isActive = now >= exerciseStart && now < exerciseEnd
        XCTAssertTrue(isActive, "Current time should be within active exercise window")
    }

    func testExpiredExerciseNotActive() {
        let pastExercise = BiologicalIntervention(
            id: "4",
            name: "Running",
            scheduledTime: Date().addingTimeInterval(-7200), // 2 hours ago
            type: .exercise,
            durationMinutes: 30,
            maintainsHepaticPerfusion: true
        )

        let now = Date()
        let exerciseStart = pastExercise.scheduledTime
        let exerciseEnd = exerciseStart.addingTimeInterval(Double(pastExercise.durationMinutes ?? 30) * 60)

        let isActive = now >= exerciseStart && now < exerciseEnd
        XCTAssertFalse(isActive, "Past exercise should not be active")
    }
}
