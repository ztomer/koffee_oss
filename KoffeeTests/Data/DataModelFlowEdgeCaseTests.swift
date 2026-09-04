import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
extension DataModelFlowTests {
    // MARK: - Edge Cases

    // Large database - many entries should not cause performance issues
    func testLargeDatabase_Performance() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description

        // Create 100 plan items
        let startTime = Date()
        for i in 0..<100 {
            let item = DailyPlanItemModel(
                id: "LARGE-\(i)-\(dayKey)",
                compoundName: "Compound-\(i)",
                scheduledTime: startTime.addingTimeInterval(Double(i) * 60),
                status: .pending,
                dayKey: dayKey,
                compoundUuid: "supplement",
            )
            try planRepo.save(item)
        }

        // Wait for all to be saved
        let saveExp = expectation(description: "100 items saved")
        saveExp.assertForOverFulfill = false
        let c = planRepo.$items.dropFirst(99).sink { items in
            if items.count >= 100 { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 5.0)
        c.cancel()

        // Verify all loaded
        let allItems = planRepo.items.filter { $0.dayKey == dayKey }
        XCTAssertEqual(allItems.count, 100)

        // Timeline reconstruction should handle this
        let nonSkipped = allItems.filter { $0.status != .skipped }
        XCTAssertEqual(nonSkipped.count, 100)
    }

    // Rapid changes - quickly approve then skip should work correctly
    func testRapidChanges_ApproveThenSkip() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description
        let itemId = "RAPID-\(dayKey)"

        // Create plan item
        let item = DailyPlanItemModel(
            id: itemId,
            compoundName: "RapidTest",
            scheduledTime: Date(),
            status: .pending,
            dayKey: dayKey,
            compoundUuid: "supplement",
        )
        try planRepo.save(item)

