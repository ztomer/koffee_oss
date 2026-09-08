import Foundation
import GRDB

@MainActor
final class DatabaseManager {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?
    private(set) var isReady = false

    static let dbURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Koffee", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("koffee.sqlite")
    }()

    private init() {}

    func open() async throws {
        if dbQueue != nil { return }

        dbQueue = try DatabaseQueue(path: DatabaseManager.dbURL.path)

        try migrator().migrate(dbQueue!)
        isReady = true
        print("[DatabaseManager] Opened at \(DatabaseManager.dbURL.path)")
    }

    func queue() -> DatabaseQueue {
        guard let db = dbQueue else {
            fatalError("Database not opened. Call open() first.")
        }
        return db
    }

    /// Canonical database schema, shared by the app and every test store.
    ///
    /// Policy (owner-sanctioned 2026-08): legacy schema versions are no longer
    /// migrated forward. `v9_coffee_schema` drops any pre-existing app tables and
    /// rebuilds the final schema deterministically, so a database created under
    /// v1-v8 is wiped (data loss accepted) rather than migrated. v9 removes the
    /// non-coffee tables (supplement_logs, hydration_entries, exercise_logs,
    /// nutrition_templates + FTS, exercise_templates, daily_biometrics) and the
    /// nutrition/exercise template columns on daily_plan_items.
    ///
    /// This is the ONE schema path. Tests must build their stores through it —
    /// hand-rolled fixture SQL is what let `doses.compound_uuid` drift.
    nonisolated static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v9_coffee_schema") { db in
            // Kill legacy schemas wholesale. Children first so foreign keys hold.
            for table in [
                "daily_plan_items",
                "daily_biometrics",
                "nutrition_fts",
                "nutrition_templates",
                "exercise_templates",
                "doses",
                "supplement_logs",
                "hydration_entries",
                "exercise_logs",
                "beverages",
                "user_profile"
            ] {
                try db.execute(sql: "DROP TABLE IF EXISTS \(table)")
            }

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
                t.column("auto_refresh_plan", .boolean).notNull().defaults(to: true)
                t.column("notifications_enabled", .boolean).notNull().defaults(to: true)
                t.column("tolerance_alerts_enabled", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "beverages") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("caffeine_mg", .integer).notNull()
                t.column("category", .text).notNull()
                t.column("icon", .text).notNull()
                t.column("sort_order", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "doses") { t in
                t.column("id", .text).primaryKey()
                t.column("beverage_id", .text)
                t.column("timestamp", .datetime).notNull()
                t.column("caffeine_mg", .double).notNull()
                t.column("beverage_name", .text)
                t.column("compound_uuid", .text).defaults(to: "caffeine")
                t.column("is_plan_item", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "daily_plan_items") { t in
                t.column("id", .text).primaryKey()
                t.column("compound_uuid", .text).notNull().indexed()
                t.column("day_key", .text).notNull().indexed()
                t.column("compound_name", .text).notNull()
                t.column("dose_mg", .double).notNull()
                t.column("source", .text).notNull()
                t.column("status", .text).notNull()
                t.column("scheduled_time", .double).notNull()
                t.column("actual_taken_time", .double)
                t.column("quantity", .double).notNull().defaults(to: 1.0)
            }

            try db.create(index: "daily_plan_items_day_key", on: "daily_plan_items", columns: ["day_key"])
            try db.create(index: "doses_timestamp", on: "doses", columns: ["timestamp"])
        }
        return migrator
    }

    private func migrator() -> DatabaseMigrator {
        DatabaseManager.makeMigrator()
    }
}
