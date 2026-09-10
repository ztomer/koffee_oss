import XCTest
@testable import Koffee
import Foundation

final class NotificationsPreviewTests: XCTestCase {
    func testNextPendingWins() {
        let date = Calendar.current.date(bySettingHour: 13, minute: 30, second: 0, of: Date())!
        let item = DailyPlanItemModel(
            compoundName: "Caffeine",
            scheduledTime: date,
            status: .pending,
            dayKey: "2026-09-09",
            compoundUuid: "caffeine",
            doseMg: 95
        )
        let line = nextNudgeLine(pending: [item], sleepTime: nil, sensitivity: .medium, metabolism: .medium)
        XCTAssertTrue(line.contains("13:30"))
        XCTAssertTrue(line.contains("95mg"))
    }

    func testCutoffWhenNoPending() {
        let sleep = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        let line = nextNudgeLine(pending: [], sleepTime: sleep, sensitivity: .medium, metabolism: .medium)
        // medium 9h before 23:00 -> 14:00
        XCTAssertTrue(line.contains("14:00"))
        XCTAssertTrue(line.lowercased().contains("cutoff"))
    }

    func testWarmEmptyWhenNoProfile() {
        let line = nextNudgeLine(pending: [], sleepTime: nil, sensitivity: .medium, metabolism: .medium)
        XCTAssertFalse(line.isEmpty)
        XCTAssertFalse(line.lowercased().contains("no upcoming"))
    }
}
