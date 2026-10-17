import XCTest
import Combine
@testable import Koffee

/// The ruled dose set (L4, owner ruling 2026-10-17).
///
/// Three surfaces read "same caffeine" from two different dose sets: the chart's stat
/// row read the curve built from logged doses *plus pending plan items*, while the
/// bedtime funnel (`projectBedtimeCaffeine`) and the tank read logged doses alone —
/// on one dashboard render the stat row said 76mg beside the banner's 65mg, and the
/// tank read 0 beside a "Current Caffeine" of 47mg. The owner ruled the dose set:
/// **planned + logged, deduplicating the case where the planned dose was already
/// logged** (a taken plan-dose is logged with the plan item's own id, so the link is
/// structural — dose id == plan item id — not a guess from times and amounts).
///
/// One derivation, every surface. A future-timestamped planned dose is safe to hand
/// the pure decay core: `calculateCaffeineLevel` skips doses ahead of the instant it
/// is asked about, so a pending item contributes nothing until its time arrives.
@MainActor
final class EffectiveDoseSetTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: hour, minute: minute))!
    }

    override func tearDown() {
        DateHelper.pinnedNow = nil
        super.tearDown()
    }

    // MARK: - the pure derivation

    /// Planned and logged combine: a pending plan item nobody logged yet is a dose
    /// the day expects to contain.
    func test_planned_and_logged_combine() {
        let logged = [DoseModel(timestamp: at(9), caffeineMg: 65, beverageName: "Coffee")]
        let pending = [DailyPlanItemModel(id: "P-late", compoundUuid: "caffeine", dayKey: "2026-10-17",
                                          compoundName: "caffeine", doseMg: 95, scheduledTime: at(14))]

        let set = effectiveDoseSet(loggedDoses: logged, pendingPlanItems: pending)

        XCTAssertEqual(set.count, 2, "the ruled set is the logged dose and the pending plan item")
        XCTAssertEqual(set.filter { $0.isPlanItem }.count, 1, "the plan item is drawn as planned")
        XCTAssertTrue(set.contains { $0.amount == 95 && $0.isPlanItem })
        XCTAssertTrue(set.contains { $0.amount == 65 && !$0.isPlanItem })
    }

    /// The dedup is structural: a taken plan-dose is logged with the plan item's id, so
    /// a pending item whose id is already logged is counted ONCE — by its logged dose,
    /// with the logged timestamp (the actual cup is a fact; the schedule an estimate).
    func test_a_planned_dose_already_logged_is_counted_once() {
        let logged = [DoseModel(id: "P-morning", timestamp: at(9, 30), caffeineMg: 95, beverageName: "Coffee")]
        let pending = [DailyPlanItemModel(id: "P-morning", compoundUuid: "caffeine", dayKey: "2026-10-17",
                                          compoundName: "caffeine", doseMg: 95, scheduledTime: at(7))]

        let set = effectiveDoseSet(loggedDoses: logged, pendingPlanItems: pending)

        XCTAssertEqual(set.count, 1, "the planned cup that was drunk is not also a second cup")
        XCTAssertEqual(set.first?.time, at(9, 30), "the logged dose's timestamp wins")
        XCTAssertEqual(set.first?.amount, 95)
    }

    /// Two plan items, one of them logged: the set carries the other.
    func test_dedup_leaves_the_other_planned_dose_standing() {
        let logged = [DoseModel(id: "P1", timestamp: at(7, 5), caffeineMg: 95, beverageName: "Coffee")]
        let pending = [
            DailyPlanItemModel(id: "P1", compoundUuid: "caffeine", dayKey: "2026-10-17",
                               compoundName: "caffeine", doseMg: 95, scheduledTime: at(7)),
            DailyPlanItemModel(id: "P2", compoundUuid: "caffeine", dayKey: "2026-10-17",
                               compoundName: "caffeine", doseMg: 40, scheduledTime: at(14))
        ]

        let set = effectiveDoseSet(loggedDoses: logged, pendingPlanItems: pending)

        XCTAssertEqual(set.count, 2)
        XCTAssertFalse(set.contains { $0.time == at(7) && $0.isPlanItem },
                       "the morning plan item was logged; the schedule must not duplicate it")
        XCTAssertTrue(set.contains { $0.amount == 40 && $0.isPlanItem })
    }

    // MARK: - the bedtime funnel takes the ruled set

    /// A planned dose scheduled ahead of bedtime raises the funnel's number, because
    /// the funnel now receives the ruled set — the banner's "At Bedtime" is advice
    /// about the rest of the day, and the app draws the pending item as a dose it
    /// expects to be taken.
    func test_a_pending_item_ahead_of_bedtime_raises_the_funnels_number() {
        let logged = [DoseModel(timestamp: at(9), caffeineMg: 65, beverageName: "Coffee")]
        let pending = [DailyPlanItemModel(id: "P2", compoundUuid: "caffeine", dayKey: "2026-10-17",
                                          compoundName: "caffeine", doseMg: 95, scheduledTime: at(14))]

        let loggedOnly = logged.compactMap { dose in
            dose.caffeineMg > 0 ? (dose.timestamp, dose.caffeineMg) : nil
        }
        let ruled = effectiveDoseSet(loggedDoses: logged, pendingPlanItems: pending)
            .compactMap { dose in dose.time.map { (time: $0, amount: dose.amount) } }

        let withoutPlanned = projectBedtimeCaffeine(doses: loggedOnly, wakeTime: at(7), sleepTime: at(23))
        let withPlanned = projectBedtimeCaffeine(doses: ruled, wakeTime: at(7), sleepTime: at(23))

        XCTAssertEqual(withPlanned, withoutPlanned + 95 * pow(0.5, (23 - 14) / 5.0), accuracy: 0.01,
                       "the pending item's decayed remainder must reach the bedtime number")
        XCTAssertGreaterThan(withPlanned, withoutPlanned)
    }

    // MARK: - the tank holds the ruled set

    func test_the_tank_counts_a_pending_planned_dose_from_its_scheduled_time() throws {
        DateHelper.pinnedNow = at(12)
        let appState = try TestDatabase().appState
        try appState.profileRepo.save(UserProfileModel(wakeTime: at(7), sleepTime: at(23),
                                                       stackCompounds: ["caffeine"]))

        try appState.planRepo.save(DailyPlanItemModel(
            id: "P-wake", compoundUuid: "caffeine", dayKey: "2026-10-17",
            compoundName: "caffeine", doseMg: 95, scheduledTime: at(7)))

        appState.updateCaffeineLevels()

        XCTAssertEqual(appState.currentCaffeineLevel, 95 * pow(0.5, 5.0 / 5.0), accuracy: 0.01,
                       "at noon the tank held nothing beside a wake-hour planned cup: it read logged doses only")
    }

    /// The exact double-count the ruling dedupes: the cup was taken (dose logged with
    /// the plan item's id) while the plan row still sits pending — the tank may not
    /// read 190mg from one cup.
    func test_the_tank_counts_a_dose_its_pending_plan_row_already_carries_once() throws {
        DateHelper.pinnedNow = at(12)
        let appState = try TestDatabase().appState
        try appState.profileRepo.save(UserProfileModel(wakeTime: at(7), sleepTime: at(23),
                                                       stackCompounds: ["caffeine"]))

        try appState.doseRepo.addWithId(id: "P-wake", beverageId: nil,
                                        timestamp: at(7, 10), caffeineMg: 95,
                                        beverageName: "Coffee")
        try appState.planRepo.save(DailyPlanItemModel(
            id: "P-wake", compoundUuid: "caffeine", dayKey: "2026-10-17",
            compoundName: "caffeine", doseMg: 95, scheduledTime: at(7)))

        appState.updateCaffeineLevels()

        XCTAssertEqual(appState.currentCaffeineLevel, 95 * pow(0.5, (12 - 7.1667) / 5.0), accuracy: 0.5,
                       "the tank double-counted the cup the pending plan row still carries")
    }

    // MARK: - one bedtime number everywhere

    /// The chart's stat row must announce the FUNNEL's bedtime number, not a local read of
    /// the curve: the funnel is the one bedtime projection (its own comment's law), and its
    /// day-boundary rule (at-or-before wake belongs to the coming day) makes it differ from
    /// the curve exactly for a plan item at wake — the shape L4 was found on.
    func test_the_chart_row_announces_the_funnel_number() {
        let doses = [Dose(time: at(9), amount: 200),
                     Dose(time: at(7), amount: 95, isPlanItem: true)]

        DateHelper.pinnedNow = at(12)
        let chart = CaffeineTimelineChart(
            doses: doses, wakeTime: at(7), sleepTime: at(23),
            safeLimit: 400, metabolism: .medium
        )

        let funnelNumber = projectBedtimeCaffeine(
            doses: doses.map { ($0.time!, $0.amount) },
            wakeTime: at(7), sleepTime: at(23)
        )

        XCTAssertEqual(chart.bedtimeCaffeineLevel, funnelNumber, accuracy: 0.001,
                       "the stat row read the curve, the funnel applies its day-boundary rule — two bedtime numbers again")
        XCTAssertGreaterThan(
            chart.bedtimeCaffeineLevel, 0,
            "a plan item at wake sits on the chart's curve start exactly; the row may not silently read zero"
        )
    }
}
