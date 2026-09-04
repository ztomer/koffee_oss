import Foundation
import GRDB

protocol TelemetryProvider: Sendable {
    var id: String { get }
    var name: String { get }
    var icon: String { get }

    func isAuthorized() async -> Bool
    func authorize() async throws
    func disconnect() async throws
    func fetchDailyBiometrics(for date: Date) async throws -> DailyBiometricsModel
}

enum TelemetryProviderError: Error, LocalizedError {
    case notAuthorized
    case tokenRefreshFailed
    case networkError(Error)
    case mappingError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Provider not authorized. Please complete OAuth flow."
        case .tokenRefreshFailed:
            return "Failed to refresh OAuth tokens."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .mappingError(let message):
            return "Data mapping error: \(message)"
        case .invalidResponse:
            return "Invalid response from provider API."
        }
    }
}

struct TelemetryProviderFactory {
    static let availableProviders: [any TelemetryProvider.Type] = [
        OuraProvider.self
    ]

    @MainActor
    static func provider(for id: String) -> (any TelemetryProvider)? {
        switch id {
        case OuraProvider.id:
            return OuraProvider()
        default:
            return nil
        }
    }
}
