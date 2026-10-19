import SwiftUI
import LiquidContainer

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

                        // P1: the forecast. It rides on the ruled dose set the chart draws
                        // (L4) and on the same decay model, so it is the curve's own answer
                        // rather than a second caffeine number.
                        if let forecast = caffeineFreeLine(freeAt: caffeineFreeAt, now: DateHelper.now) {
                            Text(forecast)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
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

/// The forecast line under the oracle sentence: when the day's modelled caffeine falls
/// under the threshold the app calls "none" (P1).
///
/// The line NAMES the threshold, because "caffeine-free" is only ever true of a line the
/// app chose — 1 mg, its own reporting resolution. A sentence that said "caffeine-free"
/// with no line would be a claim the reader has no way to check, which is the shape K4
/// found and closed.
///
/// The day is named too ("today", "tomorrow", or the date): a clock time without its day
/// is a forecast the reader has to guess about, and guessing is how "06:09" becomes
/// "six in the morning".
///
/// - Returns: `nil` when there is nothing to forecast (no doses) — a line with no fact
///   behind it is worse than no line.
func caffeineFreeLine(
    freeAt: Date?,
    now: Date,
    calendar: Calendar = DateHelper.calendar
) -> String? {
    guard let freeAt else { return nil }
    // Printed, so it must not be rounded into a DIFFERENT number: casting the threshold to
    // an Int would print "under 0mg" for anything under 1 mg — a sentence that lies about
    // the line the derivation uses.
    let threshold = String(format: "%g", CaffeineConstants.caffeineFreeThresholdMg)
    guard freeAt > now else {
        return "Caffeine-free now (under \(threshold)mg)."
    }
    let time = clockTime(freeAt, calendar: calendar)
    let day = dayLabel(freeAt, now: now, calendar: calendar)
    return "Caffeine-free at \(time) \(day) (under \(threshold)mg)."
}

/// "HH:mm" in the reader's own zone — the app's clock format (the chart's stat row uses it).
private func clockTime(_ date: Date, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.timeZone = calendar.timeZone
    return formatter.string(from: date)
}

/// How the forecast names the day the instant falls on.
private func dayLabel(_ date: Date, now: Date, calendar: Calendar) -> String {
    if calendar.isDate(date, inSameDayAs: now) {
        return "today"
    }
    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
       calendar.isDate(date, inSameDayAs: tomorrow) {
        return "tomorrow"
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "EEE d MMM"
    formatter.timeZone = calendar.timeZone
    return formatter.string(from: date)
}

/// Idle bubble count scales with fill ratio using the existing generator.
/// Pure for testing: 20 empty … 40 full.
func bubbleCount(forFillRatio ratio: Double) -> Int {
    let clamped = min(max(ratio, 0), 1)
    return 20 + Int((clamped * 20).rounded())
}

/// The dashboard's bubbles.
///
/// While `KOFFEE_RENDER` is set they are drawn from a fixed seed, because `BubbleGenerator`'s layout
/// is the one thing in a dashboard render that comes from the system's entropy — two screenshots of
/// the same surface would otherwise differ only in where the bubbles sit. The app is unchanged: it
/// draws from the system, as before.
///
/// The seed is a parameter rather than a read of the environment so the seeded layout can be tested
/// for what it claims (the same seed twice is the same layout) in a process that is not rendering.
func dashboardBubbles(count: Int, seed: UInt64?) -> [BubbleState] {
    guard let seed else {
        return BubbleGenerator.generate(count: count, width: 400, height: 300)
    }
    var generator = SeededRandomNumberGenerator(seed: seed)
    return BubbleGenerator.generate(count: count, width: 400, height: 300, using: &generator)
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
