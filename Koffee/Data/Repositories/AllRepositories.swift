import Foundation
import GRDB
import Combine

// Protocols defined in RepositoryProtocols.swift - same target, auto-visible
// If build errors, we'll see which protocol is missing

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
