import XCTest
@testable import Koffee

// K1 (roadmap Phase 0b): the daily ceiling must never exceed 400 mg.
//
// `dailyCaffeineLimit` was `Sensitivity.multiplier * 400`, and `.low` has
// multiplier 1.2 -- so a user who described themselves as low-sensitivity was
// shown 480 mg/day as SAFE. 400 mg is the EFSA adult ceiling and is not raised
// by self-report: the sensitivity setting describes metabolism (how fast the
// body clears caffeine), which is a real reason to move the BEDTIME threshold,
// and not a reason to raise a population safety limit.
//
// A multiplier does not lower it either. The first draft of this test argued
// that a fast metabolizer is a reason to be more conservative, and left the
// door open at 320 mg; the implementation settled it the other way, because
// "how fast do I clear caffeine" is not a safety margin and guessing at one
// invents a number no source supports. So every sensitivity pins to exactly
// 400 -- and that is asserted, not merely bounded, so a future edit that
// reintroduces a multiplier fails here rather than looking conservative.
@MainActor
final class DailyCaffeineLimitTests: XCTestCase {

    /// The population ceiling, named once so a future edit has to argue with it.
    private let efsaAdultCeilingMg = 400.0

    private func limit(for sensitivity: String) -> Double {
        AppState.dailyCaffeineLimit(sensitivityRawValue: sensitivity)
    }

    func test_low_sensitivity_does_not_raise_the_ceiling() {
        // The defect, exactly: 1.2 x 400.
        XCTAssertEqual(
            limit(for: "low"), efsaAdultCeilingMg,
            "a low-sensitivity user must not be shown more than the 400 mg "
                + "population ceiling; self-report does not raise a safety limit"
        )
    }

    func test_no_sensitivity_ever_exceeds_the_ceiling() {
        for raw in ["low", "medium", "high", "unknown-value", ""] {
            XCTAssertLessThanOrEqual(
                limit(for: raw), efsaAdultCeilingMg,
                "sensitivity \(raw.isEmpty ? "<empty>" : raw) raised the ceiling"
            )
        }
    }

    func test_every_declared_sensitivity_is_pinned() {
        // Exact equality, not a bound: every sensitivity pins to the ceiling,
        // so a case added to Sensitivity later cannot quietly pick up a
        // multiplier and pass a `<=` check.
        XCTAssertEqual(limit(for: "low"), 400, accuracy: 0.001)
        XCTAssertEqual(limit(for: "medium"), 400, accuracy: 0.001)
        XCTAssertEqual(limit(for: "high"), 400, accuracy: 0.001)
    }

    func test_an_unrecognised_value_is_treated_as_the_ceiling_not_a_discount() {
        // The old code's `?? 1.0` defaulted an unknown string to the ceiling,
        // which is right; this pins that it stays right rather than becoming
        // "no profile, guess low".
        XCTAssertEqual(limit(for: "nonsense"), 400, accuracy: 0.001)
    }
}
