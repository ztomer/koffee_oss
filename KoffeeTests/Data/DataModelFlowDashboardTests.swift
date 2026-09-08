import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
extension DataModelFlowTests {
    // MARK: - Dashboard Calculations Tests

    // Test stimulant load calculation
    func testDashboard_StimulantLoadEmpty() throws {
        // Empty timeline should have 0 stimulant load
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description

        // No doses, no pending plan items
        let doses = appState.doses.filter { calendar.isDateInToday($0.timestamp) }
        let pendingCaffeine = appState.dailyPlanItems.filter {
            $0.compoundUuid == "caffeine" && $0.status == .pending
        }

        let stimulantLoad = doses.reduce(0) { $0 + $1.caffeineMg } + pendingCaffeine.reduce(0) { $0 + $1.doseMg }
        XCTAssertEqual(stimulantLoad, 0)
    }

    func testDashboard_StimulantLoadWithDoses() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description

        // Add a dose
        try doseRepo.addWithId(id: "TEST-DOSE-1-\(dayKey)", beverageId: nil, timestamp: Date(), caffeineMg: 95, beverageName: "Coffee")

        let saveExp = expectation(description: "dose added")
        saveExp.assertForOverFulfill = false
        let c = appState.$doses.dropFirst().sink { doses in
            if doses.count > 0 { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c.cancel()

        // Verify stimulant load includes this dose
        let doses = appState.doses.filter { calendar.isDateInToday($0.timestamp) }
        let pendingCaffeine = appState.dailyPlanItems.filter {
            $0.compoundUuid == "caffeine" && $0.status == .pending
        }

        let stimulantLoad = doses.reduce(0) { $0 + $1.caffeineMg } + pendingCaffeine.reduce(0) { $0 + $1.doseMg }
        XCTAssertEqual(stimulantLoad, 95, "95mg dose should contribute to stimulant load")
    }

    func testDashboard_StimulantLoadWithPendingPlan() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description

        // Add a pending caffeine plan item
        let pendingItem = DailyPlanItemModel(
            id: "TEST-PENDING-CAF-\(dayKey)",
            compoundName: "Caffeine",
            scheduledTime: Date(),
            status: .pending,
            dayKey: dayKey,
            compoundUuid: "caffeine",
            doseMg: 95
        )
        try planRepo.save(pendingItem)

        // Wait for planRepo to update
        let saveExp = expectation(description: "plan item saved")
        saveExp.assertForOverFulfill = false
        let c = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == "TEST-PENDING-CAF-\(dayKey)" }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c.cancel()

        // Verify the item is in planRepo
        let planItems = planRepo.items
        XCTAssertTrue(planItems.contains(where: { $0.id == "TEST-PENDING-CAF-\(dayKey)" }), "Plan item should exist in repo")

        // Now calculate stimulant load using planRepo directly (what Dashboard does via appState)
        let pendingCaffeine = planItems.filter {
            $0.compoundUuid == "caffeine" && $0.status == .pending
        }

        // There are no doses, so stimulant load should be just the pending item
        let stimulantLoad = pendingCaffeine.reduce(0) { $0 + $1.doseMg }
        XCTAssertEqual(stimulantLoad, 95, "Pending caffeine plan should contribute to stimulant load")
    }
}
