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
