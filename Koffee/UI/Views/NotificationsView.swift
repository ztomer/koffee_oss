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
                        Text("Get notified about caffeine cutoff and tolerance")
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
        let pendingCaffeine = appState.pendingPlanItemsTodayByCompound("caffeine")
        return VStack(spacing: 8) {
            ForEach(pendingCaffeine) { item in
                reminderRow(title: "\(item.compoundName) \(Int(item.doseMg))mg", time: item.scheduledTime)
            }

            if pendingCaffeine.isEmpty {
                Text("No upcoming reminders")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
    }

    private func reminderRow(title: String, time: Date) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.orange)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(formatTime(time))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()
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

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
