import Foundation
import GRDB
import AuthenticationServices

@MainActor
final class OuraProvider: TelemetryProvider, @unchecked Sendable {
    static let id = "oura"

    let id: String = OuraProvider.id
    let name: String = "Oura Ring"
    let icon: String = "circle.hexagonpath"

    private let credentialManager = TelemetryCredentialManager.shared
    private let clientId: String
    private let clientSecret: String

    private let authEndpoint = "https://cloud.ouraring.com/oauth/authorize"
    private let tokenEndpoint = "https://cloud.ouraring.com/oauth/token"
    private let apiBaseUrl = "https://api.ouraring.com/v2/usercollection"

    init() {
        self.clientId = ProcessInfo.processInfo.environment["OURA_CLIENT_ID"] ?? ""
        self.clientSecret = ProcessInfo.processInfo.environment["OURA_CLIENT_SECRET"] ?? ""
    }

    func isAuthorized() async -> Bool {
        return credentialManager.hasTokens(provider: Self.id)
    }

    func authorize() async throws {
        guard !clientId.isEmpty else {
            throw TelemetryProviderError.notAuthorized
        }

        let redirectScheme = "com.koffee.telemetry"
        let redirectURI = "\(redirectScheme)://oauth/callback"

        var components = URLComponents(string: authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "daily")
        ]

        guard let authURL = components.url else {
            throw TelemetryProviderError.notAuthorized
        }

        let authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: redirectScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }

            if let error = error {
                print("OAuth error: \(error.localizedDescription)")
                return
            }

            guard let callbackURL = callbackURL,
                  let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "code" })?
                    .value else {
                return
            }

            Task {
                await self.exchangeCodeForTokens(code: code, redirectURI: redirectURI)
            }
        }

        authSession.presentationContextProvider = AuthContextProvider.shared
        authSession.prefersEphemeralWebBrowserSession = false
        authSession.start()
    }

    private func exchangeCodeForTokens(code: String, redirectURI: String) async {
        var components = URLComponents(string: tokenEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret)
        ]

        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }

            let tokenResponse = try JSONDecoder().decode(OuraTokenResponse.self, from: data)

            try? credentialManager.saveTokens(
                provider: Self.id,
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken
            )
        } catch {
            print("Token exchange failed: \(error)")
        }
    }

    func disconnect() async throws {
        try credentialManager.clearTokens(provider: Self.id)
    }

    func fetchDailyBiometrics(for date: Date) async throws -> DailyBiometricsModel {
        guard let tokens = credentialManager.getTokens(provider: Self.id) else {
            throw TelemetryProviderError.notAuthorized
        }

        // Try to use stored auth state if available
        // Auth state available - using stored tokens for now
        if credentialManager.getAuthState(provider: Self.id) != nil {
        }

        let accessToken = tokens.accessToken

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: endDate)

        let urlString = "\(apiBaseUrl)/daily_sleep?start_date=\(startStr)&end_date=\(endStr)"
        guard let url = URL(string: urlString) else {
            throw TelemetryProviderError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                // Token expired, try to refresh
                if let newToken = await refreshToken(tokens.refreshToken) {
                    // Retry with new token
                    return try await fetchDailyBiometricsWithToken(newToken, date: date)
                }
                throw TelemetryProviderError.tokenRefreshFailed
            }
            throw TelemetryProviderError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let ouraResponse = try decoder.decode(OuraDailySleepResponse.self, from: data)

            guard let sleepData = ouraResponse.data.first else {
                throw TelemetryProviderError.mappingError("No sleep data found for date")
            }

            let dayKey = DailyBiometricsModel.dayKey(for: date)

            return DailyBiometricsModel(
                id: dayKey,
                sleepScore: sleepData.score,
                deepSleepMinutes: sleepData.totalStages?.deep,
                remSleepMinutes: sleepData.totalStages?.rem,
                restingHeartRate: sleepData.restingHeartRate,
                heartRateVariability: sleepData.heartRateVariability,
                source: "Oura",
                lastSyncedAt: Date()
            )
        } catch let error as DecodingError {
            throw TelemetryProviderError.mappingError("Failed to decode Oura response: \(error.localizedDescription)")
        }
    }

    private func fetchDailyBiometricsWithToken(_ token: String, date: Date) async throws -> DailyBiometricsModel {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: endDate)

        let urlString = "\(apiBaseUrl)/daily_sleep?start_date=\(startStr)&end_date=\(endStr)"
        guard let url = URL(string: urlString) else {
            throw TelemetryProviderError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TelemetryProviderError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let ouraResponse = try decoder.decode(OuraDailySleepResponse.self, from: data)

        guard let sleepData = ouraResponse.data.first else {
            throw TelemetryProviderError.mappingError("No sleep data found for date")
        }

        let dayKey = DailyBiometricsModel.dayKey(for: date)

        return DailyBiometricsModel(
            id: dayKey,
            sleepScore: sleepData.score,
            deepSleepMinutes: sleepData.totalStages?.deep,
            remSleepMinutes: sleepData.totalStages?.rem,
            restingHeartRate: sleepData.restingHeartRate,
            heartRateVariability: sleepData.heartRateVariability,
            source: "Oura",
            lastSyncedAt: Date()
        )
    }

    private func refreshToken(_ refreshToken: String) async -> String? {
        var components = URLComponents(string: tokenEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret)
        ]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let tokenResponse = try JSONDecoder().decode(OuraTokenResponse.self, from: data)

            try? credentialManager.saveTokens(
                provider: Self.id,
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken
            )

            return tokenResponse.accessToken
        } catch {
            return nil
        }
    }
}

// MARK: - Oura API Response Models

struct OuraDailySleepResponse: Codable {
    let data: [OuraSleepData]
}

struct OuraSleepData: Codable {
    let score: Double?
    let totalStages: OuraSleepStages?
    let restingHeartRate: Double?
    let heartRateVariability: Double?
    let day: String

    enum CodingKeys: String, CodingKey {
        case score
        case totalStages = "total_stages"
        case restingHeartRate = "resting_heart_rate"
        case heartRateVariability = "heart_rate_variability"
        case day
    }
}

struct OuraSleepStages: Codable {
    let deep: Int?
    let light: Int?
    let rem: Int?
    let awake: Int?
}

// MARK: - Token Exchange Models

struct OuraTokenRequest: Codable {
    let grantType: String
    let code: String
    let redirectURI: String
    let clientId: String
    let clientSecret: String

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case code
        case redirectURI = "redirect_uri"
        case clientId = "client_id"
        case clientSecret = "client_secret"
    }
}

struct OuraTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}
