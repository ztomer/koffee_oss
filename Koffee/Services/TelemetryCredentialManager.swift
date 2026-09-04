import Foundation
import KeychainAccess

final class TelemetryCredentialManager: @unchecked Sendable {
    static let shared = TelemetryCredentialManager()

    private let keychain: Keychain

    private init() {
        keychain = Keychain(service: "com.koffee.telemetry")
            .accessibility(.whenUnlocked)
    }

    func saveTokens(provider: String, accessToken: String, refreshToken: String) throws {
        try keychain.set(accessToken, key: "\(provider)_access_token")
        try keychain.set(refreshToken, key: "\(provider)_refresh_token")
    }

    func getTokens(provider: String) -> (accessToken: String, refreshToken: String)? {
        guard let accessToken = try? keychain.get("\(provider)_access_token"),
              let refreshToken = try? keychain.get("\(provider)_refresh_token") else {
            return nil
        }
        return (accessToken, refreshToken)
    }

    func getAccessToken(provider: String) -> String? {
        return try? keychain.get("\(provider)_access_token")
    }

    func clearTokens(provider: String) throws {
        try keychain.remove("\(provider)_access_token")
        try keychain.remove("\(provider)_refresh_token")
    }

    func hasTokens(provider: String) -> Bool {
        return getTokens(provider: provider) != nil
    }

    func saveAuthState(provider: String, authStateData: Data) throws {
        try keychain.set(authStateData, key: "\(provider)_auth_state")
    }

    func getAuthState(provider: String) -> Data? {
        return try? keychain.getData("\(provider)_auth_state")
    }

    func clearAuthState(provider: String) throws {
        try keychain.remove("\(provider)_auth_state")
    }
}
