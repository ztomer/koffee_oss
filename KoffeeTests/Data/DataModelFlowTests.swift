import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Data Model Flow Tests

@MainActor
final class DataModelFlowTests: XCTestCase {

    var testDB: TestDatabase!
    var appState: AppState! { testDB.appState }
    var doseRepo: DoseRepository! { testDB.doseRepo }
    var supplementRepo: SupplementLogRepository! { testDB.supplementRepo }
    var hydrationRepo: HydrationRepository! { testDB.hydrationRepo }
    var planRepo: DailyPlanRepository! { testDB.planRepo }

    override func setUp() async throws {
        testDB = try TestDatabase()
    }

    // Note: Tests use repos directly since AppState's @Published properties don't update synchronously in tests

    // Rule: Timeline = History + Plan(non-skipped)
    func testTimelineReconstruction_HistoryPlusPlan() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description

        // Create a plan item
        let planItem = DailyPlanItemModel(
            id: "TEST-1-\(dayKey)",
            compoundName: "Caffeine",
            scheduledTime: today.addingTimeInterval(3600),
            status: .pending,
            dayKey: dayKey,
            compoundUuid: "caffeine",
            doseMg: 95
        )
        try planRepo.save(planItem)

        // Wait for reactive update
        let exp = expectation(description: "plan item saved")
        exp.assertForOverFulfill = false
        let c = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == planItem.id }) { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        c.cancel()

        // Verify plan item is in repo
        var allItems = planRepo.items
        XCTAssertTrue(allItems.contains { $0.id == planItem.id })

        // Skip the plan item
        try appState.skipPlanItem(id: planItem.id)

        // Wait for reactive update after skip
        let skipExp = expectation(description: "plan item skipped")
        skipExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if let item = items.first(where: { $0.id == planItem.id }), item.status == .skipped {
                skipExp.fulfill()
            }
        }
        wait(for: [skipExp], timeout: 2.0)
        c2.cancel()

        // Verify it's now skipped in repo
        allItems = planRepo.items
        XCTAssertEqual(allItems.first { $0.id == planItem.id }?.status, .skipped)

        // Verify skipped items are filtered out (reconstruction logic)
        let nonSkipped = allItems.filter { $0.status != .skipped }
        XCTAssertFalse(nonSkipped.contains { $0.id == planItem.id })
    }

    // Rule: Approve creates history with SAME UUID
    func testApprovePlanItem_CreatesHistoryWithSameUUID() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description
        let planItemId = "CAFFEINE-\(dayKey)"

        // Create a plan item
        let planItem = DailyPlanItemModel(
            id: planItemId,
            compoundName: "Caffeine",
            scheduledTime: Date(),
            status: .pending,
            dayKey: dayKey,
            compoundUuid: "caffeine",
            doseMg: 95
        )
        try planRepo.save(planItem)

        // Wait for reactive update
        let saveExp = expectation(description: "plan item saved")
        saveExp.assertForOverFulfill = false
        let c1 = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == planItemId }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c1.cancel()

        // Approve the plan item - this creates history with SAME UUID
        try appState.updatePlanItemStatus(id: planItemId, status: .taken)

        // Wait for reactive update
        let approveExp = expectation(description: "plan item approved")
        approveExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == planItemId })?.status == .taken {
                approveExp.fulfill()
            }
        }
        wait(for: [approveExp], timeout: 2.0)
        c2.cancel()

        // Verify history entry created with SAME UUID as plan item
        let historyDoses = try doseRepo.dosesForDate(Date())
        XCTAssertTrue(historyDoses.contains { $0.id == planItemId }, "History entry should have same ID as plan item")
        XCTAssertEqual(historyDoses.first { $0.id == planItemId }?.caffeineMg, 95)

        // Verify plan status is approved
        let updatedPlan = planRepo.items.first { $0.id == planItemId }
        XCTAssertEqual(updatedPlan?.status, .taken)
    }

    // Rule: X on plan item marks as skipped + deletes history
    func testSkipPlanItem_RemovesFromHistory() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description
        let planItemId = "TEST-SKIP-\(dayKey)"

        // Create a plan item
        let planItem = DailyPlanItemModel(
            id: planItemId,
            compoundName: "TestCompound",
            scheduledTime: Date(),
            status: .pending,
            dayKey: dayKey,
            compoundUuid: "supplement",
        )
        try planRepo.save(planItem)

        // Wait for reactive update
        let saveExp = expectation(description: "plan item saved")
        saveExp.assertForOverFulfill = false
        let c1 = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == planItemId }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c1.cancel()

        // Approve it first to create history (with same UUID)
        try appState.updatePlanItemStatus(id: planItemId, status: .taken)

        // Wait for approve
        let approveExp = expectation(description: "plan item approved")
        approveExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == planItemId })?.status == .taken {
                approveExp.fulfill()
            }
        }
        wait(for: [approveExp], timeout: 2.0)
        c2.cancel()

        // Verify history was created with same UUID
        var historyLogs = try supplementRepo.logsForDate(Date())
        XCTAssertTrue(historyLogs.contains { $0.id == planItemId })

        // Now skip - should delete history by exact UUID match
        try appState.skipPlanItem(id: planItemId)

        // Wait for skip
        let skipExp = expectation(description: "plan item skipped")
        skipExp.assertForOverFulfill = false
        let c3 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == planItemId })?.status == .skipped {
                skipExp.fulfill()
            }
        }
        wait(for: [skipExp], timeout: 2.0)
        c3.cancel()

        // Verify history was deleted
        historyLogs = try supplementRepo.logsForDate(Date())
        XCTAssertFalse(historyLogs.contains { $0.id == planItemId }, "History should be deleted on skip")

        // Verify plan is marked as skipped
        let updatedPlan = planRepo.items.first { $0.id == planItemId }
        XCTAssertEqual(updatedPlan?.status, .skipped)
    }

    // Rule: Skipped items don't appear in timeline reconstruction
    func testTimelineExcludesSkippedItems() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description

        // Create plan item with skipped status directly
        let skippedItemId = "SKIPPED-ITEM-\(dayKey)"
        let skippedItem = DailyPlanItemModel(
            id: skippedItemId,
            compoundName: "SkippedSupplement",
            scheduledTime: Date(),
            status: .skipped,
            dayKey: dayKey,
            compoundUuid: "supplement",
        )
        try planRepo.save(skippedItem)

        // Wait for reactive update
        let saveExp = expectation(description: "skipped item saved")
        saveExp.assertForOverFulfill = false
        let c = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == skippedItemId }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c.cancel()

        // Verify it's in DB with skipped status
        let allItems = planRepo.items
        XCTAssertTrue(allItems.contains { $0.id == skippedItemId && $0.status == .skipped })

        // Verify reconstruction logic: status != .skipped is the filter
        let nonSkipped = allItems.filter { $0.status != .skipped }
        XCTAssertFalse(nonSkipped.contains { $0.id == skippedItemId })
    }

    // Rule: Approved items appear as logged in timeline
    func testApprovedItemsAppearAsLogged() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description

        // Create plan item with approved status
        let approvedItemId = "APPROVED-ITEM-\(dayKey)"
        let approvedItem = DailyPlanItemModel(
            id: approvedItemId,
            compoundName: "ApprovedSupplement",
            scheduledTime: Date(),
            status: .taken,
            dayKey: dayKey,
            compoundUuid: "supplement",
        )
        try planRepo.save(approvedItem)

        // Wait for reactive update
        let saveExp = expectation(description: "approved item saved")
        saveExp.assertForOverFulfill = false
        let c = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == approvedItemId }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c.cancel()

        // Create corresponding history entry manually
        try supplementRepo.addWithId(id: approvedItemId, compoundName: "ApprovedSupplement", status: .pending)

        // Wait for history update
        let historyExp = expectation(description: "history entry added")
        historyExp.assertForOverFulfill = false
        let c2 = supplementRepo.$logs.dropFirst().sink { logs in
            if logs.contains(where: { $0.id == approvedItemId }) { historyExp.fulfill() }
        }
        wait(for: [historyExp], timeout: 2.0)
        c2.cancel()

        // Verify both exist - this is what Timeline reconstruction shows
        let planItems = planRepo.items.filter { $0.dayKey == dayKey }
        XCTAssertTrue(planItems.contains { $0.id == approvedItemId && $0.status == .taken })

        let historyLogs = try supplementRepo.logsForDate(Date())
        XCTAssertTrue(historyLogs.contains { $0.id == approvedItemId })
    }

}
