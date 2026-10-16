import XCTest
@testable import Koffee

/// L2 (Phase 0c). The test bundle's host IS the app (`project.yml` sets `TEST_HOST` to
/// `Koffee.app`), so this suite runs inside a process whose launch already opened
/// `DatabaseManager.shared`. If that singleton points at the user's real file, then every
/// `xcodebuild test` — and therefore every push, since `tools/gate.sh --full` runs them — reads
/// and writes the user's own database.
///
/// This test is the assertion; the measurement behind it is in the roadmap: a single existing
/// test run moved a live profile's `wake_time` from 2026-10-15 11:00 to 2026-10-16 11:00.
///
/// It runs green only because it IS a test process, which is the point: the guard it pins is the
/// one a test process needs.
@MainActor
final class DatabaseIsolationTests: XCTestCase {

    /// The path the app itself uses, derived here the same way `DatabaseManager` derives it — from
    /// the user's Application Support directory, not from the test's environment.
    private var liveDatabaseURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Koffee", isDirectory: true)
            .appendingPathComponent("koffee.sqlite")
    }

    func test_this_test_process_is_not_pointed_at_the_users_live_database() {
        XCTAssertNotEqual(
            DatabaseManager.dbURL.standardizedFileURL.path,
            liveDatabaseURL.standardizedFileURL.path,
            """
            the test host is pointed at the user's live database \
            (\(DatabaseManager.dbURL.path)); the push gate runs this suite, so a push writes to it
            """
        )
    }

    /// The other direction, so the guard cannot be satisfied by pointing the app somewhere else
    /// too: the app's own database stays the user's file.
    func test_the_apps_own_database_is_still_the_users_file() {
        XCTAssertEqual(
            DatabaseManager.appSupportDatabaseURL.standardizedFileURL.path,
            liveDatabaseURL.standardizedFileURL.path
        )
    }

    /// Why the path above is the scratch one: this process is a test host. Pins the mechanism, so a
    /// renamed `xcodebuild` variable that quietly stopped matching would fail here instead of
    /// silently re-pointing the suite at the user's file.
    func test_this_process_is_recognised_as_a_test_host() {
        XCTAssertTrue(DatabaseManager.isTestingProcess)
    }

    /// And the scratch store has to be a working store, or the fix trades a data-loss bug for a
    /// broken suite: `AppState+DailyPlan`'s `dbWrite` and `BeverageManager` both call
    /// `DatabaseManager.shared.queue()`, which traps unless `open()` ran.
    func test_the_scratch_store_opens_and_leaves_the_users_file_alone() async throws {
        let liveMTimeBefore = try FileManager.default
            .attributesOfItem(atPath: liveDatabaseURL.path)[.modificationDate] as? Date

        try await DatabaseManager.shared.open()
        let tables = try await DatabaseManager.shared.queue().read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table'") ?? 0
        }

        XCTAssertGreaterThan(tables, 0, "the scratch store opened but the migrator created no tables")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: DatabaseManager.dbURL.path),
            "the scratch database file was never written"
        )

        let liveMTimeAfter = try FileManager.default
            .attributesOfItem(atPath: liveDatabaseURL.path)[.modificationDate] as? Date
        XCTAssertEqual(
            liveMTimeBefore, liveMTimeAfter,
            "opening the suite's store touched the user's live database"
        )
    }
}
