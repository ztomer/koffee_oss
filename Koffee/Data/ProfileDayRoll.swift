import Foundation
import GRDB

/// L1 (Phase 0c). The launch path stores a profile on every start. It used to store a *fresh* one —
/// `UserProfileModel.deleteAll`, then a new default — so every setting the user had chosen was
/// reset, on every launch and, because the test host is this app, on every push.
///
/// One part of that was load-bearing: the wake and sleep times are absolute datetimes and
/// `refreshDailyPlan` places the plan's first item AT `wakeTime`, so the stored dates have to be
/// today's. Only the dates needed moving. This rolls them, and leaves everything else alone.
enum ProfileDayRoll {

    /// What a brand-new install starts from.
    static let defaultWakeHour = 7
    static let defaultSleepHour = 23

    /// What the launch path should store, given what is already stored.
    ///
    /// - Parameters:
    ///   - existing: the stored profile, or `nil` on a first run.
    ///   - day: the day to roll onto — normally now.
    ///   - calendar: the calendar the wall-clock times are read in.
    /// - Returns: `existing` with its wake and sleep times carried onto `day`, so that only the
    ///   dates move; or a default profile when nothing is stored yet.
    static func profileToStore(
        existing: UserProfileModel?,
        day: Date,
        calendar: Calendar = .current
    ) -> UserProfileModel {
        guard var profile = existing else {
            let start = calendar.startOfDay(for: day)
            return UserProfileModel(
                wakeTime: calendar.date(byAdding: .hour, value: defaultWakeHour, to: start) ?? day,
                sleepTime: calendar.date(byAdding: .hour, value: defaultSleepHour, to: start) ?? day,
                stackCompounds: [NootropicCompound.caffeine.rawValue]
            )
        }

        profile.wakeTime = transposedWallTime(from: profile.wakeTime, onto: day, calendar: calendar)
        profile.sleepTime = transposedWallTime(from: profile.sleepTime, onto: day, calendar: calendar)
        return profile
    }

    /// The launch path's profile step: read what is stored, roll it onto `day`, write it back.
    ///
    /// Split out of `main.swift` so the step the app really performs — the read, the roll and the
    /// save, through a real database — is the thing a test drives, rather than a re-telling of it.
    /// `deleteAll` used to sit where the write now is.
    static func store(in db: Database, day: Date, calendar: Calendar = .current) throws {
        let existing = try UserProfileModel.fetchOne(db)
        try profileToStore(existing: existing, day: day, calendar: calendar).save(db)
    }
}

/// `wallTime`'s time of day, carried onto `date`'s date.
///
/// The profile stores wake and sleep as absolute datetimes, so every reader that wants "the same
/// wall-clock time, on this day" needs this projection: the launch path's day roll (L1) and
/// `HistoryView`, which reads a past day the same way.
func transposedWallTime(from wallTime: Date, onto date: Date, calendar: Calendar = .current) -> Date {
    let components = calendar.dateComponents([.hour, .minute, .second], from: wallTime)
    return calendar.date(
        bySettingHour: components.hour ?? 0,
        minute: components.minute ?? 0,
        second: components.second ?? 0,
        of: date
    ) ?? date
}
