import Foundation
import GRDB
import Combine

enum RepositoryError: Error, LocalizedError {
    case notFound(String)
    case validationFailed(String)
    case databaseError(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let msg): return "Not found: \(msg)"
        case .validationFailed(let msg): return "Validation failed: \(msg)"
        case .databaseError(let msg): return "Database error: \(msg)"
        }
    }
}

protocol UserProfileRepositoryProtocol: AnyObject, ObservableObject {
    var profile: UserProfileModel? { get }
    func save(_ profile: UserProfileModel) throws
    func getOrCreate() throws -> UserProfileModel
}

protocol DoseRepositoryProtocol: AnyObject, ObservableObject {
    var doses: [DoseModel] { get }
    func add(beverageId: String?, timestamp: Date, caffeineMg: Double, beverageName: String?) throws
    func delete(_ dose: DoseModel) throws
    func dosesForDate(_ date: Date) throws -> [DoseModel]
}

protocol BeverageRepositoryProtocol: AnyObject, ObservableObject {
    var beverages: [BeverageModel] { get }
    func seed(_ beverages: [BeverageModel]) throws
    func deleteAll() throws
}

protocol SupplementLogRepositoryProtocol: AnyObject, ObservableObject {
    var logs: [SupplementLogModel] { get }
    func add(compoundName: String, status: PlanItemStatus) throws
    func logsForDate(_ date: Date) throws -> [SupplementLogModel]
}

protocol HydrationRepositoryProtocol: AnyObject, ObservableObject {
    var entries: [HydrationEntryModel] { get }
    func add(amountMl: Double) throws
    func entriesForDate(_ date: Date) throws -> [HydrationEntryModel]
    func delete(_ entry: HydrationEntryModel) throws
}

protocol ExerciseRepositoryProtocol: AnyObject, ObservableObject {
    var logs: [ExerciseLogModel] { get }
    func add(activityName: String, durationMinutes: Int?) throws
    func logsForDate(_ date: Date) throws -> [ExerciseLogModel]
    func delete(_ log: ExerciseLogModel) throws
}
