import XCTest
import Combine
@testable import Koffee

/// The clock seam (G4's limit made good).
///
/// Every fixture the harness could build placed its doses *ahead* of the draw, because the picture
/// moved with the wall clock: `Current Caffeine` picked whichever 30-minute sample the second hand
/// happened to be on, "Peak" flipped between "Peak" and "Peak At" as the instant passed, and the tank
/// read empty because the day's dose was still in the future. A screenshot you cannot compare with
/// yesterday's is not a screenshot, so the app reads "now" through `DateHelper` and a render freezes it.
///
/// These are the two halves of that claim, the same pair the harness uses for the bubble seed: a pinned
/// instant decides the value, and two different instants give two different values — without the
/// second half, the first would pass just as well if the seam were ignored and the wall clock read.
@MainActor
final class ClockSeamTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: hour, minute: minute))!
    }

    override func tearDown() {
        DateHelper.pinnedNow = nil
        super.tearDown()
    }

    /// The chart's "Current Caffeine" is read at the pinned instant, not at the wall clock. 200mg at
    /// 09:00 is 152mg at 11:00 and 44mg at 20:00.
    func test_the_charts_current_level_is_read_at_the_pinned_instant() {
        let chart = CaffeineTimelineChart(
            doses: [Dose(time: at(9), amount: 200)],
            wakeTime: at(7),
            sleepTime: at(23),
            safeLimit: 400,
            metabolism: .medium
        )

        DateHelper.pinnedNow = at(11)
        let morning = chart.currentCaffeine

        DateHelper.pinnedNow = at(20)
        let evening = chart.currentCaffeine

        XCTAssertEqual(morning, 200 * pow(0.5, 2.0 / 5.0), accuracy: 1.0)
        XCTAssertEqual(evening, 200 * pow(0.5, 11.0 / 5.0), accuracy: 1.0)
        XCTAssertGreaterThan(
            morning, evening,
            "moving the pinned instant left the chart unchanged: it read the wall clock"
        )
    }

    /// The seam is one door, not a per-view habit: with it pinned the tank's level is the level at that
    /// instant. The fixture logs 200mg eight hours after its 07:00 wake, so at 16:00 the dose is in the
    /// tank and at 12:00 it is still ahead of the clock — the tank reads empty there by arithmetic, not
    /// by accident, which is the other half of the claim.
    func test_the_tank_holds_the_fixtures_dose_when_the_instant_is_behind_it() throws {
        DateHelper.pinnedNow = at(16)
        let evening = try RenderHarness.Fixture.overBedtimeLimit()
        settle(evening)

        DateHelper.pinnedNow = at(12)
        let noon = try RenderHarness.Fixture.overBedtimeLimit()
        settle(noon)

        XCTAssertGreaterThan(
            evening.state.currentCaffeineLevel, 150,
            "the tank was empty at 16:00, an hour after the fixture's 200mg dose"
        )
        XCTAssertEqual(
            noon.state.currentCaffeineLevel, 0, accuracy: 0.001,
            "the tank held caffeine at noon, three hours before the fixture's dose"
        )
    }

    /// Waits for the fixture's rows to reach `AppState` — the delivery that also recomputes the tank,
    /// which a render gets from the harness's `settle`.
    private func settle(_ fixture: RenderHarness.Fixture) {
        let landed = expectation(description: "the fixture's rows reach AppState")
        landed.assertForOverFulfill = false
        let token = fixture.state.$doses.dropFirst().sink { _ in landed.fulfill() }
        wait(for: [landed], timeout: 2.0)
        token.cancel()
    }
}
