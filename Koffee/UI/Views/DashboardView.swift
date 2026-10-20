import SwiftUI
import LiquidContainer

// The dashboard's own view.
//
// The pieces around it were cut out along the seams that had their own reasons to exist:
//
//   DashboardOracleBanner.swift  the banner, a view that takes what it shows
//   DashboardCopy.swift          the oracle's sentences, as pure functions
//   DashboardWidgets.swift       the stat tiles
//   DashboardBubbles.swift       the bubble layout helpers
//
// The cut is by dependency, not by size: each of those can be read, changed and tested
// without the tank, the chart or the physics engine, which is what the 500-line cap was
// asking for.
struct DashboardView: View {
    @ObservedObject var appState: AppState
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @ObservedObject var physicsEngine: SharedPhysicsEngine
    let window: NSWindow?

    @State private var caffeineAtBedtime: Double = 0
    @State private var caffeineFreeAt: Date?
    @State private var bubbleStates: [BubbleState] = dashboardBubbles(count: 30, seed: RenderHarness.bubbleSeedWhenRendering)
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
        // A render draws one instant, so the liquid's timeline is paused for it: otherwise
        // `TimelineView(.animation)` steps the physics at 30fps and no two renders agree.
        var configuration = LiquidContainerConfiguration.coffee
        configuration.animates = !RenderHarness.isRendering
        return configuration
    }

    var activeStimulantLoad: Double {
        let now = DateHelper.now

        var load: Double = 0
        let todayDoses = appState.dosesForDate(now)

        // The ruled dose set (L4): a pending plan item whose cup was already logged
        // (dose id == plan item id) is one cup, not two.
        load += effectiveDoseSet(
            loggedDoses: todayDoses,
            pendingPlanItems: appState.pendingPlanItemsTodayByCompound("caffeine")
        ).reduce(0) { $0 + $1.amount }

        return load
    }

    private var compositeDoses: [Dose] {
        // The ruled dose set (L4) applies to the curve too: planned + logged,
        // deduplicated when the planned dose was already logged.
        effectiveDoseSet(
            loggedDoses: appState.dosesForDate(DateHelper.now),
            pendingPlanItems: appState.pendingPlanItemsToday
        )
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
            // A render is one instant of the dashboard, so the ambient slosh — a random nudge every
            // two seconds — is left out of it. Everything a screenshot shows is then the fixture's.
            guard !RenderHarness.isRendering else { return }
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
        DashboardOracleBanner(
            toleranceAlert: appState.toleranceAlert,
            title: bedtimeStatusTitle,
            icon: bedtimeStatusIcon,
            color: bedtimeStatusColor,
            subtitle: oracleSubtitle,
            forecast: caffeineFreeForecast
        )
    }

    /// The forecast line, when there is one. P1: it rides on the ruled dose set the
    /// chart draws (L4) and on the same decay model, so it is the curve's own answer
    /// rather than a second caffeine number.
    private var caffeineFreeForecast: String? {
        caffeineFreeLine(freeAt: caffeineFreeAt, now: DateHelper.now)
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
                wakeTime: appState.profile?.wakeTime ?? Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: DateHelper.now)!,
                sleepTime: appState.profile?.sleepTime ?? Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: DateHelper.now)!,
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
        // The banner passes the funnel the ruled dose set (L4): planned + logged,
        // deduplicated — the funnel takes the composite set, so this number and the
        // chart's stat row are the same projection of the same day.
        let ruledSet = effectiveDoseSet(
            loggedDoses: appState.todayDoses,
            pendingPlanItems: appState.pendingPlanItemsToday
        ).compactMap { dose -> (Date, Double)? in
            guard let time = dose.time else { return nil }
            return (time, dose.amount)
        }
        let wakeTime = appState.profile?.wakeTime ?? DateHelper.now
        let sleepTime = appState.profile?.sleepTime ?? DateHelper.now
        let metabolism = MetabolismRate(swiftDataValue: appState.profile?.metabolismRate ?? "") ?? .medium
        caffeineAtBedtime = projectBedtimeCaffeine(doses: ruledSet, wakeTime: wakeTime, sleepTime: sleepTime, metabolism: metabolism)
        // P1: the same ruled set, through the same decay model -- so the forecast cannot
        // disagree with the curve the reader is looking at.
        caffeineFreeAt = CaffeinePK.caffeineFreeAt(doses: ruledSet, metabolism: metabolism)
    }

    private func rescaleBubbles(force: Bool = false) {
        let bucket = Int((min(max(fillRatio, 0), 1) * 10).rounded())
        guard force || bucket != lastBubbleBucket else { return }
        lastBubbleBucket = bucket
        bubbleStates = dashboardBubbles(count: bubbleCount(forFillRatio: fillRatio), seed: RenderHarness.bubbleSeedWhenRendering)
    }
}
