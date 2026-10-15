import XCTest
@testable import Koffee
import GRDB
import Combine

// K2 (roadmap Phase 0b): no surface may state a post-wake delay as guidance, or
// justify one with cortisol.
//
// "First coffee 90 minutes after waking, for optimal cortisol alignment" was on
// three user-visible surfaces, plus a `recommendedTimingMinutes = 90` in the
// data model with no consumer but a test pinning it, plus a `firstDoseDelay
// Seconds = 5400` that actually placed the plan item. No RCT establishes a
// post-wake delay, and the rationale is not merely unsupported but BACKWARDS —
// the cortisol argument has the sign of the effect the wrong way round (Antonio
// et al. 2024; Klaas et al. 2025; koffee_big grades the claim tier `none`, i.e.
// to be removed rather than softened).
//
// This scans the STRINGS the app renders rather than a list of call sites. A
// grep for "cortisol" over the source would pass the moment this copy moved
// into a Settings pane, a new compound row or a per-user override — which is
// how it would come back, because nothing about a string carries its own
// provenance. `NotificationCopy` exists so the notification bodies are
// reachable from a test at all; they were inline literals.
@MainActor
final class NoPostWakeDelayClaimTests: XCTestCase {

    /// Phrases that assert a delay or a mechanism with no trial behind them.
    private static let banned = [
        "cortisol",
        "90 min",
        "90 minutes",
        "first coffee in",
        "after waking to",
        "firstdosedelay",
        "recommendedtimingminutes"
    ]

    /// Every user-visible string reachable from this app's own code.
    private func renderedCopy() -> [(surface: String, text: String)] {
        var out: [(String, String)] = [
            ("NotificationCopy.morningBody", NotificationCopy.morningBody),
            ("NotificationCopy.morningTitle", NotificationCopy.morningTitle),
            ("NootropicCompound.explanation", NootropicCompound.caffeine.explanation),
            ("NootropicCompound.mechanismOfAction", NootropicCompound.caffeine.mechanismOfAction),
            ("NootropicCompound.intendedPurpose", NootropicCompound.caffeine.intendedPurpose),
            ("NootropicCompound.synergyBenefit", NootropicCompound.caffeine.synergyBenefit ?? "")
        ]
        // Any future compound row is covered by existing, not by remembering
        // to add it: CaseIterable means a new case cannot skip this scan.
        for compound in NootropicCompound.allCases where compound != .caffeine {
            out.append(("\(compound.rawValue).explanation", compound.explanation))
            out.append(("\(compound.rawValue).mechanismOfAction", compound.mechanismOfAction))
        }
        return out
    }

    func test_no_surface_states_the_delay_or_cites_cortisol() {
        var offenders: [String] = []
        for (surface, text) in renderedCopy() {
            let lower = text.lowercased()
            for phrase in Self.banned where lower.contains(phrase.lowercased()) {
                offenders.append("\(surface) contains \"\(phrase)\": \(text)")
            }
        }
        XCTAssertEqual(
            offenders, [],
            "a post-wake delay is stated as guidance with no trial behind it (K2):\n"
                + offenders.joined(separator: "\n")
        )
    }

    func test_the_plan_item_sits_at_wake_not_at_wake_plus_ninety() throws {
        // The behavioural half of K2. The copy is the part a user reads; this is
        // the part the app ACTS on — `firstDoseDelaySeconds` used to push the
        // generated plan item 90 minutes past wake, so the advice was not only
        // unsound, it was scheduled.
        let db = try DatabaseQueue()
        try DatabaseManager.makeMigrator().migrate(db)
        let state = AppState(
            profileRepo: UserProfileRepository(db: db),
            doseRepo: DoseRepository(db: db),
            beverageRepo: BeverageRepository(db: db),
            planRepo: DailyPlanRepository(db: db)
        )

        var profile = try state.getOrCreateProfile()
        profile.stackCompounds = ["Caffeine"]
        try state.saveProfile(profile)

        // `saveProfile` writes through the repo; `AppState.profile` is `private(set)`
        // and only moves when the repository's publisher fires. Without this wait the
        // plan is generated from a nil profile and the test asserts on zero items —
        // which is red for the wrong reason and would have passed the defect through.
        let loaded = expectation(description: "profile reached AppState")
        loaded.assertForOverFulfill = false
        let sub = state.$profile.dropFirst().sink { p in
            if p?.stackCompounds.contains("Caffeine") == true { loaded.fulfill() }
        }
        wait(for: [loaded], timeout: 2.0)
        sub.cancel()

        try state.refreshDailyPlan()

        // Second hop, and the one that made this test red for the wrong reason:
        // `dailyPlanItems` is fed by `planRepo.$items` through `receive(on: main)`,
        // so it lags the write by one main-queue hop. Reading it right after
        // `refreshDailyPlan()` returns asserts on zero items and calls it a defect.
        let planned = expectation(description: "caffeine item reached AppState")
        planned.assertForOverFulfill = false
        let planSub = state.$dailyPlanItems
            .dropFirst()
            .filter { $0.contains { $0.compoundUuid == "caffeine" } }
            .prefix(1)
            .sink { _ in planned.fulfill() }
        wait(for: [planned], timeout: 2.0)
        planSub.cancel()

        let items = state.dailyPlanItems.filter { $0.compoundUuid == "caffeine" }
        XCTAssertEqual(
            items.count, 1,
            "expected exactly one caffeine plan item; got \(items.count)"
        )
        guard let item = items.first else { return }

        let offset = item.scheduledTime.timeIntervalSince(state.effectiveWakeTime)
        XCTAssertEqual(
            offset, 0, accuracy: 1.0,
            "the caffeine plan item sits \(Int(offset / 60)) min after wake; "
                + "K2 puts it at wake"
        )
    }
}
