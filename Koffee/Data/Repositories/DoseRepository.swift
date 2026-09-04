import Foundation
import GRDB
import Combine

final class DoseRepository: DoseRepositoryProtocol {
    private let db: DatabaseQueue
    @Published private(set) var doses: [DoseModel] = []
    private var cancellables = Set<AnyCancellable>()

    init(db: DatabaseQueue) {
        self.db = db
        self.doses = (try? db.read { db in
            try DoseModel.order(DoseModel.Columns.timestamp).fetchAll(db)
        }) ?? []
        startObserving()
    }

    private func startObserving() {
        ValueObservation
            .tracking { db in
                try DoseModel.order(DoseModel.Columns.timestamp).fetchAll(db)
            }
            .publisher(in: db, scheduling: .immediate)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] doses in
                    self?.doses = doses
                }
            )
            .store(in: &cancellables)
    }

    func add(beverageId: String? = nil, timestamp: Date, caffeineMg: Double, beverageName: String? = nil) throws {
        guard caffeineMg >= 0 else {
            throw RepositoryError.validationFailed("caffeineMg must be non-negative, got \(caffeineMg)")
        }
        guard caffeineMg <= 1000 else {
            throw RepositoryError.validationFailed("caffeineMg exceeds maximum (1000mg), got \(caffeineMg)")
        }

        let dose = DoseModel(beverageId: beverageId, timestamp: timestamp, caffeineMg: caffeineMg, beverageName: beverageName)
        try db.write { db in
            try dose.insert(db)
        }
    }

    func addWithId(id: String, beverageId: String? = nil, timestamp: Date, caffeineMg: Double, beverageName: String? = nil) throws {
        guard caffeineMg >= 0 else {
            throw RepositoryError.validationFailed("caffeineMg must be non-negative, got \(caffeineMg)")
        }
        guard caffeineMg <= 1000 else {
            throw RepositoryError.validationFailed("caffeineMg exceeds maximum (1000mg), got \(caffeineMg)")
        }

        let dose = DoseModel(id: id, beverageId: beverageId, timestamp: timestamp, caffeineMg: caffeineMg, beverageName: beverageName)
        try db.write { db in
            try dose.insert(db)
        }
    }

    func delete(_ dose: DoseModel) throws {
        try db.write { db in
            let deleted = try dose.delete(db)
            guard deleted else {
                throw RepositoryError.notFound("Dose \(dose.id)")
            }
        }
    }

    func dosesForDate(_ date: Date) throws -> [DoseModel] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let results = try db.read { db in
            try DoseModel
                .filter(SQLRequest(sql: "timestamp >= ? AND timestamp < ?", arguments: [start, end]))
                .fetchAll(db)
        }
        return results.sorted { $0.timestamp < $1.timestamp }
    }
}
