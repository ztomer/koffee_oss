import SwiftUI
import LiquidContainer

struct DashboardView: View {
    @ObservedObject var appState: AppState
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @ObservedObject var physicsEngine: SharedPhysicsEngine
    let window: NSWindow?

    @State private var caffeineAtBedtime: Double = 0
    @State private var bubbleStates: [BubbleState] = BubbleGenerator.generate(count: 30, width: 400, height: 300)
    @State private var lastDoseCount: Int = 0
    @State private var lastBubbleBucket: Int = -1
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

    private var compositeDoses: [Dose] {
        // Use AppState method
        let todayDoses = appState.dosesForDate(Date())

        let actuals = todayDoses.map { dose in
            Dose(time: dose.timestamp, amount: dose.caffeineMg, compound: .caffeine, isPlanItem: false)
        }

// Get today's pending plan items
        let planDoses = appState.pendingPlanItemsToday

        let planDoseData = planDoses.map { item in
            Dose(time: item.scheduledTime, amount: item.doseMg, compound: .caffeine, isPlanItem: true)
        }

        var result = actuals
        result.append(contentsOf: planDoseData)

        return result.sorted { ($0.time ?? Date.distantPast) < ($1.time ?? Date.distantPast) }
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

                        caffeineHUD
                    }
                    heroSection
                }
                .padding(16)
            }
        }
        .onAppear {
            debugLog("DashboardView onAppear - physicsEngine.engine.containerAccelX=\(physicsEngine.engine.containerAccelX)")
            updateCaffeineLevel()
            lastDoseCount = appState.doses.count
            rescaleBubbles(force: true)
        }
        .task {
            // Ambient physics: tiny continuous waves. A task, not a repeating Timer: it runs on the
            // main actor that owns this state, and ends when the view goes away. The Timer it
            // replaces mutated main-actor state from a Sendable closure, and a new one was started
            // on every appearance and never stopped.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                let randomForce = Double.random(in: -0.3...0.3)
                physicsEngine.engine.containerAccelX += randomForce
                debugLog("DashboardView: ambient physics slosh, accelX now: \(physicsEngine.engine.containerAccelX)")
            }
        }
        .onChange(of: appState.doses.count) { _, newCount in
            if newCount > lastDoseCount {
                physicsEngine.engine.containerAccelX += 2.0
            }
            lastDoseCount = newCount
            rescaleBubbles()
        }
        .onChange(of: fillRatio) { _, _ in
            rescaleBubbles()
        }
        .onChange(of: appState.doses) { _, _ in
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
            } else {
                HStack(spacing: 12) {
                    Image(systemName: bedtimeStatusIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(bedtimeStatusColor)
                        .frame(width: 40, height: 40)
                        .background(bedtimeStatusColor.opacity(0.2))
                        .clipShape(.circle)
                        .symbolEffect(.bounce, value: bedtimeStatusTitle)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(bedtimeStatusTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(oracleSubtitle)
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
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                )
            }
        }
    }

    // MARK: - Caffeine HUD

    private var caffeineHUD: some View {
        let largeSize: CGFloat = 80

        return LazyVGrid(columns: [
            GridItem(.fixed(largeSize)),
            GridItem(.fixed(largeSize))
        ], spacing: 12) {
            CaffeineMeterView(
                level: currentCaffeine,
                safeLimit: appState.dailyCaffeineLimit
            )
            .frame(width: largeSize, height: largeSize)

            CaffeineStatWidget(
                title: "BEDTIME",
                value: "\(Int(caffeineAtBedtime))mg",
                icon: "moon.fill",
                color: bedtimeStatusColor
            )
            .frame(width: largeSize, height: largeSize)
        }
    }

    private var bedtimeStatusTitle: String {
        caffeineAtBedtime <= safeLimit * 0.5 ? "Sleep ready" : (caffeineAtBedtime <= safeLimit ? "Monitor intake" : "Over bedtime limit")
    }

    private var bedtimeStatusIcon: String {
        caffeineAtBedtime <= safeLimit * 0.5 ? "moon.fill" : (caffeineAtBedtime <= safeLimit ? "eye.fill" : "exclamationmark.triangle.fill")
    }

    private var bedtimeStatusColor: Color {
        caffeineAtBedtime <= safeLimit * 0.5 ? .green : (caffeineAtBedtime <= safeLimit ? .yellow : .red)
    }

    private var oracleSubtitle: String {
        oracleLine(
            bedtimeMg: caffeineAtBedtime,
            limit: safeLimit,
            thresholdName: currentSensitivity.bedtimeThresholdName
        )
    }

    /// The reader's own sensitivity setting, so the bedtime sentence can name
    /// whether its threshold is the sourced figure or their stricter choice.
    private var currentSensitivity: Sensitivity {
        Sensitivity(swiftDataValue: appState.profile?.sensitivity ?? "") ?? .medium
    }

    // MARK: - Hero Section (Chart)

    private var heroSection: some View {
        VStack(spacing: 8) {
            CaffeineTimelineChart(
                doses: compositeDoses,
                wakeTime: appState.profile?.wakeTime ?? Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!,
                sleepTime: appState.profile?.sleepTime ?? Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!,
                safeLimit: safeLimit,
                metabolism: MetabolismRate(swiftDataValue: appState.profile?.metabolismRate ?? "") ?? .medium
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
        let doses = appState.todayDoses.map { ($0.timestamp, $0.caffeineMg) }
        let wakeTime = appState.profile?.wakeTime ?? Date()
        let sleepTime = appState.profile?.sleepTime ?? Date()
        let metabolism = MetabolismRate(swiftDataValue: appState.profile?.metabolismRate ?? "") ?? .medium
        caffeineAtBedtime = projectBedtimeCaffeine(doses: doses, wakeTime: wakeTime, sleepTime: sleepTime, metabolism: metabolism)
    }

    private func rescaleBubbles(force: Bool = false) {
        let bucket = Int((min(max(fillRatio, 0), 1) * 10).rounded())
        guard force || bucket != lastBubbleBucket else { return }
        lastBubbleBucket = bucket
        bubbleStates = BubbleGenerator.generate(count: bubbleCount(forFillRatio: fillRatio), width: 400, height: 300)
    }
}

// MARK: - Oracle copy (pure, testable)
/// Per-state oracle line. Numbers stay honest: every state names the bedtime mg.
func oracleLine(bedtimeMg: Double, limit: Double, thresholdName: String) -> String {
    let mg = Int(bedtimeMg)
    if bedtimeMg <= limit * 0.5 {
        return "Thanks for keeping it early — \(mg)mg at bedtime."
    } else if bedtimeMg <= limit {
        return "Still wired at \(mg)mg by bedtime — easy on the next cup."
    } else {
        // K4. "over the 50mg limit" read as evidence the app had measured. Only
        // the 100 mg figure is sourced; 50 and 25 are the reader's own stricter
        // choice, and the sentence now says so rather than letting a convention
        // pass as a finding.
        return "Put the pot down — \(mg)mg at bedtime, over \(thresholdName)."
    }
}

/// Idle bubble count scales with fill ratio using the existing generator.
/// Pure for testing: 20 empty … 40 full.
func bubbleCount(forFillRatio ratio: Double) -> Int {
    let clamped = min(max(ratio, 0), 1)
    return 20 + Int((clamped * 20).rounded())
}

// MARK: - Stat Widget

struct CaffeineStatWidget: View {
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
