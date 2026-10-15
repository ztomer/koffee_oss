import XCTest
@testable import Koffee
import Foundation

// K3 (roadmap Phase 0b): the cutoff is derived from the dose, not from a table.
//
// The retired table was low 6 h / medium 9 h / high 12 h, multiplied by a
// metabolism rate. It was unsourced and, fatally, dose-blind. The wall it drew
// was the same for a 50 mg tea and a 400 mg cold brew, so for the sizes that
// actually disturb sleep it certified compliance the reader's own threshold
// contradicted.
//
// These tests pin the invariant, not the numbers. A test that restates the
// formula agrees with it by construction and reads as coverage while asserting
// nothing about whether the formula is right -- which is how the inverted
// metabolism multipliers survived for a month in koffee_big. So the load-bearing
// assertion is the invariant below, and the arithmetic tests only stop a future
// edit from silently changing the model.

final class CaffeineCutoffTests: XCTestCase {

    // MARK: - The invariant

    /// The one property that matters: after waiting the gap the app draws, a dose
    /// of this size at this reader's threshold is not above that reader's own line.
    ///
    /// Checked across every sensitivity and every dose, for exactly the reason the
    /// old table failed: it held for the doses that happened to be small.
    func test_the_cutoff_never_leaves_the_dose_above_the_readers_own_threshold() {
        for sensitivity in Sensitivity.allCases {
            for doseMg in [50.0, 95.0, 200.0, 400.0] {
                let gap = Sensitivity.medium.hoursBeforeBedForLastDose(doseMg: doseMg, halfLifeHours: 5.0)
                let gapForReader = sensitivity.hoursBeforeBedForLastDose(doseMg: doseMg, halfLifeHours: 5.0)
                let atBed = doseMg * pow(0.5, gap / 5.0)
                let atBedForReader = doseMg * pow(0.5, gapForReader / 5.0)
                XCTAssertLessThanOrEqual(
                    atBed, Sensitivity.medium.safeCaffeineAtBedtime + 0.001,
                    "medium reader: a \(doseMg) mg dose waited \(gap) h is still \(atBed) mg at bed"
                )
                XCTAssertLessThanOrEqual(
                    atBedForReader, sensitivity.safeCaffeineAtBedtime + 0.001,
                    "\(sensitivity.rawValue) reader: a \(doseMg) mg dose waited \(gapForReader) h is still \(atBedForReader) mg at bed"
                )
            }
        }
    }

    /// The same invariant at the doses between the trial anchors, where the floor
    /// interpolates and a blade of arithmetic error becomes real hours.
    func test_the_invariant_holds_for_doses_between_the_anchors() {
        for sensitivity in Sensitivity.allCases {
            var dose = 60.0
            while dose <= 390.0 {
                let gap = sensitivity.hoursBeforeBedForLastDose(doseMg: dose, halfLifeHours: 5.0)
                let atBed = dose * pow(0.5, gap / 5.0)
                XCTAssertLessThanOrEqual(
                    atBed, sensitivity.safeCaffeineAtBedtime + 0.001,
                    "\(sensitivity.rawValue) reader at \(dose) mg: \(atBed) mg at bed after a \(gap) h gap"
                )
                dose += 1.0
            }
        }
    }

    // MARK: - The defect, quantified

    /// What the fixed table actually did, stated as a number, so the reason K3
    /// exists cannot be lost. This test passes and is supposed to: it documents
    /// the retired behaviour, it does not test current code.
    func test_the_fixed_table_it_replaced_failed_that_invariant() {
        // A medium reader, 23:00 bedtime, a 200 mg dose taken at the 14:00 cutoff
        // the old table drew (9 h before bed).
        let oldTableHours = 9.0
        let doseMg = 200.0
        let halfLife = 5.0
        let atBed = doseMg * pow(0.5, oldTableHours / halfLife)
        // 200 · 0.5^(9/5) = 57.4 mg -- above the 50 mg this reader's own threshold
        // says, so the app could call the cutoff respected while its own model put
        // the reader over the line it drew.
        XCTAssertGreaterThan(atBed, Sensitivity.medium.safeCaffeineAtBedtime)
        XCTAssertEqual(atBed, 57.4, accuracy: 0.1)

        // The derived cutoff for the same dose is strictly longer.
        let corrected = Sensitivity.medium.hoursBeforeBedForLastDose(doseMg: doseMg, halfLifeHours: halfLife)
        XCTAssertGreaterThan(corrected, oldTableHours)
    }

    // MARK: - The Gardiner floor

    func testFloorReproducesTheTrialPoints() {
        XCTAssertEqual(CaffeinePK.floorHours(doseMg: 47), 0.0, accuracy: 0.0001)
        XCTAssertEqual(CaffeinePK.floorHours(doseMg: 100), 4.0, accuracy: 0.0001)
        XCTAssertEqual(CaffeinePK.floorHours(doseMg: 400), 12.0, accuracy: 0.0001)
    }

    func testFloorInterpolatesBetweenNodes() {
        let mid = CaffeinePK.floorHours(doseMg: 250)
        XCTAssertEqual(mid, 8.0, accuracy: 0.0001,
                       "250 mg is halfway between the 100 mg and 400 mg anchors")
        XCTAssertEqual(CaffeinePK.floorHours(doseMg: 20), 0.0, accuracy: 0.0001,
                       "under the 47 mg anchor there is no measured benefit to a gap")
    }

