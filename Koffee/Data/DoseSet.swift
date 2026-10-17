import Foundation

/// The ruled dose set (L4, owner ruling 2026-10-17).
///
/// Three surfaces read "caffeine" from three different sets — the chart's stat row read a curve
/// built from logged doses *plus pending plan items*, the bedtime funnel read logged doses alone,
/// and the tank read logged doses alone — so one dashboard render carried two bedtime numbers
/// (76mg beside 65mg) and a tank of 0 beside a "Current Caffeine" of 47mg. The ruling settles the
/// set: **planned + logged**, deduplicating the case where the planned dose was already logged.
///
/// The dedup is structural, not a guess from times and amounts: when a plan item is taken, its
/// dose is logged with the plan item's own id (`AppState.updatePlanItemStatus` →
/// `addDoseWithId(id:)`, and `refreshDailyPlan` flips a baseStack item whose id is logged back to
/// `.taken`), so a logged dose and a pending plan item sharing an id are one cup, not two. The
/// logged dose wins — the cup that was actually drunk is a fact; the scheduled time was an
/// estimate. A freeform manual dose carries a fresh id, so it and the plan row it was inspired by
/// count separately; whether the plan row should notice its intention was fulfilled outside the
/// take button is a separate question, not this set's to answer by fuzzy matching.
///
/// Feeding this set to `projectBedtimeCaffeine` and `calculateCaffeineLevel` is safe: the decay
/// core skips doses whose time is ahead of the instant it is asked about, so a pending item
/// contributes nothing until its scheduled time arrives — the tank can hold the full ruled set
/// and still read empty before the day's first planned cup.
///
/// Pure, so it is testable without a database: `DoseModel` and `DailyPlanItemModel` are plain
/// records constructible in tests.
func effectiveDoseSet(loggedDoses: [DoseModel], pendingPlanItems: [DailyPlanItemModel]) -> [Dose] {
    var set: [Dose] = loggedDoses.map { dose in
        Dose(time: dose.timestamp, amount: dose.caffeineMg, compound: .caffeine, isPlanItem: false)
    }

    let loggedIds = Set(loggedDoses.map { $0.id })
    for item in pendingPlanItems where !loggedIds.contains(item.id) {
        set.append(Dose(time: item.scheduledTime, amount: item.doseMg, compound: .caffeine, isPlanItem: true))
    }

    return set.sorted { ($0.time ?? .distantPast) < ($1.time ?? .distantPast) }
}
