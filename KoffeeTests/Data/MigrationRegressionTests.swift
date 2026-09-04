import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Migration Regression Tests
//
// Policy (owner-sanctioned 2026-08): legacy schema versions (v1-v7) are no
// longer migrated forward. DatabaseManager.makeMigrator() registers a single
// clean-schema migration that DROPS any pre-existing app tables and rebuilds
// the final schema deterministically — old data is wiped rather than migrated.
//
// These tests pin that invariant: any database handed to makeMigrator(), fresh
// or legacy, ends up at the final schema with working repositories.

@MainActor
final class MigrationRegressionTests: XCTestCase {

    /// A database shaped like the pre-v8 schema (missing columns that were only
    /// added by later migrations) must be wiped and rebuilt by makeMigrator().
    func testLegacyDatabaseIsRebuiltToFinalSchema() throws {
        let db = try DatabaseQueue()

        // Simulate a LEGACY database: user_profile without auto_refresh_plan /
        // notifications_enabled, doses without compound_uuid / is_plan_item.
        var legacyMigrator = DatabaseMigrator()
        legacyMigrator.registerMigration("v1_initial") { db in
            try db.create(table: "user_profile") { t in
                t.column("id", .text).primaryKey()
                t.column("weight", .double).notNull().defaults(to: 70.0)
                t.column("age", .integer).notNull().defaults(to: 30)
                t.column("height_cm", .double).notNull().defaults(to: 175.0)
                t.column("biological_sex", .text).notNull().defaults(to: "male")
                t.column("sensitivity", .text).notNull().defaults(to: "medium")
                t.column("wake_time", .datetime).notNull()
                t.column("sleep_time", .datetime).notNull()
                t.column("metabolism_rate", .text).notNull().defaults(to: "medium")
                t.column("tolerance_days_since_reset", .integer).notNull().defaults(to: 0)
                t.column("tolerance_reset_days_required", .integer).notNull().defaults(to: 14)
                t.column("optimization_goal", .text).notNull().defaults(to: "balanced")
                t.column("stack_compounds", .text).notNull().defaults(to: "[]")
                t.column("updated_at", .datetime).notNull()
            }
            try db.create(table: "doses") { t in
                t.column("id", .text).primaryKey()
                t.column("beverage_id", .text)
                t.column("timestamp", .datetime).notNull()
                t.column("caffeine_mg", .double).notNull()
                t.column("beverage_name", .text)
            }
        }
        try legacyMigrator.migrate(db)

        // Run the canonical migrator over the legacy database.
        try DatabaseManager.makeMigrator().migrate(db)

        // Final schema columns must exist and defaults must hold.
        let profileColumns = try db.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(user_profile)").map { $0["name"] as String }
        }
        for column in ["auto_refresh_plan", "notifications_enabled", "tolerance_alerts_enabled"] {
            XCTAssertTrue(profileColumns.contains(column), "user_profile should have \(column) after rebuild")
        }

        let doseColumns = try db.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(doses)").map { $0["name"] as String }
        }
        for column in ["compound_uuid", "is_plan_item"] {
            XCTAssertTrue(doseColumns.contains(column), "doses should have \(column) after rebuild")
        }
    }

    /// Verify that getOrCreate works on the canonical schema.
    func testProfileGetOrCreateAfterMigration() throws {
        let db = try DatabaseQueue()
        try DatabaseManager.makeMigrator().migrate(db)

        let profileRepo = UserProfileRepository(db: db)
        let profile = try profileRepo.getOrCreate()

        XCTAssertEqual(profile.autoRefreshPlan, true)
    }
}
