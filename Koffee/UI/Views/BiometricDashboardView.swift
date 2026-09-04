import SwiftUI

struct BiometricDashboardView: View {
    @ObservedObject var appState: AppState

    @State private var weightText: String = ""
    @State private var birthdate: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var heightValue: Double = 175
    @State private var selectedSex: BiologicalSex = .male
    @State private var selectedGoal: OptimizationGoal = .balanced
    @State private var selectedMetabolism: MetabolismRate = .medium
    @State private var selectedSensitivity: Sensitivity = .medium

    @State private var editingField: String?

    var computedAge: Int {
        Calendar.current.dateComponents([.year], from: birthdate, to: Date()).year ?? 30
    }

    var volumeOfDistribution: Double {
        let age = computedAge
        let height = appState.profile?.heightCm ?? 175
        let weight = appState.profile?.weight ?? 70.0
        let sex = appState.profile?.biologicalSex ?? "male"

        if sex.lowercased() == "male" {
            return 2.447 - 0.09516 * Double(age) + 0.1074 * height + 0.3362 * weight
        } else {
            return -2.097 + 0.1069 * height + 0.2466 * weight
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profile Settings")
                            .font(.system(size: 24, weight: .bold))
                        Text("Your personal metrics and preferences")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Profile Header Card
                profileHeaderCard

                // Main Content: Three Columns
                HStack(alignment: .top, spacing: 16) {
                    metabolismColumn
                    neurologyColumn
                    scheduleAndGoalsColumn
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadFromProfile()
        }
    }

    // MARK: - Profile Header

    private var profileHeaderCard: some View {
        HStack(spacing: 16) {
            // User Icon
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 70, height: 70)
                Image(systemName: "person.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }

            // Interactive Stat Pods
            HStack(spacing: 10) {
                statPod(value: "\(Int(appState.profile?.weight ?? 70))", unit: "kg", isEditing: editingField == "weight") {
                    editingField = "weight"
                }
                .popover(isPresented: Binding(
                    get: { editingField == "weight" },
                    set: { if !$0 { editingField = nil } }
                )) {
                    VStack(spacing: 10) {
                        Text("Body Weight (kg)")
                            .font(.headline)
                        TextField("Weight", value: Binding(
                            get: { Double(weightText) ?? 70 },
                            set: { weightText = String(format: "%.0f", $0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        Button("Save") {
                            saveWeight(weightText)
                            editingField = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding(20)
                }

                statPod(value: "\(Int(appState.profile?.heightCm ?? 175))", unit: "cm", isEditing: editingField == "height") {
                    editingField = "height"
                }
                .popover(isPresented: Binding(
                    get: { editingField == "height" },
                    set: { if !$0 { editingField = nil } }
                )) {
                    VStack(spacing: 10) {
                        Text("Height (cm)")
                            .font(.headline)
                        TextField("Height", value: $heightValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Button("Save") {
                            updateHeight(String(format: "%.0f", heightValue))
                            editingField = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding(20)
                }

                statPod(value: birthdateString, unit: "", isEditing: editingField == "birthdate") {
                    editingField = "birthdate"
                }
                .popover(isPresented: Binding(
                    get: { editingField == "birthdate" },
                    set: { if !$0 { editingField = nil } }
                )) {
                    VStack(spacing: 10) {
                        Text("Birthdate")
                            .font(.headline)
                        DatePicker("", selection: $birthdate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                        Button("Save") {
                            saveBirthdate()
                            editingField = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding(20)
                }

                statPod(value: "\(computedAge)", unit: "years", isEditing: false) {
                }
                .allowsHitTesting(false)
            }

            Spacer()

            // Core Metric Circle
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Circle()
                        .stroke(Color.orange, lineWidth: 3)
                        .frame(width: 80, height: 80)
                    VStack(spacing: 2) {
                        Text("\(Int(volumeOfDistribution))")
                            .font(.system(size: 22, weight: .bold))
                        Text("L")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.orange)
                }
                Text("Total Body Water")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var birthdateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: birthdate)
    }

    private func statPod(value: String, unit: String, isEditing: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isEditing ? .orange : .primary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isEditing ? Color.orange.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .clipShape(.rect(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEditing ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func saveWeight(_ value: String) {
        if let w = Double(value), w > 0 {
            saveProfile { $0.weight = w }
        }
    }

    private func updateHeight(_ value: String) {
        if let h = Double(value) {
            saveProfile { $0.heightCm = h }
        }
    }

    private func saveBirthdate() {
        let age = Calendar.current.dateComponents([.year], from: birthdate, to: Date()).year ?? 30
        saveProfile { profile in
            profile.age = age
        }
    }

    // MARK: - Metabolism Column

    private var metabolismColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Block Title
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("Caffeine Processing Speed")
                    .font(.system(size: 12, weight: .bold))
            }

            // Metabolic Enzyme Profile Label
            VStack(alignment: .leading, spacing: 4) {
                Text("Metabolic Enzyme Profile (CYP1A2)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                // Options: Slow, Medium, Fast
                HStack(spacing: 0) {
                    ForEach(MetabolismRate.allCases) { rate in
                        Button {
                            selectedMetabolism = rate
                            saveProfile { $0.metabolismRate = rate.swiftDataValue }
                        } label: {
                            Text(rate.displayName)
                                .font(.system(size: 10, weight: .semibold))
                                .frame(width: 55)
                                .padding(.vertical, 5)
                                .background(selectedMetabolism == rate ? Color.orange : Color(nsColor: .controlBackgroundColor))
                                .foregroundStyle(selectedMetabolism == rate ? .white : .primary)
                                .clipShape(.rect(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        if rate != MetabolismRate.allCases.last {
                            Color.clear.frame(width: 1)
                        }
                    }
                }
            }

            Spacer()

            // Elimination Half-life at bottom
            HStack {
                Text("Elimination Half-life")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(selectedMetabolism.halfLifeMultiplier * 5.0, specifier: "%.2f") hours")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
        }
        .padding(14)
        .frame(minWidth: 160)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    // MARK: - Neurology Column

    private var neurologyColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Block Title
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple)
                Text("Brain & Nervous System Sensitivity")
                    .font(.system(size: 12, weight: .bold))
            }

            // Stimulant Sensitivity Label
            VStack(alignment: .leading, spacing: 4) {
                Text("Stimulant Sensitivity Level")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                // Options: Low, Medium, High
                HStack(spacing: 0) {
                    ForEach(Sensitivity.allCases) { sens in
                        Button {
                            selectedSensitivity = sens
                            saveProfile { $0.sensitivity = sens.swiftDataValue }
                        } label: {
                            Text(sens.displayName)
                                .font(.system(size: 10, weight: .semibold))
                                .frame(width: 55)
                                .padding(.vertical, 5)
                                .background(selectedSensitivity == sens ? Color.orange : Color(nsColor: .controlBackgroundColor))
                                .foregroundStyle(selectedSensitivity == sens ? .white : .primary)
                                .clipShape(.rect(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        if sens != Sensitivity.allCases.last {
                            Color.clear.frame(width: 1)
                        }
                    }
                }
            }

            // Safe Amount at Bedtime
            HStack {
                Text("Safe Amount at Bedtime")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(Sensitivity(swiftDataValue: appState.profile?.sensitivity ?? "medium")?.safeCaffeineAtBedtime ?? 50))mg")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }

            // Caffeine Tolerance Progress Bar
            let profile = appState.profile
            let tolerance = ToleranceCycle(
                daysSinceReset: profile?.toleranceDaysSinceReset ?? 0,
                resetDaysRequired: profile?.toleranceResetDaysRequired ?? 14)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Caffeine Tolerance Reset Status")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(tolerance.daysSinceReset) of \(tolerance.resetDaysRequired) days")
                        .font(.system(size: 10, weight: .semibold))
                }
                ProgressView(value: Double(tolerance.daysSinceReset), total: Double(tolerance.resetDaysRequired))
                    .tint(.orange)
            }
        }
        .padding(14)
        .frame(minWidth: 160)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    // MARK: - Schedule & Goals Column

    private var scheduleAndGoalsColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Daily Activity Windows Block
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.orange)
                    Text("Daily Activity Windows")
                        .font(.system(size: 12, weight: .bold))
                }

                HStack(spacing: 20) {
                    // Wake Up Time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wake Up Time")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        timePicker(time: Binding(
                            get: { appState.profile?.wakeTime ?? Date() },
                            set: { newTime in saveProfile { $0.wakeTime = newTime } }
                        ))
                    }

                    // Sleep Time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sleep Time")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        timePicker(time: Binding(
                            get: { appState.profile?.sleepTime ?? Date() },
                            set: { newTime in saveProfile { $0.sleepTime = newTime } }
                        ))
                    }
                }
            }

            // Primary Performance Goal Block
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(.green)
                    Text("Primary Performance Goal")
                        .font(.system(size: 12, weight: .bold))
                }

                VStack(spacing: 4) {
                    ForEach(OptimizationGoal.allCases) { goal in
                        Button {
                            selectedGoal = goal
                            saveProfile { $0.optimizationGoal = goal.rawValue }
                        } label: {
                            HStack {
                                Text(goal.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                                Spacer()
                                if selectedGoal == goal {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.orange)
                                }
                            }
                            .padding(8)
                            .background(selectedGoal == goal ? Color.orange.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                            .clipShape(.rect(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .frame(minWidth: 160)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func timePicker(time: Binding<Date>) -> some View {
        HStack(spacing: 4) {
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.field)
                .frame(width: 70)
        }
    }

    // MARK: - Helpers

    private func loadFromProfile() {
        guard let profile = appState.profile else { return }
        weightText = String(format: "%.0f", profile.weight)
        heightValue = profile.heightCm
        selectedSex = BiologicalSex(rawValue: profile.biologicalSex) ?? .male
        if profile.age > 0 {
            birthdate = Calendar.current.date(byAdding: .year, value: -profile.age, to: Date()) ?? Date()
        }
        if let goal = OptimizationGoal(rawValue: profile.optimizationGoal) {
            selectedGoal = goal
        }
        selectedMetabolism = MetabolismRate(swiftDataValue: profile.metabolismRate) ?? .medium
        selectedSensitivity = Sensitivity(swiftDataValue: profile.sensitivity) ?? .medium
    }

    private func saveProfile(_ update: (inout UserProfileModel) -> Void) {
        guard var profile = appState.profile else { return }
        update(&profile)
        profile.updatedAt = Date()
        try? appState.saveProfile(profile)
    }
}