    func testFloorExtendsBeyondTheLastNodeRatherThanClamping() {
        // The last segment runs (100 mg, 4 h) → (400 mg, 12 h), a slope of 8/300 h
        // per mg. Extending it to 800 mg gives 12 + (8/300)·400 = 22.667 h.
        //
        // NOT 24 h: "twice the anchor dose" is not "twice the gap", because the
        // slope is linear in milligrams rather than in log-dose. Clamping at 12 h
        // would claim knowledge stops mattering past the last node, which the data
        // does not say and the derivation contradicts.
        XCTAssertEqual(CaffeinePK.floorHours(doseMg: 800), 22.6667, accuracy: 0.001)
        XCTAssertGreaterThan(CaffeinePK.floorHours(doseMg: 800), CaffeinePK.floorHours(doseMg: 400))
    }

    // MARK: - The derivation

    func testHoursToDecayIsTheExactInverseOfTheCaffeineCurve() {
        // Not restated -- measured against `calculateCaffeineLevel`, so the cutoff
        // and the bedtime projection cannot disagree.
        let dose = 200.0
        let threshold = 50.0
        let halfLife = 5.0
        let gap = CaffeinePK.hoursToDecay(
            doseMg: dose, toMilligrams: threshold, halfLifeHours: halfLife
        )
        let doses: [(Date, Double)] = [(Date(timeIntervalSinceNow: -gap * 3600), dose)]
        let atBed = calculateCaffeineLevel(doses: doses, at: Date(), halfLife: halfLife)
        XCTAssertEqual(atBed, threshold, accuracy: 0.001)
    }

    func testADoseAlreadyUnderTheThresholdNeedsNoGapAtAll() {
        XCTAssertEqual(CaffeinePK.hoursToDecay(
            doseMg: 40, toMilligrams: 100, halfLifeHours: 5.0
        ), 0.0)
        XCTAssertEqual(Sensitivity.low.hoursBeforeBedForLastDose(doseMg: 47, halfLifeHours: 5.0), 0.0,
                       "a tea-sized dose is under every reader's threshold and needs no gap at all")
    }

    // MARK: - The composition

    func testTheGapIsTheLongerOfTheDerivationAndTheFloor() {
        for sensitivity in Sensitivity.allCases {
            for doseMg in [47.0, 100.0, 200.0, 400.0] {
                let got = sensitivity.hoursBeforeBedForLastDose(doseMg: doseMg, halfLifeHours: 5.0)
                let derived = CaffeinePK.hoursToDecay(
                    doseMg: doseMg,
                    toMilligrams: sensitivity.safeCaffeineAtBedtime,
                    halfLifeHours: 5.0
                )
                XCTAssertEqual(got, max(derived, CaffeinePK.floorHours(doseMg: doseMg)),
                               accuracy: 0.0001,
                               "\(sensitivity.rawValue) at \(doseMg) mg")
            }
        }
    }

    func testTheFloorBindsOnlyWhereItShould() {
        // 47 mg: the derivation says no gap and neither does the floor.
        XCTAssertEqual(
            Sensitivity.low.hoursBeforeBedForLastDose(doseMg: 47, halfLifeHours: 5.0), 0.0,
            accuracy: 0.0001
        )
        // 400 mg for a low reader: derived 10 h, floor 12 h -- the EMPIRICS bind,
        // because the trial data is the better warrant for a big dose.
        let low400 = Sensitivity.low.hoursBeforeBedForLastDose(doseMg: 400, halfLifeHours: 5.0)
        let derived400 = CaffeinePK.hoursToDecay(
            doseMg: 400, toMilligrams: 100, halfLifeHours: 5.0
        )
        XCTAssertEqual(derived400, 10.0, accuracy: 0.0001)
        XCTAssertEqual(low400, 12.0, accuracy: 0.0001, "the floor must bind, not the derivation")
    }

    // MARK: - Direction and monotonicity

    func testSlowerMetabolismDemandsALongerGap() {
        // Half-life lengthens for a slow metabolizer, so the gap must lengthen too.
        // The old table got this right only by coincidence: it multiplied the
        // hours, which is the right sign applied to the wrong quantity.
        let slow = Sensitivity.medium.hoursBeforeBedForLastDose(
            doseMg: 200, halfLifeHours: 5.0 * MetabolismRate.slow.halfLifeMultiplier
        )
        let fast = Sensitivity.medium.hoursBeforeBedForLastDose(
            doseMg: 200, halfLifeHours: 5.0 * MetabolismRate.fast.halfLifeMultiplier
        )
        XCTAssertGreaterThan(slow, fast)
    }

    func testALargerDoseDemandsALongerGap() {
        // The property the retired table inverted by ignoring entirely.
        var previous = -1.0
        for doseMg in stride(from: 50.0, through: 400.0, by: 10.0) {
            let gap = Sensitivity.medium.hoursBeforeBedForLastDose(doseMg: doseMg, halfLifeHours: 5.0)
            XCTAssertGreaterThanOrEqual(gap, previous, "\(doseMg) mg must not demand a shorter gap")
            previous = gap
        }
        XCTAssertGreaterThan(
            Sensitivity.medium.hoursBeforeBedForLastDose(doseMg: 400, halfLifeHours: 5.0),
            Sensitivity.medium.hoursBeforeBedForLastDose(doseMg: 95, halfLifeHours: 5.0)
        )
    }
}
