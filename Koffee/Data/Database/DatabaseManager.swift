import Foundation
import GRDB

@MainActor
final class DatabaseManager {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?
    private(set) var referenceQueue: DatabaseQueue?
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

        openReferenceDatabase()
    }

    private func openReferenceDatabase() {
        guard let bundleURL = Bundle.main.url(forResource: "koffee_reference", withExtension: "sqlite") else {
            print("[DatabaseManager] Reference DB not found in bundle")
            return
        }

        do {
            var config = Configuration()
            config.readonly = true
            referenceQueue = try DatabaseQueue(path: bundleURL.path, configuration: config)
            print("[DatabaseManager] Reference DB opened (readonly): \(bundleURL.path)")
        } catch {
            print("[DatabaseManager] Failed to open reference DB: \(error)")
        }
    }

    func queue() -> DatabaseQueue {
        guard let db = dbQueue else {
            fatalError("Database not opened. Call open() first.")
        }
        return db
    }

    func referenceQueueForReading() -> DatabaseQueue? {
        return referenceQueue
    }

    /// Canonical database schema, shared by the app and every test store.
    ///
    /// Policy (owner-sanctioned 2026-08): legacy schema versions are no longer
    /// migrated forward. `v8_clean_schema` drops any pre-existing app tables and
    /// rebuilds the final schema deterministically, so a database created under
    /// v1-v7 is wiped (data loss accepted) rather than migrated.
    ///
    /// This is the ONE schema path. Tests must build their stores through it —
    /// hand-rolled fixture SQL is what let `doses.compound_uuid` drift.
    nonisolated static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v8_clean_schema") { db in
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

            try db.create(table: "supplement_logs") { t in
                t.column("id", .text).primaryKey()
                t.column("compound_name", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("status", .text).notNull().defaults(to: "completed")
            }

            try db.create(table: "hydration_entries") { t in
                t.column("id", .text).primaryKey()
                t.column("amount_ml", .double).notNull()
                t.column("timestamp", .datetime).notNull()
            }

            try db.create(table: "exercise_logs") { t in
                t.column("id", .text).primaryKey()
                t.column("activity_name", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("duration_minutes", .integer)
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
                t.column("nutrition_template_id", .text)
                t.column("exercise_template_id", .text)
                t.column("quantity", .double).notNull().defaults(to: 1.0)
            }

            try db.create(table: "nutrition_templates") { t in
                t.column("id", .text).primaryKey()
                t.column("external_db_id", .text)
                t.column("name", .text).notNull()
                t.column("category", .text).notNull()
                t.column("calories", .double).notNull()
                t.column("protein_g", .double).notNull().defaults(to: 0)
                t.column("carbs_g", .double).notNull().defaults(to: 0)
                t.column("fat_g", .double).notNull().defaults(to: 0)
                t.column("fiber_g", .double).notNull().defaults(to: 0)
                t.column("is_absorption_blocker", .boolean).notNull().defaults(to: false)
                t.column("requires_fasted_state", .boolean).notNull().defaults(to: false)
            }

            try db.create(virtualTable: "nutrition_fts", using: FTS5()) { t in
                t.synchronize(withTable: "nutrition_templates")
                t.column("name")
                t.column("category")
            }

            try db.create(table: "exercise_templates") { t in
                t.column("id", .text).primaryKey()
                t.column("external_db_id", .text)
                t.column("name", .text).notNull()
                t.column("muscle_group", .text).notNull()
                t.column("base_met", .double).notNull()
                t.column("maintains_hepatic_perfusion", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "daily_biometrics") { t in
                t.column("id", .text).primaryKey()
                t.column("sleep_score", .double)
                t.column("deep_sleep_minutes", .integer)
                t.column("rem_sleep_minutes", .integer)
                t.column("resting_heart_rate", .double)
                t.column("heart_rate_variability", .double)
                t.column("source", .text).notNull().defaults(to: "Manual")
                t.column("last_synced_at", .datetime).notNull()
            }

            try db.create(index: "daily_plan_items_day_key", on: "daily_plan_items", columns: ["day_key"])
            try db.create(index: "doses_timestamp", on: "doses", columns: ["timestamp"])
            try db.create(index: "supplement_logs_timestamp", on: "supplement_logs", columns: ["timestamp"])
            try db.create(index: "hydration_entries_timestamp", on: "hydration_entries", columns: ["timestamp"])
            try db.create(index: "exercise_logs_timestamp", on: "exercise_logs", columns: ["timestamp"])
            try db.create(index: "daily_biometrics_last_synced", on: "daily_biometrics", columns: ["last_synced_at"])
        }
        return migrator
    }

    private func migrator() -> DatabaseMigrator {
        DatabaseManager.makeMigrator()
    }
}
