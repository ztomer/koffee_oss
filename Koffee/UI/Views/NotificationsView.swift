import SwiftUI

struct NotificationsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                reminderSection
                scheduleSection
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
                Text("Notifications")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
            }
            Text("Manage reminders and alerts")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("REMINDERS", icon: "alarm")

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { appState.profile?.notificationsEnabled ?? true },
                    set: { newValue in
                        if var profile = appState.profile {
                            profile.notificationsEnabled = newValue
                            try? appState.saveProfile(profile)
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Reminders")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Get notified when to take your stack")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { appState.profile?.toleranceAlertsEnabled ?? true },
                    set: { newValue in
                        if var profile = appState.profile {
                            profile.toleranceAlertsEnabled = newValue
                            try? appState.saveProfile(profile)
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tolerance Alerts")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Alert when tolerance cycle needs reset")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("SCHEDULED", icon: "calendar")

            if appState.profile?.notificationsEnabled ?? false {
                reminderList
            } else {
                Text("Enable reminders to see schedule")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private var reminderList: some View {
        VStack(spacing: 8) {
            ForEach(appState.todayRecommendations) { recommendation in
                reminderRow(for: recommendation)
            }

            if appState.todayRecommendations.isEmpty {
                Text("No upcoming reminders")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
    }

    private func reminderRow(for recommendation: ActionableRecommendation) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(iconColor(for: recommendation.type))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.title)
                    .font(.system(size: 14, weight: .medium))
                Text(formatTime(recommendation.scheduledTime))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("P\(recommendation.priority)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(iconColor(for: recommendation.type))
                .clipShape(.rect(cornerRadius: 4))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func iconColor(for type: ActionableRecommendation.RecommendationType) -> Color {
        switch type {
        case .caffeineCutoff: return .orange
        case .takeCompound: return .blue
        case .hydrate: return .cyan
        case .sleepPrep: return .purple
        case .exercise: return .green
        case .replaceCompound: return .yellow
        case .avoidCompound: return .red
        }
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
