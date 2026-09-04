import Foundation
import GRDB
import Combine

// Protocols defined in RepositoryProtocols.swift - same target, auto-visible
// If build errors, we'll see which protocol is missing

final class SupplementLogRepository: SupplementLogRepositoryProtocol {
    private let db: DatabaseQueue
    @Published private(set) var logs: [SupplementLogModel] = []
    private var cancellables = Set<AnyCancellable>()

    init(db: DatabaseQueue) {
        self.db = db
        self.logs = (try? db.read { db in try SupplementLogModel.order(SupplementLogModel.Columns.timestamp.desc).fetchAll(db) }) ?? []
        startObserving()
    }

    private func startObserving() {
        ValueObservation
            .tracking { db in
                try SupplementLogModel.order(SupplementLogModel.Columns.timestamp.desc).fetchAll(db)
            }
            .publisher(in: db, scheduling: .immediate)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] logs in
                    self?.logs = logs
                }
            )
            .store(in: &cancellables)
    }

    func add(compoundName: String, status: PlanItemStatus = .taken) throws {
        guard !compoundName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw RepositoryError.validationFailed("compoundName must not be empty")
        }
        let log = SupplementLogModel(compoundName: compoundName, status: status)
        try db.write { db in
            try log.insert(db)
        }
    }

    func addWithId(id: String, compoundName: String, status: PlanItemStatus = .taken) throws {
        guard !compoundName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw RepositoryError.validationFailed("compoundName must not be empty")
        }
        let log = SupplementLogModel(id: id, compoundName: compoundName, status: status)
        try db.write { db in
            try log.insert(db)
        }
    }

    func logsForDate(_ date: Date) throws -> [SupplementLogModel] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let results = try db.read { db in
            try SupplementLogModel
                .filter(SQLRequest(sql: "timestamp >= ? AND timestamp < ?", arguments: [start, end]))
                .fetchAll(db)
        }
        return results.sorted { $0.timestamp > $1.timestamp }
    }

    func delete(_ log: SupplementLogModel) throws {
        try db.write { db in
            _ = try log.delete(db)
        }
    }
}

final class ExerciseRepository: ExerciseRepositoryProtocol {
    private let db: DatabaseQueue
    @Published private(set) var logs: [ExerciseLogModel] = []
    private var cancellables = Set<AnyCancellable>()

    init(db: DatabaseQueue) {
        self.db = db
        self.logs = (try? db.read { db in try ExerciseLogModel.order(ExerciseLogModel.Columns.timestamp.desc).fetchAll(db) }) ?? []
        startObserving()
    }

    private func startObserving() {
        ValueObservation
            .tracking { db in
                try ExerciseLogModel.order(ExerciseLogModel.Columns.timestamp.desc).fetchAll(db)
            }
            .publisher(in: db, scheduling: .immediate)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] logs in
                    self?.logs = logs
                }
            )
            .store(in: &cancellables)
    }

    func add(activityName: String, durationMinutes: Int? = nil) throws {
        guard !activityName.isEmpty else {
            throw RepositoryError.validationFailed("activityName must not be empty")
        }
        if let duration = durationMinutes {
            guard duration > 0 else {
                throw RepositoryError.validationFailed("durationMinutes must be positive, got \(duration)")
            }
            guard duration <= 480 else {
                throw RepositoryError.validationFailed("durationMinutes exceeds maximum (480), got \(duration)")
            }
        }
        let log = ExerciseLogModel(activityName: activityName, durationMinutes: durationMinutes)
        try db.write { db in
            try log.insert(db)
        }
    }

    func logsForDate(_ date: Date) throws -> [ExerciseLogModel] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let results = try db.read { db in
            try ExerciseLogModel
                .filter(SQLRequest(sql: "timestamp >= ? AND timestamp < ?", arguments: [start, end]))
                .fetchAll(db)
        }
        return results.sorted { $0.timestamp > $1.timestamp }
    }

    func delete(_ log: ExerciseLogModel) throws {
        _ = try db.write { db in
            try log.delete(db)
        }
    }
}

final class DailyPlanRepository {
    private let db: DatabaseQueue
    @Published private(set) var items: [DailyPlanItemModel] = []
    private var cancellables = Set<AnyCancellable>()

    init(db: DatabaseQueue) {
        self.db = db
        self.items = (try? db.read { db in try DailyPlanItemModel.order(Column("scheduled_time")).fetchAll(db) }) ?? []
        startObserving()
    }

