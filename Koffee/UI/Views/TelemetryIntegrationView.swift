import SwiftUI

struct TelemetryIntegrationView: View {
    @ObservedObject var telemetryManager: TelemetryManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection

            if telemetryManager.isSyncing {
                syncIndicator
            }

            providerList
        }
        .padding()
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Biometric Integrations")
                    .font(.headline)
                Text("Connect your wearable devices to enable closed-loop optimization")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                Task {
                    await telemetryManager.syncAllAuthorizedProviders()
                }
            }, label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync Now")
                }
            })
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(telemetryManager.isSyncing)
        }
    }

    private var syncIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Syncing biometric data...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var providerList: some View {
        VStack(spacing: 12) {
            ForEach(telemetryManager.availableProviders, id: \.id) { provider in
                ProviderCard(
                    provider: provider,
                    status: telemetryManager.status(for: provider.id),
                    isConnected: telemetryManager.isConnected(providerId: provider.id),
                    onConnect: {
                        Task {
                            await telemetryManager.connect(provider: provider)
                        }
                    },
                    onDisconnect: {
                        Task {
                            await telemetryManager.disconnect(provider: provider)
                        }
                    }
                )
            }
        }
    }
}

struct ProviderCard: View {
    let provider: any TelemetryProvider
    let status: TelemetryManager.ProviderStatus
    let isConnected: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            providerIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(provider.name)
                    .font(.headline)
                statusLabel
            }

            Spacer()

            actionButton
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private var providerIcon: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 44, height: 44)

            Image(systemName: provider.icon)
                .font(.system(size: 20))
                .foregroundColor(.orange)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch status {
        case .disconnected:
            Text("Disconnected")
                .font(.caption)
                .foregroundColor(.secondary)
        case .connecting:
            Text("Connecting...")
                .font(.caption)
                .foregroundColor(.orange)
        case .connected:
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        case .error(let message):
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
    }

    private var actionButton: some View {
        Group {
            if isConnected {
                Button("Disconnect") {
                    onDisconnect()
                }
                .buttonStyle(.bordered)
            } else {
                Button("Connect") {
                    onConnect()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .controlSize(.small)
    }
}
