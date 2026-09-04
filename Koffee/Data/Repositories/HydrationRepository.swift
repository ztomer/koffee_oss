import Foundation
import GRDB
import Combine

final class HydrationRepository: HydrationRepositoryProtocol {
    private let db: DatabaseQueue
    @Published private(set) var entries: [HydrationEntryModel] = []
    private var cancellables = Set<AnyCancellable>()

    init(db: DatabaseQueue) {
        self.db = db
        self.entries = (try? db.read { db in try HydrationEntryModel.order(HydrationEntryModel.Columns.timestamp).fetchAll(db) }) ?? []
        startObserving()
    }

    private func startObserving() {
        ValueObservation
            .tracking { db in
                try HydrationEntryModel.order(HydrationEntryModel.Columns.timestamp).fetchAll(db)
            }
            .publisher(in: db, scheduling: .immediate)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] entries in
                    self?.entries = entries
                }
            )
            .store(in: &cancellables)
    }

    func add(amountMl: Double) throws {
        guard amountMl > 0 else {
            throw RepositoryError.validationFailed("amountMl must be positive, got \(amountMl)")
        }
        guard amountMl <= 5000 else {
            throw RepositoryError.validationFailed("amountMl exceeds maximum (5000ml), got \(amountMl)")
        }
        let entry = HydrationEntryModel(amountMl: amountMl)
        try db.write { db in
            try entry.insert(db)
        }
    }

    func entriesForDate(_ date: Date) throws -> [HydrationEntryModel] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let results = try db.read { db in
            try HydrationEntryModel
                .filter(SQLRequest(sql: "timestamp >= ? AND timestamp < ?", arguments: [start, end]))
                .fetchAll(db)
        }
        return results.sorted { $0.timestamp < $1.timestamp }
    }

    func delete(_ entry: HydrationEntryModel) throws {
        _ = try db.write { db in
            try entry.delete(db)
        }
    }
}