    private func startObserving() {
        ValueObservation
            .tracking { db in
                try DailyPlanItemModel.order(Column("scheduled_time")).fetchAll(db)
            }
            .publisher(in: db, scheduling: .immediate)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] items in
                    self?.items = items
                }
            )
            .store(in: &cancellables)
    }

    /// Re-run the observed query so published state reflects this write NOW.
    /// GRDB 7's `.immediate` scheduler delivers subsequent observations via
    /// DispatchQueue.main.async, so read-after-write must not rely on it.
    private func reload() {
        items = (try? db.read { db in
            try DailyPlanItemModel.order(Column("scheduled_time")).fetchAll(db)
        }) ?? items
    }

    func save(_ item: DailyPlanItemModel) throws {
        guard !item.compoundName.isEmpty else {
            throw RepositoryError.validationFailed("compoundName must not be empty")
        }
        try db.write { db in
            try item.save(db)
        }
        reload()
    }

    func updateStatus(id: String, status: PlanItemStatus) throws {
        try db.write { db in
            if var item = try DailyPlanItemModel.fetchOne(db, id: id) {
                item.status = status
                try item.save(db)
            }
        }
        reload()
    }

    func delete(id: String) throws {
        try db.write { db in
            _ = try DailyPlanItemModel.deleteOne(db, id: id)
        }
        reload()
    }

    func itemsForDay(_ date: Date) throws -> [DailyPlanItemModel] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let results = try db.read { db in
            try DailyPlanItemModel
                .filter(SQLRequest(sql: "scheduled_time >= ? AND scheduled_time < ?", arguments: [start, end]))
                .fetchAll(db)
        }
        return results.sorted { $0.scheduledTime < $1.scheduledTime }
    }

    func deleteAllForDay(_ dayKey: String) throws {
        try db.write { db in
            _ = try DailyPlanItemModel.filter(Column("day_key") == dayKey).deleteAll(db)
        }
    }
}

// MARK: - Biometric Repository

final class BiometricRepository: ObservableObject {
    @Published private(set) var biometrics: DailyBiometricsModel?

    private let db: DatabaseQueue

    init(db: DatabaseQueue) {
        self.db = db
        loadTodayBiometrics()
    }

    private func loadTodayBiometrics() {
        if let today = try? fetchBiometrics(for: Date()) {
            biometrics = today
        }
    }

    func fetchBiometrics(for date: Date) throws -> DailyBiometricsModel? {
        let dayKey = DailyBiometricsModel.dayKey(for: date)
        return try db.read { db in
            try DailyBiometricsModel.fetchOne(db, key: dayKey)
        }
    }

    func save(_ biometrics: DailyBiometricsModel) throws {
        try db.write { db in
            try biometrics.save(db)
        }
        self.biometrics = biometrics
    }

    func update(from date: Date, sleepScore: Double?, deepSleep: Int?, remSleep: Int?, rhr: Double?, hrv: Double?, source: String) throws {
        let dayKey = DailyBiometricsModel.dayKey(for: date)
        var model = try fetchBiometrics(for: date) ?? DailyBiometricsModel(id: dayKey)

        if let score = sleepScore { model.sleepScore = score }
        if let deep = deepSleep { model.deepSleepMinutes = deep }
        if let rem = remSleep { model.remSleepMinutes = rem }
        if let r = rhr { model.restingHeartRate = r }
        if let h = hrv { model.heartRateVariability = h }
        model.source = source
        model.lastSyncedAt = Date()

        try save(model)
    }
}

// MARK: - Reference Repository (Read-Only)

@MainActor
final class ReferenceRepository {
    private var referenceQueue: DatabaseQueue?

    init() {
        self.referenceQueue = DatabaseManager.shared.referenceQueueForReading()
    }

    nonisolated func searchNutrition(query: String) async throws -> [NutritionTemplateModel] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let queue = await getReferenceQueue()
        guard let dbQueue = queue else {
            throw RepositoryError.databaseError("Reference database not available")
        }

        return try await dbQueue.read { db in
            let pattern = query
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces)
                .map { "\($0)*" }
                .joined(separator: " ")

            return try NutritionTemplateModel.fetchAll(db, sql: """
                SELECT nutrition_templates.*
                FROM nutrition_templates
                JOIN nutrition_fts ON nutrition_templates.rowid = nutrition_fts.rowid
                WHERE nutrition_fts MATCH ?
                ORDER BY rank
                LIMIT 50
            """, arguments: [pattern])
        }
    }

    nonisolated func searchExercise(query: String) async throws -> [ExerciseTemplateModel] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let queue = await getReferenceQueue()
        guard let dbQueue = queue else {
            throw RepositoryError.databaseError("Reference database not available")
        }

        return try await dbQueue.read { db in
            try ExerciseTemplateModel
                .filter(Column("name").like("%\(query)%"))
                .limit(50)
                .fetchAll(db)
        }
    }

    private nonisolated func getReferenceQueue() async -> DatabaseQueue? {
        return await MainActor.run {
            DatabaseManager.shared.referenceQueueForReading()
        }
    }
}
