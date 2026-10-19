import XCTest
@testable import Koffee

/// P1 (Phase 2). "Caffeine-free at": the instant the day's modelled caffeine falls under
/// the threshold the app reports as nothing.
///
/// The forecast has to agree with the curve by construction. A second caffeine number that
/// disagreed with the chart would be the defect L4 closed (one screen, two bedtime numbers),
/// so the assertions here are about the MODEL — the level at the instant the forecast names
/// — and not only about a date.
final class CaffeineFreeAtTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func at(_ hour: Int, _ minute: Int = 0, day: Int = 16) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    /// 95mg at 07:00 at a 5h half-life is 1mg after log2(95) = 6.57 half-lives — 32h 51m
    /// later, so the next morning.
    func test_free_at_is_the_instant_the_level_reaches_the_threshold() {
        let free = CaffeinePK.caffeineFreeAt(doses: [(at(7), 95.0)])

        let expected = at(7).addingTimeInterval(5 * log2(95) * 3600)
        XCTAssertNotNil(free)
        XCTAssertEqual(free!.timeIntervalSince(expected), 0, accuracy: 0.001)
    }

    /// The invariant, against the model the chart draws: at the instant the forecast names,
    /// the level is at the threshold, and a minute earlier it is above it. A forecast that
    /// drifted from `calculateCaffeineLevel` would fail here even if its own arithmetic
    /// were perfectly self-consistent.
    func test_the_level_crosses_the_threshold_at_the_instant_it_names() {
        let doses = [(at(7), 95.0)]
        let free = CaffeinePK.caffeineFreeAt(doses: doses)!

        XCTAssertEqual(calculateCaffeineLevel(doses: doses, at: free), 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(
            calculateCaffeineLevel(doses: doses, at: free.addingTimeInterval(-60)),
            1.0,
            "the level was already under the threshold a minute before the forecast named"
        )
    }

    /// A later dose moves the answer past itself: the free time is after the LAST dose,
    /// never before it.
    func test_the_free_time_is_after_the_last_dose() {
        let free = CaffeinePK.caffeineFreeAt(doses: [(at(7), 95.0), (at(15), 200.0)])!

        XCTAssertGreaterThan(free, at(15))
    }

    /// A slower metaboliser clears later: the half-life multiplier has to be in the
    /// derivation, not beside it.
    func test_a_slow_metaboliser_is_free_later_than_a_fast_one() {
        let doses = [(at(7), 95.0)]

        let slow = CaffeinePK.caffeineFreeAt(doses: doses, metabolism: .slow)!
        let fast = CaffeinePK.caffeineFreeAt(doses: doses, metabolism: .fast)!

        XCTAssertGreaterThan(slow, fast)
    }

    /// No doses: nothing to forecast. A date in the past would be an invented answer.
    func test_no_doses_means_no_forecast() {
        XCTAssertNil(CaffeinePK.caffeineFreeAt(doses: []))
    }

    /// The threshold is the app's own reporting resolution — the level at which the
    /// dashboard prints 0 mg — and it is declared once, so the copy and the derivation
    /// cannot disagree about what "free" means.
    func test_the_threshold_is_the_display_resolution() {
        XCTAssertEqual(CaffeineConstants.caffeineFreeThresholdMg, 1.0)
    }

    // MARK: - The line the dashboard draws

    func test_the_line_names_the_day_the_instant_falls_on() {
        XCTAssertEqual(
            caffeineFreeLine(freeAt: at(14, 35), now: at(9), calendar: calendar),
            "Caffeine-free at 14:35 today (under 1mg)."
        )
        XCTAssertEqual(
            caffeineFreeLine(freeAt: at(6, 9, day: 17), now: at(12), calendar: calendar),
            "Caffeine-free at 06:09 tomorrow (under 1mg)."
        )
    }

    /// A day further out is named, not guessed at: "tomorrow" would be a lie on the third day.
    func test_a_day_further_out_is_named() {
        let line = caffeineFreeLine(freeAt: at(6, 9, day: 19), now: at(12), calendar: calendar)

        XCTAssertEqual(line, "Caffeine-free at 06:09 Mon 19 Oct (under 1mg).")
    }

    /// Already under the threshold: the honest answer is now, not a time in the past.
    func test_already_free_says_now() {
        XCTAssertEqual(
            caffeineFreeLine(freeAt: at(7), now: at(12), calendar: calendar),
            "Caffeine-free now (under 1mg)."
        )
    }

    /// Nothing to forecast, nothing to say.
    func test_no_forecast_means_no_line() {
        XCTAssertNil(caffeineFreeLine(freeAt: nil, now: at(12), calendar: calendar))
    }
}
