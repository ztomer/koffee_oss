import SwiftUI
import LiquidContainer

struct SettingsView: View {
    @ObservedObject var appState: AppState

    @State private var weightText: String = ""
    @State private var heightValue: Double = 175
    @State private var birthdate: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var selectedSensitivity: Sensitivity = .medium
    @State private var selectedMetabolism: MetabolismRate = .medium
    @State private var wakeTime: Date = Date()
    @State private var sleepTime: Date = Date()
    @State private var selectedGoal: OptimizationGoal = .balanced

    @State private var editingWeight: Bool = false
    @State private var editingHeight: Bool = false
    @State private var editingAge: Bool = false

    private var computedAge: Int {
        Calendar.current.dateComponents([.year], from: birthdate, to: Date()).year ?? 30
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                characterHeader
                statPods
                engineBlock
                circadianBlock
                toleranceBlock
                timelineBlock
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { loadSettings() }
    }

    private func loadSettings() {
        guard let profile = appState.profile else { return }
        weightText = String(format: "%.0f", profile.weight)
        heightValue = profile.heightCm
        selectedSensitivity = Sensitivity(swiftDataValue: profile.sensitivity) ?? .medium
        selectedMetabolism = MetabolismRate(swiftDataValue: profile.metabolismRate) ?? .medium
        wakeTime = profile.wakeTime
        sleepTime = profile.sleepTime
        if let goal = OptimizationGoal(rawValue: profile.optimizationGoal) {
            selectedGoal = goal
        }
        if profile.age > 0 {
            birthdate = Calendar.current.date(byAdding: .year, value: -profile.age, to: Date()) ?? Date()
        }
    }

    private func saveProfile(_ update: (inout UserProfileModel) -> Void) {
        guard var profile = appState.profile else { return }
        update(&profile)
        profile.updatedAt = Date()
        try? appState.saveProfile(profile)
    }

    // MARK: - Character Header

    private var characterHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(KoffeeColor.orange.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(KoffeeColor.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("CAFFEINIST")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Level 5 Optimizer")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("XP")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("12,450")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Stat Pods (Attributes Block)

    private var statPods: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("ATTRIBUTES", icon: "figure.stand")

            HStack(spacing: 12) {
                StatPod(
                    value: Binding(
                        get: { weightText.isEmpty ? "—" : weightText },
                        set: { weightText = $0 }
                    ),
                    label: "kg",
                    isEditing: $editingWeight,
                    onSave: { newValue in
                        if let w = Double(newValue), w > 0 {
                            saveProfile { $0.weight = w }
                        }
                    }
                )

                StatPod(
                    value: Binding(
                        get: { String(format: "%.0f", heightValue) },
                        set: { heightValue = Double($0) ?? 175 }
                    ),
                    label: "cm",
                    isEditing: $editingHeight,
                    onSave: { _ in
                        saveProfile { $0.heightCm = heightValue }
                    }
                )

                StatPod(
                    value: Binding(
                        get: { "\(computedAge)" },
                        set: { _ in }
                    ),
                    label: "years",
                    isEditing: $editingAge,
                    onSave: { _ in
                        saveProfile { $0.age = computedAge }
                    }
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Engine Block (Metabolism & Sensitivity)

    private var engineBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("THE ENGINE", icon: "gearshape.2.fill")

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CAFFEINE SENSITIVITY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(Sensitivity.allCases) { sens in
                            SkillPill(
                                title: sens.displayName,
                                isSelected: selectedSensitivity == sens,
                                color: KoffeeColor.orange
                            ) {
                                selectedSensitivity = sens
                                saveProfile { $0.sensitivity = sens.swiftDataValue }
                            }
                        }
                    }
                }

                Divider()
                    .background(Color(nsColor: .separatorColor))

                VStack(alignment: .leading, spacing: 8) {
                    Text("OPTIMIZATION GOAL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(OptimizationGoal.allCases) { goal in
                            let isSelected = selectedGoal == goal
                            let color: Color = goal == .deepSleep ? .purple : .blue
                            SkillPill(
                                title: goal.rawValue,
                                isSelected: isSelected,
                                color: color
                            ) {
                                selectedGoal = goal
                                saveProfile { profile in
                                    profile.optimizationGoal = goal.rawValue
                                }
                            }
                        }
                    }
                }

                Divider()
                    .background(Color(nsColor: .separatorColor))

                VStack(alignment: .leading, spacing: 8) {
                    Text("METABOLISM RATE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(MetabolismRate.allCases) { rate in
                            SkillPill(
                                title: rate.displayName,
                                isSelected: selectedMetabolism == rate,
                                color: KoffeeColor.green
                            ) {
                                selectedMetabolism = rate
                                saveProfile { $0.metabolismRate = rate.swiftDataValue }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Circadian Block

    private var circadianBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("CIRCADIAN PARAMETERS", icon: "clock.fill")

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WAKE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    KoffeeTimeStepper(time: $wakeTime)
                        .onChange(of: wakeTime) { _, newValue in
                            saveProfile { $0.wakeTime = newValue }
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("SLEEP")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    KoffeeTimeStepper(time: $sleepTime)
                        .onChange(of: sleepTime) { _, newValue in
                            saveProfile { $0.sleepTime = newValue }
                        }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Tolerance Block

    private var toleranceBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("TOLERANCE CYCLE", icon: "arrow.triangle.2.circlepath")

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DAYS SINCE RESET")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button {
                            saveProfile { p in
                                if p.toleranceDaysSinceReset > 0 {
                                    p.toleranceDaysSinceReset -= 1
                                }
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(KoffeeColor.orange)
                        }
                        .buttonStyle(.plain)

                        Text("\((appState.profile?.toleranceDaysSinceReset) ?? 0)")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(KoffeeColor.orange)

                        Text("/ \((appState.profile?.toleranceResetDaysRequired) ?? 14)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Button {
                            saveProfile { p in
                                if p.toleranceDaysSinceReset < p.toleranceResetDaysRequired {
                                    p.toleranceDaysSinceReset += 1
                                }
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(KoffeeColor.green)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                let shouldReset = appState.profile.map {
                    ToleranceCycle(daysSinceReset: $0.toleranceDaysSinceReset,
                                   resetDaysRequired: $0.toleranceResetDaysRequired).shouldReset
                } ?? false
                if shouldReset {
                    VStack(alignment: .center, spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(KoffeeColor.red)
                        Text("RESET")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(KoffeeColor.red)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(KoffeeColor.red.opacity(0.15))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Timeline Block

    private var timelineBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("TIMELINE", icon: "calendar")

            Toggle(isOn: Binding(
                get: { appState.profile?.autoRefreshPlan ?? true },
                set: { newValue in
                    saveProfile { $0.autoRefreshPlan = newValue }
                    if newValue {
                        try? appState.refreshDailyPlan()
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AUTO-REFRESH PLAN")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Update daily plan when stack changes")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: KoffeeColor.orange))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Helper Views

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KoffeeColor.orange)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
