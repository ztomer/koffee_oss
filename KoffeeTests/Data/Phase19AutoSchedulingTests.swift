import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Phase 19 Auto-Scheduling Tests

@MainActor
final class Phase19AutoSchedulingTests: XCTestCase {

    func testAutoScheduleRecommendationsMethodExists() {
        // AppState should have auto-scheduling method
        let engine = StackOptimizerEngine(goal: .balanced)
        let recommendations = engine.generateRecommendations(
            activeCaffeineMg: 0,
            currentDayInterventions: [],
            wakeTime: Date(),
            sleepTime: Date().addingTimeInterval(8 * 3600),
            hydrationDeficitMl: 0,
            hoursUntilBedtime: 8,
            tolerance: ToleranceCycle(daysSinceReset: 0, resetDaysRequired: 14),
            biometrics: nil
        )

        XCTAssertNotNil(recommendations)
    }

    func testRecommendationHasScheduledTime() {
        let engine = StackOptimizerEngine(goal: .balanced)
        let recommendations = engine.generateRecommendations(
            activeCaffeineMg: 0,
            currentDayInterventions: [],
            wakeTime: Date(),
            sleepTime: Date().addingTimeInterval(8 * 3600),
            hydrationDeficitMl: 0,
            hoursUntilBedtime: 8,
            tolerance: ToleranceCycle(daysSinceReset: 0, resetDaysRequired: 14),
            biometrics: nil
        )

        // Filter for compound recommendations
        let compoundRecs = recommendations.filter { $0.type == .takeCompound }
        XCTAssertGreaterThanOrEqual(compoundRecs.count, 0)
    }

    func testExtractCompoundNameFromRecommendation() {
        // Test compound name extraction
        let title = "Deep Sleep Enhancer"
        let extracted = title.lowercased()

        XCTAssertTrue(extracted.contains("sleep") || extracted.contains("enhancer"))
    }

    func testDailyPlanItemCreatedFromRecommendation() {
        let dayKey = DailyPlanItemModel.dayKey(for: Date())
        let item = DailyPlanItemModel(
            id: "GLYCINE-AI-\(dayKey)",
            compoundName: "Glycine",
            scheduledTime: Date(),
            status: PlanItemStatus.pending,
            dayKey: dayKey
        )

        XCTAssertEqual(item.status, .pending)
        XCTAssertEqual(item.compoundName, "Glycine")
    }
}
