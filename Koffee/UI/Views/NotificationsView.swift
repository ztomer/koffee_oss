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
                        let wasEnabled = appState.profile?.notificationsEnabled ?? false
                        if var profile = appState.profile {
                            profile.notificationsEnabled = newValue
                            try? appState.saveProfile(profile)
                        }
                        if newValue && !wasEnabled {
                            Task {
                                _ = await NotificationManager().requestPermission()
                            }
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
                Text(schedulePreviewLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
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

    private var schedulePreviewLine: String {
        let pending = appState.pendingPlanItemsTodayByCompound("caffeine")
            .sorted { $0.scheduledTime < $1.scheduledTime }
        let profile = appState.profile
        let sensitivity = Sensitivity(swiftDataValue: profile?.sensitivity ?? "") ?? .medium
        let metabolism = MetabolismRate(swiftDataValue: profile?.metabolismRate ?? "") ?? .medium
        return nextNudgeLine(
            pending: pending,
            sleepTime: profile?.sleepTime,
            sensitivity: sensitivity,
            metabolism: metabolism,
            // The biggest dose of the day, not a constant: a cutoff drawn for a
            // 95 mg standard dose is simply the wrong wall for the day the user
            // actually had. With no doses yet the prospective standard is the only
            // honest number available.
            referenceDoseMg: todayReferenceDoseMg
        )
    }

    /// The dose the cutoff is derived from: today's largest logged dose, else the
    /// prospective standard. Never an average — averaging pulls the wall inward.
    private var todayReferenceDoseMg: Double {
        let today = appState.dosesForDate(DateHelper.now)
        let todayMax = today.map(\.caffeineMg).max() ?? 0
        return todayMax > 0 ? todayMax : CaffeineConstants.defaultDoseMg
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

/// Live SCHEDULED preview. Pure for testing: next pending item wins, else the
/// computed caffeine cutoff, else a warm empty line. Never hardcoded times.
///
/// K3. `referenceDoseMg` is the dose the cutoff is drawn for — the day's biggest
/// dose at the call site, so the wall is tight enough for the biggest thing
/// actually consumed and smaller doses get more room than they strictly need.
/// Conservative in the permitted direction, never in the forbidden one.
func nextNudgeLine(
    pending: [DailyPlanItemModel],
    sleepTime: Date?,
    sensitivity: Sensitivity,
    metabolism: MetabolismRate,
    referenceDoseMg: Double
) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    if let next = pending.sorted(by: { $0.scheduledTime < $1.scheduledTime }).first {
        return "Next nudge: \(formatter.string(from: next.scheduledTime)) — \(next.compoundName) \(Int(next.doseMg))mg"
    }
    if let sleep = sleepTime {
        let hours = sensitivity.hoursBeforeBedForLastDose(
            doseMg: referenceDoseMg,
            halfLifeHours: 5.0 * metabolism.halfLifeMultiplier
        )
        if let cutoff = Calendar.current.date(byAdding: .minute, value: -Int(hours * 60), to: sleep) {
            return "Next nudge: \(formatter.string(from: cutoff)) cutoff"
        }
    }
    return "All quiet — your next nudge will appear here."
}