        // Wait for save
        let saveExp = expectation(description: "item saved")
        saveExp.assertForOverFulfill = false
        let c1 = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == itemId }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c1.cancel()

        // Approve
        try appState.updatePlanItemStatus(id: itemId, status: .taken)

        // Immediately skip (no waiting)
        try appState.updatePlanItemStatus(id: itemId, status: .skipped)

        // Wait for skip
        let skipExp = expectation(description: "item skipped")
        skipExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == itemId })?.status == .skipped {
                skipExp.fulfill()
            }
        }
        wait(for: [skipExp], timeout: 2.0)
        c2.cancel()

        // Verify: plan is skipped, history is deleted
        let planItem = planRepo.items.first { $0.id == itemId }
        XCTAssertEqual(planItem?.status, .skipped)

        let historyLogs = try supplementRepo.logsForDate(Date())
        XCTAssertFalse(historyLogs.contains { $0.id == itemId })
    }

    // Past data integrity - changing today's items doesn't affect yesterday
    func testPastDataIntegrity_YesterdayUnaffected() throws {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayKey = calendar.dateComponents([.year, .month, .day], from: yesterday).description
        let todayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description

        // Create yesterday's item
        let yesterdayItem = DailyPlanItemModel(
            id: "YESTERDAY-1-\(yesterdayKey)",
            compoundName: "YesterdayCompound",
            scheduledTime: yesterday,
            status: .taken,
            dayKey: yesterdayKey,
            compoundUuid: "supplement",
        )
        try planRepo.save(yesterdayItem)

        // Create yesterday's history with YESTERDAY's timestamp
        let yesterdayLog = SupplementLogModel(id: "YESTERDAY-1-\(yesterdayKey)", compoundName: "YesterdayCompound",
                                              timestamp: yesterday, status: PlanItemStatus.pending)
        try testDB.db.write { db in try yesterdayLog.insert(db) }

        // Wait for plan item to appear
        let saveExp = expectation(description: "yesterday item saved")
        saveExp.assertForOverFulfill = false
        let c = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == "YESTERDAY-1-\(yesterdayKey)" }) {
                saveExp.fulfill()
            }
        }
        wait(for: [saveExp], timeout: 2.0)
        c.cancel()

        // Verify yesterday data exists via DB read (not repo items, which may not have all historical data)
        let yesterdayItems = try planRepo.itemsForDay(yesterday)
        XCTAssertEqual(yesterdayItems.count, 1, "Yesterday plan should have 1 item")
        XCTAssertEqual(yesterdayItems.first?.status, .taken)

        let yesterdayHistory = try supplementRepo.logsForDate(yesterday)
        XCTAssertEqual(yesterdayHistory.count, 1, "Yesterday history should have 1 entry")
        XCTAssertEqual(yesterdayHistory.first?.id, "YESTERDAY-1-\(yesterdayKey)")

        // Now create today's item
        let todayItem = DailyPlanItemModel(
            id: "TODAY-1-\(todayKey)",
            compoundName: "TodayCompound",
            scheduledTime: Date(),
            status: .pending,
            dayKey: todayKey,
            compoundUuid: "supplement",
        )
        try planRepo.save(todayItem)

        let todaySaveExp = expectation(description: "today item saved")
        todaySaveExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == "TODAY-1-\(todayKey)" }) { todaySaveExp.fulfill() }
        }
        wait(for: [todaySaveExp], timeout: 2.0)
        c2.cancel()

        // Skip today's item
        try appState.skipPlanItem(id: "TODAY-1-\(todayKey)")

        let skipExp = expectation(description: "today skipped")
        skipExp.assertForOverFulfill = false
        let c3 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == "TODAY-1-\(todayKey)" })?.status == .skipped {
                skipExp.fulfill()
            }
        }
        wait(for: [skipExp], timeout: 2.0)
        c3.cancel()

        // Verify yesterday is STILL unaffected
        let yesterdayItemsAfter = try planRepo.itemsForDay(yesterday)
        XCTAssertEqual(yesterdayItemsAfter.count, 1)
        XCTAssertEqual(yesterdayItemsAfter.first?.status, .taken)

        let yesterdayHistoryAfter = try supplementRepo.logsForDate(yesterday)
        XCTAssertEqual(yesterdayHistoryAfter.count, 1)
        XCTAssertEqual(yesterdayHistoryAfter.first?.id, "YESTERDAY-1-\(yesterdayKey)")

        // Verify today's is skipped
        let todayItems = try planRepo.itemsForDay(Date())
        let todayPlan = todayItems.first { $0.id == "TODAY-1-\(todayKey)" }
        XCTAssertEqual(todayPlan?.status, .skipped)
    }

    // Future data integrity - changing today's items doesn't affect tomorrow
    func testFutureDataIntegrity_TomorrowUnaffected() throws {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowKey = calendar.dateComponents([.year, .month, .day], from: tomorrow).description
        let todayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description

        // Create tomorrow's item (pending)
        let tomorrowItem = DailyPlanItemModel(
            id: "TOMORROW-1-\(tomorrowKey)",
            compoundName: "TomorrowCompound",
            scheduledTime: tomorrow,
            status: .pending,
            dayKey: tomorrowKey,
            compoundUuid: "supplement",
        )
        try planRepo.save(tomorrowItem)

        // Wait for save
        let saveExp = expectation(description: "tomorrow item saved")
        saveExp.assertForOverFulfill = false
        let c = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == "TOMORROW-1-\(tomorrowKey)" }) { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c.cancel()

        // Create today's item and approve it
        let todayItem = DailyPlanItemModel(
            id: "TODAY-1-\(todayKey)",
            compoundName: "TodayCompound",
            scheduledTime: Date(),
            status: .pending,
            dayKey: todayKey,
            compoundUuid: "caffeine",
            doseMg: 95
        )
        try planRepo.save(todayItem)

        let todaySaveExp = expectation(description: "today item saved")
        todaySaveExp.assertForOverFulfill = false
        let c2 = planRepo.$items.dropFirst().sink { items in
            if items.contains(where: { $0.id == "TODAY-1-\(todayKey)" }) { todaySaveExp.fulfill() }
        }
        wait(for: [todaySaveExp], timeout: 2.0)
        c2.cancel()

        // Approve today's item
        try appState.updatePlanItemStatus(id: "TODAY-1-\(todayKey)", status: .taken)

        let approveExp = expectation(description: "today approved")
        approveExp.assertForOverFulfill = false
        let c3 = planRepo.$items.dropFirst().sink { items in
            if items.first(where: { $0.id == "TODAY-1-\(todayKey)" })?.status == .taken {
                approveExp.fulfill()
            }
        }
        wait(for: [approveExp], timeout: 2.0)
        c3.cancel()

        // Verify tomorrow is still pending (unaffected)
        let tomorrowItems = try planRepo.itemsForDay(tomorrow)
        XCTAssertEqual(tomorrowItems.count, 1)
        XCTAssertEqual(tomorrowItems.first?.status, .pending)
        XCTAssertEqual(tomorrowItems.first?.id, "TOMORROW-1-\(tomorrowKey)")

        // Verify today's is approved
        let todayItems = try planRepo.itemsForDay(Date())
        let todayPlan = todayItems.first { $0.id == "TODAY-1-\(todayKey)" }
        XCTAssertEqual(todayPlan?.status, .taken)
    }

    // Empty database - operations should handle gracefully
    func testEmptyDatabase_NoCrash() throws {
        // Query logs for a date with no data - should return empty, not crash
        let futureDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!

        let doses = try doseRepo.dosesForDate(futureDate)
        XCTAssertEqual(doses.count, 0)

        let supplements = try supplementRepo.logsForDate(futureDate)
        XCTAssertEqual(supplements.count, 0)

        let planItems = try planRepo.itemsForDay(futureDate)
        XCTAssertEqual(planItems.count, 0)
    }
}
