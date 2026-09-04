import SwiftUI

struct StackView: View {
    @ObservedObject var appState: AppState
    @State private var selectedStack: Set<NootropicCompound> = []

    private var activeStack: Set<NootropicCompound> {
        Set(appState.profile?.stackCompounds.compactMap { NootropicCompound(rawValue: $0) } ?? [])
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                stackToggleSection
                if !activeStack.isEmpty {
                    stackExplanationSection
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { selectedStack = activeStack }
        .onChange(of: appState.profile?.stackCompounds) { _, _ in
            selectedStack = activeStack
        }
        .onChange(of: selectedStack) { _, newValue in
            if newValue != activeStack, var profile = appState.profile {
                profile.stackCompounds = Array(newValue.map { $0.rawValue })
                profile.updatedAt = Date()
                try? appState.saveProfile(profile)
            }
        }
    }

    private var optimizationsCard: some View {
        let notifications = engineNotifications

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(.purple)
                Text("OPTIMIZATIONS").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                Spacer()

                if !notifications.isEmpty {
                    Button {
                        applyOptimizations()
                    } label: {
                        Text("Apply")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                }
            }

            if notifications.isEmpty {
                Text("No alerts - you're on track!").font(.system(size: 11)).foregroundStyle(.secondary)
            } else {
                ForEach(notifications, id: \.message) { item in
                    HStack(spacing: 8) {
                        Circle().fill(item.shouldWarn ? .orange : .green).frame(width: 6, height: 6)
                        Text(item.message).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.25))
        )
    }

    private func applyOptimizations() {
        appState.applyOptimizations()
    }

    private var engineNotifications: [NotificationItem] {
        guard let profile = appState.profile else { return [] }

        let optimizer = StackOptimizerEngine(goal: OptimizationGoal(rawValue: profile.optimizationGoal) ?? .balanced)

        let currentInterventions = appState.todayInterventions
        let hoursUntilBedtime = profile.sleepTime.timeIntervalSince(Date()) / 3600

        let recommendations = optimizer.generateRecommendations(
            activeCaffeineMg: 0,
            currentDayInterventions: currentInterventions,
            wakeTime: profile.wakeTime,
            sleepTime: profile.sleepTime,
            hydrationDeficitMl: 0,
            hoursUntilBedtime: hoursUntilBedtime,
            tolerance: ToleranceCycle(daysSinceReset: profile.toleranceDaysSinceReset, resetDaysRequired: profile.toleranceResetDaysRequired),
            biometrics: appState.todayBiometrics
        )

        return recommendations.map { rec in
            NotificationItem(
                type: .excessiveCaffeine,
                message: "\(rec.type.rawValue) \(rec.title): \(rec.message)",
                timeUntil: rec.scheduledTime?.timeIntervalSince(Date()),
                shouldWarn: rec.priority <= 2
            )
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nootropic Stack").font(.system(size: 24, weight: .bold))
                Text("Optimize your cognitive enhancement").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            optimizationToggle
            scheduleDisplay
            applyToTodayButton
        }
    }

    private var applyToTodayButton: some View {
        Button {
            try? appState.refreshDailyPlan()
        } label: {
            Label("Apply to Today", systemImage: "arrow.right.circle.fill")
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.bordered)
        .help("Apply stack changes to today's timeline immediately")
    }

    private var optimizationToggle: some View {
        let goal = OptimizationGoal(rawValue: appState.profile?.optimizationGoal ?? "Balanced") ?? .balanced

        return HStack(spacing: 0) {
            ForEach(OptimizationGoal.allCases) { optGoal in
                Button {
                    if var profile = appState.profile {
                        profile.optimizationGoal = optGoal.rawValue
                        profile.updatedAt = Date()
                        try? appState.saveProfile(profile)
                    }
                    recalculateStackTiming()
                } label: {
                    Image(systemName: optGoal.icon)
                        .font(.system(size: 14))
                        .foregroundColor(goal == optGoal ? .white : .secondary)
                        .frame(width: 36, height: 28)
                        .background(goal == optGoal ? Color.orange : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(.capsule)
    }

    private var scheduleDisplay: some View {
        guard let profile = appState.profile else { return AnyView(EmptyView()) }
        return AnyView(HStack(spacing: 8) {
            Image(systemName: "clock").font(.system(size: 12))
            EditableTimePicker(selection: Binding(
                get: { profile.wakeTime },
                set: { updateTime(field: \.wakeTime, to: $0) }
            ))
            Text("-").foregroundStyle(.secondary)
            EditableTimePicker(selection: Binding(
                get: { profile.sleepTime },
                set: { updateTime(field: \.sleepTime, to: $0) }
            ))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(.capsule))
    }

    private func updateTime(field: WritableKeyPath<UserProfileModel, Date>, to newValue: Date) {
        guard var profile = appState.profile else { return }
        profile[keyPath: field] = newValue
        profile.updatedAt = Date()
        try? appState.saveProfile(profile)
        recalculateStackTiming()
    }

    private func recalculateStackTiming() {}

    private var stackToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Compounds").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
            HStack(alignment: .top, spacing: 6) {
                ForEach(NootropicCompound.allCases) { compound in
                    StackCompoundButton(compound: compound, isSelected: selectedStack.contains(compound)) {
                        if selectedStack.contains(compound) {
                            selectedStack.remove(compound)
                        } else {
                            selectedStack.insert(compound)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16).background(.ultraThinMaterial).clipShape(.rect(cornerRadius: 16))
    }

    private var stackExplanationSection: some View {
        let referenceTime = appState.profile?.wakeTime ?? Date()

        return VStack(alignment: .leading, spacing: 16) {
            Text("Your Stack Explained").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)

            VStack(spacing: 8) {
                ForEach(Array(activeStack).sorted { $0.recommendedTimingMinutes < $1.recommendedTimingMinutes }, id: \.rawValue) { compound in
                    let offset = compound.recommendedTimingMinutes
                    let recommendedTime = referenceTime.addingTimeInterval(offset * 60)

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle().fill(colorForCompound(compound.rawValue)).frame(width: 8, height: 8)
                                Text(compound.rawValue).font(.system(size: 12, weight: .semibold))
                                Text("\(Int(compound.optimalDoseMg))mg").font(.system(size: 10)).foregroundStyle(.secondary)
                            }

                            Text(compound.intendedPurpose).font(.system(size: 11)).foregroundStyle(.secondary)
                            Text(compound.mechanismOfAction).font(.system(size: 10)).foregroundStyle(.secondary)

                            if compound.hydrationOffsetMl > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "drop.fill").font(.system(size: 9)).foregroundStyle(.blue)
                                    Text("Requires +\(Int(compound.hydrationOffsetMl))ml water").font(.system(size: 9)).foregroundStyle(.blue)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Take at")
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                            Text(formatTime(recommendedTime))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(colorForCompound(compound.rawValue))
                            Text(offset >= 0 ? "\(Int(offset))min after coffee" : "\(Int(abs(offset)))min before coffee")
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(colorForCompound(compound.rawValue).opacity(0.15))
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .padding(10).background(colorForCompound(compound.rawValue).opacity(0.1)).clipShape(.rect(cornerRadius: 8))
                }
            }

            Divider()
            stackInteractionsSection
        }
    }

    private var stackInteractionsSection: some View {
        let interactionModel = NootropicInteractionModel(compounds: Array(selectedStack), caffeineDoseMg: 100)
        let interactions = interactionModel.activeInteractions

        return VStack(alignment: .leading, spacing: 8) {
            Text("Stack Interactions").font(.system(size: 12, weight: .bold)).foregroundStyle(.orange)

            if !interactions.isEmpty {
                ForEach(interactions, id: \.compound) { interaction in
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(interaction.description)
                                .font(.system(size: 11))
                                .foregroundStyle(.primary)
                            Text("+\(String(format: "%.1f", interaction.extensionHours))h effect duration")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if selectedStack.contains(.lTheanine) && selectedStack.contains(.creatine) {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pro Tip").font(.system(size: 11, weight: .semibold)).foregroundStyle(.blue)
                    Text("Creatine + L-Theanine: Cognitive endurance + calm focus. "
                         + "Take together for sustained mental performance.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }

            if selectedStack.contains(.lTheanine) && !selectedStack.contains(.creatine) {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Consider Adding").font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange)
                    Text("Creatine (5g): Complements L-Theanine for enhanced cognitive "
                         + "endurance during long focus sessions.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }

            Divider()
            optimizationsCard
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
