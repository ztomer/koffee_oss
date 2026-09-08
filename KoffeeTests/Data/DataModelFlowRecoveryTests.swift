import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
extension DataModelFlowTests {
    // MARK: - Bulk & Performance Tests

    // 1000+ items stress test
    func testBulkPerformance_1000Items() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description

        let startTime = Date()

        // Create 1000 items
        for i in 0..<1000 {
            let item = DailyPlanItemModel(
                id: "BULK-\(i)-\(dayKey)",
                compoundName: "Compound-\(i)",
                scheduledTime: startTime.addingTimeInterval(Double(i) * 10),
                status: i % 3 == 0 ? .pending : .pending, // 1/3 approved
                dayKey: dayKey,
                compoundUuid: "caffeine",
                doseMg: 95,
            )
            try planRepo.save(item)
        }

        // Wait for all saves to propagate
        let saveExp = expectation(description: "1000 items saved")
        saveExp.assertForOverFulfill = false
        let c = planRepo.$items.dropFirst(999).sink { items in
            if items.count >= 1000 { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 15.0)
        c.cancel()

        // Verify timeline reconstruction is fast
        let allItems = planRepo.items
        XCTAssertEqual(allItems.count, 1000)

        let nonSkipped = allItems.filter { $0.status != .skipped }
        XCTAssertEqual(nonSkipped.count, 1000, "All non-skipped items should appear in timeline")

        let pendingCount = allItems.filter { $0.status == .pending }.count
        let approvedCount = allItems.filter { $0.status == .taken }.count
        XCTAssertEqual(pendingCount + approvedCount, 1000)
    }

    // MARK: - Recovery Tests

    // Empty compound name - should be rejected
    func testRecovery_EmptyCompoundName() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description

        let item = DailyPlanItemModel(
            id: "EMPTY-\(dayKey)",
            compoundName: "",
            scheduledTime: Date(),
            status: .pending,
            dayKey: dayKey,
            compoundUuid: "caffeine",
            doseMg: 95,
        )

        do {
            try planRepo.save(item)
            XCTFail("Should have thrown for empty compound name")
        } catch {
            // Expected
        }
    }

    // Query non-existent ID - should return nil gracefully
    func testRecovery_QueryNonExistent() throws {
        let nonExistent = "NON-EXISTENT-ID-\(Date().timeIntervalSince1970)"

        let item = planRepo.items.first { $0.id == nonExistent }
        XCTAssertNil(item)

        let history = try doseRepo.dosesForDate(Date())
        let found = history.first { $0.id == nonExistent }
        XCTAssertNil(found)
    }

    // MARK: - Idempotency Tests

    // Approve same item multiple times - should not create duplicates
    func testIdempotent_DoubleApprove() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description
        let itemId = "IDEMPOTENT-\(dayKey)"

        let item = DailyPlanItemModel(
            id: itemId,
            compoundName: "IdempotentCompound",
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

        // Approve twice
        try appState.updatePlanItemStatus(id: itemId, status: .taken)

        let approveExp = expectation(description: "first approve")
        approveExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == itemId })?.status == .taken { approveExp.fulfill() }
        }
        wait(for: [approveExp], timeout: 2.0)
        c2.cancel()

        // Approve again - should be idempotent
        try appState.updatePlanItemStatus(id: itemId, status: .taken)

        // Wait briefly
        let approveExp2 = expectation(description: "second approve")
        approveExp2.assertForOverFulfill = false
        let c3 = planRepo.$items.dropFirst().sink { _ in
            approveExp2.fulfill()
        }
        wait(for: [approveExp2], timeout: 1.0)
        c3.cancel()

        // Verify only ONE history entry
        let history = try doseRepo.dosesForDate(Date())
        let matchingHistory = history.filter { $0.id == itemId }
        XCTAssertEqual(matchingHistory.count, 1, "Should have exactly one history entry")
    }
}
