import XCTest
@testable import Koffee

/// L5 (Phase 0d). The chart row's "Peak" stat read `doses.first?.time + 45min` — the *earliest*
/// dose's peak — so a later, larger dose left the label behind. The L3 render is the evidence: the
/// drawn curve's high point is at 15:00 (a 200mg dose) and the row printed "Peak 07:45" beside it.
///
/// The other two stats on that row, `Current Caffeine` and `At Bedtime`, are read off the curve
/// (`chartData`); the peak is the only one that was read off the input doses with a hand-rolled
/// offset. It is read off the curve now, which is why these assertions are about the curve's high
/// point rather than about a dose.
@MainActor
final class ChartPeakLabelTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: hour, minute: minute))!
    }

    private func chart(_ doses: [Dose]) -> CaffeineTimelineChart {
        CaffeineTimelineChart(
            doses: doses,
            wakeTime: at(7),
            sleepTime: at(23),
            safeLimit: 400,
            metabolism: .medium
        )
    }

    /// The label names the curve's high point, whatever the doses were. 95mg at 07:00 leaves the
    /// level at 31mg by 15:00, so the 200mg dose reaches 231mg — the day peaks in the afternoon.
    func test_peak_names_the_curves_high_point_not_the_first_dose() {
        let morning = Dose(time: at(7), amount: 95)
        let afternoon = Dose(time: at(15), amount: 200)

        let peak = chart([morning, afternoon]).peakInstant

        XCTAssertEqual(peak, at(15), "the peak named the first dose rather than the curve's high point")
    }

    /// A single dose: the high point is at the dose, not a fixed offset past it.
    func test_a_single_dose_peaks_where_the_curve_is_highest() {
        let peak = chart([Dose(time: at(9), amount: 95)]).peakInstant

        XCTAssertEqual(peak, at(9), "the peak was offset from the dose instead of read off the curve")
    }

    /// No doses, no peak. The old expression fell through to `Date()`, inventing a peak for a chart
    /// with nothing on it.
    func test_no_doses_means_no_peak() {
        XCTAssertNil(chart([]).peakInstant)
    }
}
