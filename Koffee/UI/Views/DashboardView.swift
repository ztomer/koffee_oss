import SwiftUI
import LiquidContainer

struct DashboardView: View {
    @ObservedObject var appState: AppState
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @ObservedObject var physicsEngine: SharedPhysicsEngine
    let window: NSWindow?

    @State private var caffeineAtBedtime: Double = 0
    @State private var bubbleStates: [BubbleState] = BubbleGenerator.generate(count: 30, width: 400, height: 300)
    @State private var lastWindowPos: CGPoint?
    @State private var trackedWindow: NSWindow?

    var safeLimit: Double {
        appState.safeCaffeineLimit
    }

    // Use single source of truth from AppState
    var fillRatio: Double {
        appState.currentCaffeineLevel / 400.0
    }

// Use single source of truth from AppState instead of recalculating
    var currentCaffeine: Double {
        appState.todayCaffeineTotal
    }

var pendingCaffeine: Double {
        appState.pendingPlanItemsByCompound("caffeine").reduce(0) { $0 + $1.doseMg }
    }

    var liquidConfiguration: LiquidContainerConfiguration {
        .coffee
    }

    var activeStimulantLoad: Double {
        let now = Date()

        var load: Double = 0
        let todayDoses = appState.dosesForDate(now)
        load += todayDoses.reduce(0) { $0 + $1.caffeineMg }

        let pendingCaffeine = appState.pendingPlanItemsTodayByCompound("caffeine")
        load += pendingCaffeine.reduce(0) { $0 + $1.doseMg }

        return load
    }

    var activeDepressantLoad: Double {
        let now = Date()

        var load: Double = 0
        let todaySupplements = appState.supplementsForDate(now)
        for log in todaySupplements {
            if let compound = NootropicCompound(rawValue: log.compoundName) {
                load += compound.optimalDoseMg * 0.2
            }
        }

        let pendingSupplements = appState.pendingNonCaffeineItemsToday()
        for item in pendingSupplements {
            if let compound = NootropicCompound(rawValue: item.compoundName) {
                load += compound.optimalDoseMg * 0.2
            }
        }

        return load
    }

    private var compositeDoses: [Dose] {
        // Use AppState method
        let todayDoses = appState.dosesForDate(Date())

        let actuals = todayDoses.map { dose in
            let compound = NootropicCompound(rawValue: dose.compoundUuid ?? "Caffeine") ?? .caffeine
            return Dose(time: dose.timestamp, amount: dose.caffeineMg, compound: compound, isPlanItem: false)
        }

// Get today's pending plan items
        let planDoses = appState.pendingPlanItemsToday

        let planDoseData = planDoses.map { item in
            let compound = NootropicCompound(rawValue: item.compoundUuid) ?? .caffeine
            return Dose(time: item.scheduledTime, amount: item.doseMg, compound: compound, isPlanItem: true)
        }

        var result = actuals
        result.append(contentsOf: planDoseData)

        return result.sorted { ($0.time ?? Date.distantPast) < ($1.time ?? Date.distantPast) }
    }

private var compositeSupplements: [NootropicCompound] {
        let now = Date()
        var compounds: Set<NootropicCompound> = []

        // Include ALL logged supplements for today
        let todaySupplements = appState.supplementsForDate(now)
        for log in todaySupplements {
            if let compound = NootropicCompound(rawValue: log.compoundName) {
                compounds.insert(compound)
            }
        }

        // Include ALL pending plan items for today
        let pendingSupplements = appState.pendingNonCaffeineItemsToday()
        for item in pendingSupplements {
            if let compound = NootropicCompound(rawValue: item.compoundName) {
                compounds.insert(compound)
            }
        }

        return Array(compounds)
    }

    private var topRecommendation: ActionableRecommendation? {
        guard let profile = appState.profile else { return nil }

        let optimizer = StackOptimizerEngine(goal: OptimizationGoal(rawValue: profile.optimizationGoal) ?? .balanced)

        let currentInterventions = appState.todayInterventions
        let hoursUntilBedtime = profile.sleepTime.timeIntervalSince(Date()) / 3600

        let recommendations = optimizer.generateRecommendations(
            activeCaffeineMg: caffeineAtBedtime,
            currentDayInterventions: currentInterventions,
            wakeTime: profile.wakeTime,
            sleepTime: profile.sleepTime,
            hydrationDeficitMl: 0,
            hoursUntilBedtime: hoursUntilBedtime,
            tolerance: ToleranceCycle(daysSinceReset: profile.toleranceDaysSinceReset, resetDaysRequired: profile.toleranceResetDaysRequired),
            biometrics: appState.todayBiometrics
        )

        return recommendations.min { $0.priority < $1.priority }
    }

