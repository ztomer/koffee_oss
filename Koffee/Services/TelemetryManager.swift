import Foundation
import Combine

@MainActor
final class TelemetryManager: ObservableObject {
    @Published var isSyncing: Bool = false
    @Published private(set) var providerStatuses: [String: ProviderStatus] = [:]

    private var appState: AppState?
    private var providers: [any TelemetryProvider] = []

    var availableProviders: [any TelemetryProvider] {
        return providers
    }
    private let authContext = AuthContextProvider.shared

    enum ProviderStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    init() {
        setupProviders()
    }

    func configure(with appState: AppState) {
        self.appState = appState
    }

    private func setupProviders() {
        if let ouraProvider = TelemetryProviderFactory.provider(for: "oura") {
            providers.append(ouraProvider)
            providerStatuses[ouraProvider.id] = .disconnected
        }
    }

    func connect(provider: any TelemetryProvider) async {
        providerStatuses[provider.id] = .connecting

        do {
            try await provider.authorize()
            providerStatuses[provider.id] = .connected
            await syncProvider(provider)
        } catch {
            providerStatuses[provider.id] = .error(error.localizedDescription)
        }
    }

    func disconnect(provider: any TelemetryProvider) async {
        do {
            try await provider.disconnect()
            providerStatuses[provider.id] = .disconnected
        } catch {
            providerStatuses[provider.id] = .error(error.localizedDescription)
        }
    }

    func syncAllAuthorizedProviders() async {
        guard !isSyncing else { return }
        isSyncing = true

        for provider in providers {
            let isAuthorized = await provider.isAuthorized()
            if isAuthorized {
                await syncProvider(provider)
            }
        }

        isSyncing = false
    }

    private func syncProvider(_ provider: any TelemetryProvider) async {
        do {
            let biometrics = try await provider.fetchDailyBiometrics(for: Date())
            appState?.saveBiometrics(biometrics)
        } catch {
            providerStatuses[provider.id] = .error(error.localizedDescription)
        }
    }

    func isConnected(providerId: String) -> Bool {
        return providerStatuses[providerId] == .connected
    }

    func status(for providerId: String) -> ProviderStatus {
        return providerStatuses[providerId] ?? .disconnected
    }
}
