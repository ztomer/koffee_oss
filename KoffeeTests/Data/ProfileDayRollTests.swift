import XCTest
import GRDB
@testable import Koffee

/// L1 (Phase 0c). The launch path stores a profile at startup, and it used to store a FRESH one —
/// `UserProfileModel.deleteAll` then a new default — so wake time, sleep time, sensitivity,
/// metabolism, weight and stack compounds were reset on every launch, and on every test run, since
/// the test host is this app.
///
/// The dates genuinely have to be today's: `refreshDailyPlan` places the plan's first item AT
/// `wakeTime`. Only the dates needed moving, which is why the fix is a roll rather than a removal.
/// The tests are in two halves for that reason — the settings half, and the dates half.
final class ProfileDayRollTests: XCTestCase {

    /// A fixed calendar, so "the same wall-clock time" means the same thing on every machine.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int
    ) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )!
    }

    /// The launch path — the file whose `applicationDidFinishLaunching` runs on every start.
    private var mainSwiftURL: URL {
        URL(fileURLWithPath: #filePath)          // …/KoffeeTests/Data/ProfileDayRollTests.swift
            .deletingLastPathComponent()          // …/KoffeeTests/Data
            .deletingLastPathComponent()          // …/KoffeeTests
            .deletingLastPathComponent()          // …/koffee_oss
            .appendingPathComponent("Koffee/App/main.swift")
    }

    // MARK: - The settings half

    /// The regression itself. A scan rather than a behavioural test because the destructive line IS
    /// the behaviour and it lives in a top-level script no test can call: this fails on the line
    /// that did it, and keeps failing if anyone writes it again.
    func test_the_launch_path_never_deletes_the_users_profile() throws {
        let source = try String(contentsOf: mainSwiftURL, encoding: .utf8)

        XCTAssertFalse(
            source.contains("UserProfileModel.deleteAll"),
            """
            main.swift deletes the user's profile row at launch. That resets wake time, sleep time, \
            sensitivity, metabolism, weight and stack compounds on every start — and on every push, \
            because the test host is this app.
            """
        )
    }

    func test_every_setting_the_user_chose_survives_the_roll() {
        let existing = UserProfileModel(
            weight: 82.5,
            age: 41,
            heightCm: 168,
            biologicalSex: "female",
            sensitivity: "high",
            wakeTime: date(2026, 9, 30, 5, 30),
            sleepTime: date(2026, 9, 30, 22, 15),
            metabolismRate: "slow",
            toleranceDaysSinceReset: 3,
            toleranceResetDaysRequired: 21,
            optimizationGoal: "energy",
            stackCompounds: ["Caffeine"],
            updatedAt: date(2026, 9, 30, 5, 0),
            autoRefreshPlan: false,
            notificationsEnabled: false,
            toleranceAlertsEnabled: false
        )

        let rolled = ProfileDayRoll.profileToStore(
            existing: existing, day: date(2026, 10, 16, 9, 12), calendar: calendar
        )

        // One profile, not a replacement: the row keeps its identity.
        XCTAssertEqual(rolled.id, existing.id, "the profile was replaced rather than rolled")

        XCTAssertEqual(rolled.weight, 82.5)
        XCTAssertEqual(rolled.age, 41)
        XCTAssertEqual(rolled.heightCm, 168)
        XCTAssertEqual(rolled.biologicalSex, "female")
        XCTAssertEqual(rolled.sensitivity, "high", "the user's sensitivity was reset")
        XCTAssertEqual(rolled.metabolismRate, "slow", "the user's metabolism was reset")
        XCTAssertEqual(rolled.toleranceDaysSinceReset, 3)
        XCTAssertEqual(rolled.toleranceResetDaysRequired, 21)
        XCTAssertEqual(rolled.optimizationGoal, "energy")
        XCTAssertEqual(rolled.stackCompounds, ["Caffeine"], "the user's stack was reset")
        XCTAssertFalse(rolled.autoRefreshPlan)
        XCTAssertFalse(rolled.notificationsEnabled)
        XCTAssertFalse(rolled.toleranceAlertsEnabled)
        XCTAssertEqual(rolled.updatedAt, existing.updatedAt, "the roll is not a settings write")
    }

    // MARK: - The dates half

    func test_the_dates_move_onto_the_given_day_and_keep_their_wall_clock_times() {
        let existing = UserProfileModel(
            wakeTime: date(2026, 9, 30, 5, 30),
            sleepTime: date(2026, 9, 30, 22, 15)
        )

        let rolled = ProfileDayRoll.profileToStore(
            existing: existing, day: date(2026, 10, 16, 9, 12), calendar: calendar
        )

        XCTAssertEqual(rolled.wakeTime, date(2026, 10, 16, 5, 30))
        XCTAssertEqual(rolled.sleepTime, date(2026, 10, 16, 22, 15))
    }

    /// The plan places its first item AT `wakeTime` for *today*, so a roll that left the date alone
    /// would schedule today's coffee on the day the user last opened Settings.
    func test_the_rolled_wake_time_lands_on_today() {
        let existing = UserProfileModel(
            wakeTime: date(2026, 1, 2, 7, 0),
            sleepTime: date(2026, 1, 2, 23, 0)
        )
        let today = date(2026, 10, 16, 14, 5)

        let rolled = ProfileDayRoll.profileToStore(existing: existing, day: today, calendar: calendar)

        XCTAssertEqual(
            calendar.startOfDay(for: rolled.wakeTime),
            calendar.startOfDay(for: today)
        )
        XCTAssertEqual(
            calendar.startOfDay(for: rolled.sleepTime),
            calendar.startOfDay(for: today)
        )
    }

    func test_rolling_a_profile_that_is_already_today_changes_nothing() {
        let existing = UserProfileModel(
            wakeTime: date(2026, 10, 16, 5, 30),
            sleepTime: date(2026, 10, 16, 22, 15)
        )

        let rolled = ProfileDayRoll.profileToStore(
            existing: existing, day: date(2026, 10, 16, 9, 12), calendar: calendar
        )

        XCTAssertEqual(rolled.wakeTime, existing.wakeTime)
        XCTAssertEqual(rolled.sleepTime, existing.sleepTime)
        XCTAssertEqual(rolled, existing)
    }

    // MARK: - First run

    /// The step the launch path really performs, against a real database: it used to delete the row
    /// and insert a fresh one, which is the data loss; this drives the read, the roll and the save.
    func test_storing_keeps_the_users_row_and_only_moves_its_dates() throws {
        let db = try DatabaseQueue()
        try DatabaseManager.makeMigrator().migrate(db)

        let original = UserProfileModel(
            sensitivity: "high",
            wakeTime: date(2026, 9, 30, 5, 30),
            sleepTime: date(2026, 9, 30, 22, 15),
            metabolismRate: "slow",
            stackCompounds: ["Caffeine"]
        )
        try db.write { db in
            try original.save(db)
        }

        try db.write { db in
            try ProfileDayRoll.store(in: db, day: date(2026, 10, 16, 9, 12), calendar: calendar)
        }

        let stored = try db.read { db in
            try UserProfileModel.fetchOne(db)
        }

        XCTAssertEqual(stored?.id, original.id, "the stored profile is a different row")
        XCTAssertEqual(stored?.sensitivity, "high")
        XCTAssertEqual(stored?.metabolismRate, "slow")
        XCTAssertEqual(stored?.stackCompounds, ["Caffeine"])
        XCTAssertEqual(stored?.wakeTime, date(2026, 10, 16, 5, 30))
        XCTAssertEqual(stored?.sleepTime, date(2026, 10, 16, 22, 15))
        XCTAssertEqual(
            try db.read { db in try UserProfileModel.fetchCount(db) },
            1,
            "the roll left more than one profile behind"
        )
    }

    func test_a_first_run_gets_the_defaults_on_that_day() {
        let today = date(2026, 10, 16, 9, 12)

        let rolled = ProfileDayRoll.profileToStore(existing: nil, day: today, calendar: calendar)

        XCTAssertEqual(rolled.wakeTime, date(2026, 10, 16, 7, 0))
        XCTAssertEqual(rolled.sleepTime, date(2026, 10, 16, 23, 0))
        XCTAssertEqual(rolled.stackCompounds, [NootropicCompound.caffeine.rawValue])
    }
}
