import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
extension DataModelFlowTests {
    // MARK: - State Machine Tests

    // Skip -> Approve - can a skipped item be approved again?
    func testStateMachine_SkippedToApproved() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description
        let itemId = "STATE-SKIP-APPROVE-\(dayKey)"

        let item = DailyPlanItemModel(
            id: itemId,
            compoundName: "TestCompound",
            scheduledTime: Date(),
            status: .pending,
            dayKey: dayKey,
            compoundUuid: "caffeine",
            doseMg: 95
        )
        try planRepo.save(item)

        let saveExp = expectation(description: "item saved")
        saveExp.assertForOverFulfill = false
        let c1 = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == itemId }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c1.cancel()

        // Skip the item
        try appState.skipPlanItem(id: itemId)

        let skipExp = expectation(description: "item skipped")
        skipExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == itemId })?.status == .skipped {
                skipExp.fulfill()
            }
        }
        wait(for: [skipExp], timeout: 2.0)
        c2.cancel()

        // Approve the skipped item - should work
        try appState.updatePlanItemStatus(id: itemId, status: .taken)

        let approveExp = expectation(description: "item approved")
        approveExp.assertForOverFulfill = false
        let c3 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == itemId })?.status == .taken {
                approveExp.fulfill()
            }
        }
        wait(for: [approveExp], timeout: 2.0)
        c3.cancel()

        // Verify plan is approved and history was created.
        // Item is caffeine, so its "history" is a dose entry (not supplement_logs).
        let planItem = planRepo.items.first { $0.id == itemId }
        XCTAssertEqual(planItem?.status, .taken)

        let historyDoses = try doseRepo.dosesForDate(Date())
        XCTAssertTrue(historyDoses.contains { $0.id == itemId }, "History should be created on approve after skip")
    }

    // Full cycle: Pending -> Approve -> Skip -> Approve
    func testStateMachine_FullCycle() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description
        let itemId = "STATE-CYCLE-\(dayKey)"

        let item = DailyPlanItemModel(
            id: itemId,
            compoundName: "CycleCompound",
            scheduledTime: Date(),
            status: .pending,
            dayKey: dayKey,
            compoundUuid: "supplement",
        )
        try planRepo.save(item)

        let saveExp = expectation(description: "item saved")
        saveExp.assertForOverFulfill = false
        let c1 = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == itemId }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c1.cancel()

        // 1. Approve
        try appState.updatePlanItemStatus(id: itemId, status: .taken)

        let approveExp = expectation(description: "item approved")
        approveExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == itemId })?.status == .taken { approveExp.fulfill() }
        }
        wait(for: [approveExp], timeout: 2.0)
        c2.cancel()

        var history = try supplementRepo.logsForDate(Date())
        XCTAssertTrue(history.contains { $0.id == itemId }, "Should have history after approve")

        // 2. Skip
        try appState.updatePlanItemStatus(id: itemId, status: .skipped)

        let skipExp = expectation(description: "item skipped")
        skipExp.assertForOverFulfill = false
        let c3 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == itemId })?.status == .skipped { skipExp.fulfill() }
        }
        wait(for: [skipExp], timeout: 2.0)
        c3.cancel()

        history = try supplementRepo.logsForDate(Date())
        XCTAssertFalse(history.contains { $0.id == itemId }, "History should be deleted after skip")

        // 3. Approve again
        try appState.updatePlanItemStatus(id: itemId, status: .taken)

        let reapproveExp = expectation(description: "item re-approved")
        reapproveExp.assertForOverFulfill = false
        let c4 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == itemId })?.status == .taken { reapproveExp.fulfill() }
        }
        wait(for: [reapproveExp], timeout: 2.0)
        c4.cancel()

        // Verify final state
        let planItem = planRepo.items.first { $0.id == itemId }
        XCTAssertEqual(planItem?.status, .taken)

        history = try supplementRepo.logsForDate(Date())
        XCTAssertTrue(history.contains { $0.id == itemId }, "History should exist after re-approve")
    }

    // Pending -> Removed - direct removal of pending item
    func testStateMachine_PendingToRemoved() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description
        let itemId = "STATE-REMOVE-\(dayKey)"

        let item = DailyPlanItemModel(
            id: itemId,
            compoundName: "RemoveMe",
            scheduledTime: Date(),
            status: .pending,
            dayKey: dayKey,
            compoundUuid: "supplement",
        )
        try planRepo.save(item)

        let saveExp = expectation(description: "item saved")
        saveExp.assertForOverFulfill = false
        let c1 = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == itemId }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c1.cancel()

        // Remove the item (direct deletion - skipping would retain it as .skipped)
        try planRepo.delete(id: itemId)

        // Wait for reactive update after removal
        let removeExp = expectation(description: "item removed")
        removeExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if !items.contains(where: { $0.id == itemId }) { removeExp.fulfill() }
        }
        wait(for: [removeExp], timeout: 2.0)
        c2.cancel()

        // Verify it's gone from plan
        let allItems = planRepo.items
        XCTAssertFalse(allItems.contains { $0.id == itemId }, "Removed item should not exist in plan")
    }

    // Query removed item - should be gracefully handled
    func testStateMachine_QueryRemovedItem() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description
        let itemId = "STATE-QUERY-REMOVED-\(dayKey)"

        let item = DailyPlanItemModel(
            id: itemId,
            compoundName: "WillBeRemoved",
            scheduledTime: Date(),
            status: .pending,
            dayKey: dayKey,
            compoundUuid: "supplement",
        )
        try planRepo.save(item)

        let saveExp = expectation(description: "item saved")
        saveExp.assertForOverFulfill = false
        let c1 = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == itemId }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c1.cancel()

        // Remove
        try planRepo.delete(id: itemId)

        // Wait for removal to propagate
        let removeExp = expectation(description: "item removed")
        removeExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if !items.contains(where: { $0.id == itemId }) { removeExp.fulfill() }
        }
        wait(for: [removeExp], timeout: 2.0)
        c2.cancel()

        // Try to update removed item - should not crash
        try appState.updatePlanItemStatus(id: itemId, status: .taken)

        // Verify still not in plan (cannot resurrect)
        let allItems = planRepo.items
        XCTAssertFalse(allItems.contains { $0.id == itemId })
    }
}
