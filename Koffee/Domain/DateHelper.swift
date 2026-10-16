import Foundation
import Synchronization

enum DateHelper {
    static var calendar: Calendar { Calendar.current }

    /// The one door to the wall clock.
    ///
    /// Everything that asks "when is now" — the tank's level, the chart's stats, "today's" doses, the
    /// plan's statuses, the day roll — reads `now` rather than calling `Date()`, so that a render can
    /// freeze the instant and take the same picture whenever it runs.
    ///
    /// That freeze is the whole point (G4's limit): every fixture in the render harness placed its
    /// doses ahead of the draw, because a picture that moves with the wall clock is not a picture you
    /// can screenshot for a change and compare later — the tank read empty, "Current Caffeine" picked
    /// whichever 30-minute sample the second hand happened to be on, and "Peak" flipped between "Peak"
    /// and "Peak At" as the instant passed. `nil` is the app: the real clock. Only a render sets it,
    /// for the duration of one draw, and restores what it found.
    ///
    /// `Mutex` rather than a bare `static var`: the seam is read from main-actor views and from GRDB's
    /// write queue, so a plain variable would be a data race, and `nonisolated(unsafe)` would be the
    /// same race with the compiler's permission.
    private static let overriddenNow = Mutex<Date?>(nil)

    static var pinnedNow: Date? {
        get { overriddenNow.withLock { $0 } }
        set { overriddenNow.withLock { $0 = newValue } }
    }

    static var now: Date { pinnedNow ?? Date() }

    static func startOfDay(for date: Date = DateHelper.now) -> Date {
        calendar.startOfDay(for: date)
    }

    static func endOfDay(for date: Date = DateHelper.now) -> Date {
        calendar.date(byAdding: .day, value: 1, to: startOfDay(for: date))!
    }

    static func date(byAddingMinute value: Int, to date: Date) -> Date? {
        calendar.date(byAdding: .minute, value: value, to: date)
    }

    static func date(byAddingHour value: Int, to date: Date) -> Date? {
        calendar.date(byAdding: .hour, value: value, to: date)
    }

    static func date(bySettingHour hour: Int, minute: Int, second: Int, of date: Date) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: second, of: date)
    }

    static func hour(of date: Date) -> Int {
        calendar.component(.hour, from: date)
    }

    static func dayKey(for date: Date = DateHelper.now) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func date(from dayKey: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayKey)
    }
}
