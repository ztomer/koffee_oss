import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
extension DataModelFlowTests {
    // MARK: - Data Consistency Tests

    // Orphaned history - history exists but plan item deleted
    func testDataConsistency_OrphanedHistory() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description
        let itemId = "ORPHAN-\(dayKey)"

        // Create and approve item (creates history)
        let item = DailyPlanItemModel(
            id: itemId,
            compoundName: "OrphanTest",
            scheduledTime: Date(),
            status: .pending,
            dayKey: dayKey,
            compoundUuid: "caffeine",
            doseMg: 95,
        )
        try planRepo.save(item)

        let saveExp = expectation(description: "item saved")
        saveExp.assertForOverFulfill = false
        let c1 = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == itemId }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c1.cancel()

        try appState.updatePlanItemStatus(id: itemId, status: .taken)

        let approveExp = expectation(description: "item approved")
        approveExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == itemId })?.status == .taken { approveExp.fulfill() }
        }
        wait(for: [approveExp], timeout: 2.0)
        c2.cancel()

        // Verify both exist
        let historyBefore = try doseRepo.dosesForDate(Date())
        XCTAssertTrue(historyBefore.contains { $0.id == itemId })

        // Delete plan item (not skip - this creates orphan)
        try planRepo.delete(id: itemId)

        // History should still exist (orphan)
        let historyAfter = try doseRepo.dosesForDate(Date())
        XCTAssertTrue(historyAfter.contains { $0.id == itemId }, "Orphaned history should persist")
    }

    // Plan says approved but no history entry
    func testDataConsistency_MissingHistory() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description
        let itemId = "MISSING-HIST-\(dayKey)"

        // Create plan item with approved status directly (no history)
        let item = DailyPlanItemModel(
            id: itemId,
            compoundName: "MissingHistory",
            scheduledTime: Date(),
            status: .taken,
            dayKey: dayKey,
            compoundUuid: "caffeine",
            doseMg: 95,
        )
        try planRepo.save(item)

        let saveExp = expectation(description: "item saved")
        saveExp.assertForOverFulfill = false
        let c = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == itemId }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c.cancel()

        // Verify plan shows approved but no history
        let planItem = planRepo.items.first { $0.id == itemId }
        XCTAssertEqual(planItem?.status, .taken)

        let history = try doseRepo.dosesForDate(Date())
        XCTAssertFalse(history.contains { $0.id == itemId }, "No history for manual approved item")
    }

    // MARK: - Time Edge Cases

    // Midnight boundary - item at exactly 00:00
    func testTimeEdgeCase_Midnight() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayKey = calendar.dateComponents([.year, .month, .day], from: today).description

        // Create item at midnight
        let item = DailyPlanItemModel(
            id: "MIDNIGHT-\(dayKey)",
            compoundName: "MidnightCompound",
            scheduledTime: today, // Exactly midnight
            status: .pending,
            dayKey: dayKey,
            compoundUuid: "caffeine",
            doseMg: 95,
        )
        try planRepo.save(item)

        let saveExp = expectation(description: "midnight item saved")
        saveExp.assertForOverFulfill = false
        let c = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == "MIDNIGHT-\(dayKey)" }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c.cancel()

        // Query for today's items
        let todayItems = try planRepo.itemsForDay(today)
        XCTAssertTrue(todayItems.contains { $0.id == "MIDNIGHT-\(dayKey)" }, "Midnight item should be in today")

        // Approve at midnight - should work
        try appState.updatePlanItemStatus(id: "MIDNIGHT-\(dayKey)", status: .taken)

        let approveExp = expectation(description: "midnight approved")
        approveExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == "MIDNIGHT-\(dayKey)" })?.status == .taken {
                approveExp.fulfill()
            }
        }
        wait(for: [approveExp], timeout: 2.0)
        c2.cancel()

        // History should be created
        let history = try doseRepo.dosesForDate(today)
        XCTAssertTrue(history.contains { $0.id == "MIDNIGHT-\(dayKey)" })
    }

    // Year boundary - items around Dec 31 / Jan 1
    func testTimeEdgeCase_YearBoundary() throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 31
        components.hour = 23
        let dec31 = calendar.date(from: components)!

        components.year = 2026
        components.month = 1
        components.day = 1
        components.hour = 1
        let jan1 = calendar.date(from: components)!

        // Save Dec 31 item
        let dec31Key = calendar.dateComponents([.year, .month, .day], from: dec31).description
        let dec31Item = DailyPlanItemModel(
            id: "DEC31-\(dec31Key)",
            compoundName: "Dec31Compound",
            scheduledTime: dec31,
            status: .pending,
            dayKey: dec31Key,
            compoundUuid: "caffeine",
            doseMg: 95,
        )
        try planRepo.save(dec31Item)

        let saveExp1 = expectation(description: "dec31 saved")
        saveExp1.assertForOverFulfill = false
        let c1 = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == "DEC31-\(dec31Key)" }) { saveExp1.fulfill() }
        }
        wait(for: [saveExp1], timeout: 2.0)
        c1.cancel()

        // Save Jan 1 item
        let jan1Key = calendar.dateComponents([.year, .month, .day], from: jan1).description
        let jan1Item = DailyPlanItemModel(
            id: "JAN1-\(jan1Key)",
            compoundName: "Jan1Compound",
            scheduledTime: jan1,
            status: .pending,
            dayKey: jan1Key,
            compoundUuid: "caffeine",
            doseMg: 95,
        )
        try planRepo.save(jan1Item)

        let saveExp2 = expectation(description: "jan1 saved")
        saveExp2.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == "JAN1-\(jan1Key)" }) { saveExp2.fulfill() }
        }
        wait(for: [saveExp2], timeout: 2.0)
        c2.cancel()

        // Verify they belong to different days
        let dec31Items = try planRepo.itemsForDay(dec31)
        let jan1Items = try planRepo.itemsForDay(jan1)

        XCTAssertEqual(dec31Items.count, 1)
        XCTAssertEqual(jan1Items.count, 1)
        XCTAssertEqual(dec31Items.first?.id, "DEC31-\(dec31Key)")
        XCTAssertEqual(jan1Items.first?.id, "JAN1-\(jan1Key)")
    }
}
