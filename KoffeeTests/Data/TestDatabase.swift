import Foundation
import GRDB
@testable import Koffee

/// Provides a pre-configured in-memory GRDB database with the full app schema.
///
/// The schema comes from `DatabaseManager.makeMigrator()` — the ONE canonical
/// schema path. Never hand-roll fixture SQL here: drifted copies of this schema
/// are what produced the `doses.compound_uuid` / `notifications_enabled`
/// failures (fixed 2026-08).
///
/// Usage:
///   let testDB = TestDatabase()
///   let appState = testDB.makeAppState()
///   // ... test code ...
@MainActor
final class TestDatabase {
    let db: DatabaseQueue
    let profileRepo: UserProfileRepository
    let doseRepo: DoseRepository
    let beverageRepo: BeverageRepository
    let planRepo: DailyPlanRepository
    let appState: AppState

    init() throws {
        db = try DatabaseQueue()
        try DatabaseManager.makeMigrator().migrate(db)

        profileRepo = UserProfileRepository(db: db)
        doseRepo = DoseRepository(db: db)
        beverageRepo = BeverageRepository(db: db)
        planRepo = DailyPlanRepository(db: db)

        appState = AppState(
            profileRepo: profileRepo,
            doseRepo: doseRepo,
            beverageRepo: beverageRepo,
            planRepo: planRepo
        )
    }
}
