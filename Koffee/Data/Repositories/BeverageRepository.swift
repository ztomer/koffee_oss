import Foundation
import GRDB
import Combine

final class BeverageRepository: BeverageRepositoryProtocol {
    private let db: DatabaseQueue
    @Published private(set) var beverages: [BeverageModel] = []
    private var cancellables = Set<AnyCancellable>()

    init(db: DatabaseQueue) {
        self.db = db
        self.beverages = (try? db.read { db in try BeverageModel.order(Column("sort_order")).fetchAll(db) }) ?? []
        startObserving()
    }

    private func startObserving() {
        ValueObservation
            .tracking { db in
                try BeverageModel.order(Column("sort_order")).fetchAll(db)
            }
            .publisher(in: db, scheduling: .immediate)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] beverages in
                    self?.beverages = beverages
                }
            )
            .store(in: &cancellables)
    }

    func seed(_ beverages: [BeverageModel]) throws {
        try db.write { db in
            for beverage in beverages {
                try beverage.insert(db, onConflict: .replace)
            }
        }
    }

    func deleteAll() throws {
        try db.write { db in
            _ = try BeverageModel.deleteAll(db)
        }
    }
}
