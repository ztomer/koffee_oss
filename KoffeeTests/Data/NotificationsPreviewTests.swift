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
        let line = nextNudgeLine(pending: [item], sleepTime: nil, sensitivity: .medium, metabolism: .medium, referenceDoseMg: CaffeineConstants.defaultDoseMg)
        XCTAssertTrue(line.contains("13:30"))
        XCTAssertTrue(line.contains("95mg"))
    }

    func testCutoffWhenNoPending() {
        let sleep = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        let line = nextNudgeLine(pending: [], sleepTime: sleep, sensitivity: .medium, metabolism: .medium, referenceDoseMg: 95)
        // K3. This used to pin 14:00 — the medium row of a fixed 6/9/12 h table
        // (9 h before 23:00). That table was dose-blind, so 14:00 was drawn whether
        // the reader had a 50 mg tea or a 400 mg cold brew, and for the 200 mg case
        // it put the reader above their own 50 mg threshold at bedtime.
        //
        // For a 95 mg dose the derived gap is 5·log₂(95/50) = 4.630 h = 277.8 min,
        // which beats the Gardiner floor's 3.62 h at that dose, so the cutoff is
        // 23:00 − 277 min = 18:23. The minutes are truncated, which moves the
        // cutoff half a minute EARLIER than exact — the conservative direction.
        // Pinning the derivation rather than whatever the code returns: if the
        // model changes for a reason nobody wrote down, this must fail.
        XCTAssertTrue(line.contains("18:23"), "got: \(line)")
        XCTAssertTrue(line.lowercased().contains("cutoff"))
    }

    /// The cutoff must move with the dose — the property the old table lacked.
    func testCutoffMovesWithTheDose() {
        let sleep = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        let small = nextNudgeLine(pending: [], sleepTime: sleep, sensitivity: .medium, metabolism: .medium, referenceDoseMg: 95)
        let large = nextNudgeLine(pending: [], sleepTime: sleep, sensitivity: .medium, metabolism: .medium, referenceDoseMg: 400)
        XCTAssertNotEqual(small, large, "a 400 mg dose must draw an earlier cutoff than 95 mg")
    }

    func testWarmEmptyWhenNoProfile() {
        let line = nextNudgeLine(pending: [], sleepTime: nil, sensitivity: .medium, metabolism: .medium, referenceDoseMg: CaffeineConstants.defaultDoseMg)
        XCTAssertFalse(line.isEmpty)
        XCTAssertFalse(line.lowercased().contains("no upcoming"))
    }
}