    var body: some View {
        ZStack(alignment: .top) {
            LiquidContainerView(
                fillLevel: CGFloat(min(fillRatio, 1.0)),
                configuration: liquidConfiguration,
                physicsEngine: physicsEngine.engine,
                bubbleStates: bubbleStates
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        oracleBanner
                            .frame(maxWidth: .infinity)

                        biometricHUD
                    }
                    heroSection
                }
                .padding(16)
            }
            .background(.ultraThinMaterial)
        }
        .onAppear {
            debugLog("DashboardView onAppear - physicsEngine.engine.containerAccelX=\(physicsEngine.engine.containerAccelX)")
            updateCaffeineLevel()

            // Add ambient physics animation - tiny continuous waves
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                let randomForce = Double.random(in: -0.3...0.3)
                physicsEngine.engine.containerAccelX += randomForce
                debugLog("DashboardView: ambient physics slosh, accelX now: \(physicsEngine.engine.containerAccelX)")
            }
        }
        .onChange(of: appState.doses) { _, _ in
            updateCaffeineLevel()
        }
        .onChange(of: appState.supplementLogs) { _, _ in
            updateCaffeineLevel()
        }
        .onChange(of: appState.profile) { _, _ in
            updateCaffeineLevel()
        }
        .onChange(of: appState.profile?.stackCompounds) { _, _ in
            updateCaffeineLevel()
        }
        .onChange(of: appState.dailyPlanItems) { _, _ in
            updateCaffeineLevel()
        }
    }

    // MARK: - Oracle Banner

    private var oracleBanner: some View {
        Group {
            // Show tolerance alert first (highest priority warning)
            if let toleranceAlert = appState.toleranceAlert {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .frame(width: 40, height: 40)
                        .background(.yellow.opacity(0.2))
                        .clipShape(.circle)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Caffeine Tolerance Alert")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(toleranceAlert.message)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.15))
                )
            } else if let recommendation = topRecommendation {
                HStack(spacing: 12) {
                    Image(systemName: iconForRecommendationType(recommendation.type))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(iconColorForType(recommendation.type))
                        .frame(width: 40, height: 40)
                        .background(iconColorForType(recommendation.type).opacity(0.2))
                        .clipShape(.circle)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(recommendation.message)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Text("P\(recommendation.priority)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(iconColorForType(recommendation.type))
                        .clipShape(.rect(cornerRadius: 4))
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("All systems optimal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
    }

    // MARK: - Biometric HUD

    private var biometricHUD: some View {
        let largeSize: CGFloat = 80

        return LazyVGrid(columns: [
            GridItem(.fixed(largeSize)),
            GridItem(.fixed(largeSize))
        ], spacing: 12) {
            SleepGaugeView(score: appState.todayBiometrics?.sleepScore)
                .frame(width: largeSize, height: largeSize)

            BiometricWidget(
                title: "HRV",
                value: appState.todayBiometrics?.heartRateVariability.map { "\(Int($0))ms" } ?? "--",
                icon: "heart.fill",
                color: .red
            )
            .frame(width: largeSize, height: largeSize)

            MetabolicWidget(interventions: appState.todayInterventions)
                .frame(width: largeSize, height: largeSize)

            CaffeineMeterView(
                level: currentCaffeine,
                safeLimit: safeLimit
            )
            .frame(width: largeSize, height: largeSize)
        }
    }

    private func iconForRecommendationType(_ type: ActionableRecommendation.RecommendationType) -> String {
        switch type {
        case .hydrate: return "drop.fill"
        case .takeCompound: return "pill.fill"
        case .replaceCompound: return "arrow.triangle.2.circlepath"
        case .avoidCompound: return "exclamationmark.triangle.fill"
        case .caffeineCutoff: return "cup.and.saucer.fill"
        case .sleepPrep: return "moon.fill"
        case .exercise: return "figure.run"
        }
    }

    private func iconColorForType(_ type: ActionableRecommendation.RecommendationType) -> Color {
        switch type {
        case .hydrate: return .blue
        case .takeCompound: return .green
        case .replaceCompound: return .purple
        case .avoidCompound: return .red
        case .caffeineCutoff: return .orange
        case .sleepPrep: return .purple
        case .exercise: return .cyan
        }
    }

    private var sleepScoreColor: Color {
        guard let score = appState.todayBiometrics?.sleepScore else { return .gray }
        if score >= 85 { return .green }
        if score >= 70 { return .yellow }
        return .red
    }

    // MARK: - Hero Section (Chart)

    private var heroSection: some View {
        VStack(spacing: 8) {
            UnifiedNootropicChart(
                doses: compositeDoses,
                supplements: compositeSupplements,
                wakeTime: appState.profile?.wakeTime ?? Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!,
                sleepTime: appState.profile?.sleepTime ?? Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!,
                safeLimit: safeLimit
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }

    private func updateCaffeineLevel() {
        let doses = appState.todayDoses.map { Dose(time: $0.timestamp, amount: $0.caffeineMg) }
        let wakeTime = appState.profile?.wakeTime ?? Date()
        let sleepTime = appState.profile?.sleepTime ?? Date()
        caffeineAtBedtime = PharmacokineticEngine.calculateCaffeineAtBedtime(doses: doses, wakeTime: wakeTime, sleepTime: sleepTime)
    }
}

// MARK: - Biometric Widget

struct BiometricWidget: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(color)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}
