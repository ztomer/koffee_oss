import XCTest
@testable import Koffee

/// L3 (Phase 0d). `generateUnifiedCurvePoints` filtered its doses with `mg <= 150` — a magnitude
/// ceiling that arrived with the coffee-only strip (`bd2134d`) as a stand-in for "this is a caffeine
/// dose, not something else in the stack". The app is caffeine-only now, so nothing needs the
/// stand-in and the ceiling only drops real doses.
///
/// The difference is user-visible: the curve, and the three stats the chart reads off it
/// (`Current Caffeine`, `At Bedtime`, `Peak`), then disagree with the bedtime banner about the same
/// day — because the banner projects through `projectBedtimeCaffeine`, which does not filter. Both
/// call `calculateCaffeineLevel`, so the only thing between them is the filter.
final class CurveDoseMagnitudeTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: hour, minute: minute))!
    }

    /// A 200 mg caffeine pill is a dose this app is for, and it has to be in the curve at the size it
    /// was taken. Under the ceiling the nearest sample reads 0.
    func test_a_dose_over_the_old_ceiling_reaches_the_curve() {
        let doseTime = at(15)

        let points = generateUnifiedCurvePoints(
            doses: [(doseTime, 200)],
            from: at(7),
            to: at(23),
            metabolism: .medium
        )

        let atDose = points.first { $0.time >= doseTime }
        XCTAssertNotNil(atDose, "the curve should have a sample at the dose")
        XCTAssertEqual(
            atDose?.compoundLevels["Caffeine"] ?? 0, 200, accuracy: 1.0,
            "a 200mg dose was dropped from the curve"
        )
    }

    /// The screen-level consequence: the number the curve reports at bedtime and the number the
    /// bedtime funnel reports must be the same number, whatever the dose was.
    func test_the_curve_and_the_bedtime_funnel_agree_on_a_dose_over_the_ceiling() {
        let doseTime = at(15)
        let doses: [(Date, Double)] = [(doseTime, 200)]

        let points = generateUnifiedCurvePoints(
            doses: doses,
            from: at(7),
            to: at(23),
            metabolism: .medium
        )
        let bedtimeOnCurve = points.last { $0.time <= at(23) }?.compoundLevels["Caffeine"] ?? 0
        let bedtimeProjected = projectBedtimeCaffeine(
            doses: doses,
            wakeTime: at(7),
            sleepTime: at(23),
            metabolism: .medium
        )

        XCTAssertGreaterThan(bedtimeProjected, 50, "200mg at 15:00 is still over 50mg at 23:00")
        XCTAssertEqual(
            bedtimeOnCurve, bedtimeProjected, accuracy: 1.0,
            "the chart and the bedtime projection disagree on the same dose"
        )
    }
}
