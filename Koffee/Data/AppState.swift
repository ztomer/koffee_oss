import Foundation
import Combine
import GRDB

enum AppError: Error, LocalizedError {
    case database(RepositoryError)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .database(let repoError): return repoError.localizedDescription
        case .unknown(let error): return error.localizedDescription
        }
    }
}

struct DailySummary: Equatable {
    let date: Date
    let totalCaffeineMg: Double
    let doseCount: Int
}

final class QueryService {
    private let doseRepo: DoseRepository

    init(doseRepo: DoseRepository) {
        self.doseRepo = doseRepo
    }

    func summaryForDate(_ date: Date) -> DailySummary {
        let doses = (try? doseRepo.dosesForDate(date)) ?? []

        return DailySummary(
            date: date,
            totalCaffeineMg: sumCaffeine(doses),
            doseCount: doses.count
        )
    }

    func totalCaffeineForDay(_ date: Date) -> Double {
        (try? doseRepo.dosesForDate(date)).map { sumCaffeine($0) } ?? 0
    }

    func caffeineCurveForDay(_ date: Date) -> [(time: Date, cumulativeMg: Double)] {
        guard let doses = try? doseRepo.dosesForDate(date) else { return [] }
        let sorted = doses.sorted { $0.timestamp < $1.timestamp }
        var cumulative: Double = 0
        return sorted.map { dose in
            cumulative += dose.caffeineMg
            return (dose.timestamp, cumulative)
        }
    }
}

@MainActor
// MARK: - AppState: Single Source of Truth
final class AppState: ObservableObject {
    // MARK: - @Published Properties
    @Published private(set) var profile: UserProfileModel?
    @Published private(set) var doses: [DoseModel] = []
    @Published private(set) var beverages: [BeverageModel] = []
    @Published private(set) var dailyPlanItems: [DailyPlanItemModel] = []

    @Published private(set) var todaySummary: DailySummary
    @Published private(set) var todayCaffeineTotal: Double
    @Published private(set) var toleranceAlert: ToleranceAlert?

    // Single source of truth for active caffeine level (pharmacokinetic-based)
    @Published private(set) var currentCaffeineLevel: Double = 0
    @Published private(set) var caffeineAtBedtime: Double = 0

    // MARK: - Computed Properties
    // Computed profile properties - single source of truth
    var safeCaffeineLimit: Double {
        guard let profile = profile else { return CaffeineConstants.defaultBedtimeMg }
        return Sensitivity(swiftDataValue: profile.sensitivity)?.safeCaffeineAtBedtime ?? CaffeineConstants.defaultBedtimeMg
    }

    /// Daily intake ceiling (weight/sensitivity-derived). The bedtime limit
    /// governs the *bedtime projection*; this governs *today's total*.
    var dailyCaffeineLimit: Double {
        guard let profile = profile else { return CaffeineConstants.dailyCeilingMg }
        return AppState.dailyCaffeineLimit(sensitivityRawValue: profile.sensitivity)
    }

    /// The daily ceiling for a sensitivity string, as a pure function of it.
    ///
    /// Split out from the property above so the ceiling is testable without a
    /// database and a profile row: the number is a SAFETY claim, and a safety
    /// claim that can only be checked by standing up the whole app is a claim
    /// nobody checks. See K1.
    static func dailyCaffeineLimit(sensitivityRawValue: String) -> Double {
        let sensitivity = Sensitivity(swiftDataValue: sensitivityRawValue) ?? .medium
        return sensitivity.dailyCeilingMg
    }

    var effectiveWakeTime: Date {
        profile?.wakeTime ?? DateHelper.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
    }

    var effectiveSleepTime: Date {
        profile?.sleepTime ?? DateHelper.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
    }

    // MARK: - PK Levels
    // Update PK-based caffeine levels
    func updateCaffeineLevels() {
        guard profile != nil else { return }

        let now = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)

        // Only use today's doses
        let todayDoses = self.doses.filter { $0.timestamp >= todayStart }
        let doses = todayDoses.map { ($0.timestamp, $0.caffeineMg) }

        debugLog("updateCaffeineLevels: \(doses.count) doses today")
        for (t, m) in doses {
            debugLog("  dose: time=\(t.timeIntervalSince1970), mg=\(m)")
        }

        // Current active caffeine level (same decay core as the chart)
        let metabolism = MetabolismRate(swiftDataValue: profile?.metabolismRate ?? "") ?? .medium
        currentCaffeineLevel = calculateCaffeineLevel(doses: doses, at: now, metabolism: metabolism)
        debugLog("  currentCaffeineLevel = \(currentCaffeineLevel)")

        // Caffeine at bedtime (shared funnel with dashboard + history)
        if let profile = profile {
            caffeineAtBedtime = projectBedtimeCaffeine(
                doses: doses,
                wakeTime: profile.wakeTime,
                sleepTime: profile.sleepTime,
                metabolism: metabolism
            )
            debugLog("  caffeineAtBedtime = \(caffeineAtBedtime)")
        }

        // Check for tolerance build-up (caffeine cycling)
        toleranceAlert = calculateToleranceAlert()
    }

    private func calculateToleranceAlert() -> ToleranceAlert? {
        guard !doses.isEmpty else { return nil }

        let calendar = Calendar.current
        let now = Date()

        // Count consecutive days of caffeine use
        var consecutiveDays = 0
        var checkDate = now

        for dayOffset in 0..<30 {
            checkDate = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            let dayStart = calendar.startOfDay(for: checkDate)
            let hasCaffeine = doses.contains { dose in
                calendar.startOfDay(for: dose.timestamp) == dayStart
            }
            if hasCaffeine {
                consecutiveDays += 1
            } else if dayOffset > 0 {
                break
            }
        }

        // Caffeine tolerance after 4+ days - recommend 1 day off
        if consecutiveDays >= 4 {
            return ToleranceAlert(
                compound: "Caffeine",
                daysConsecutive: consecutiveDays,
                recommendedCyclingDays: 4,
                message: "You've taken caffeine \(consecutiveDays) days in a row. Consider a 1-day break to prevent tolerance build-up.",
                urgency: consecutiveDays >= 7 ? .high : .medium
            )
        }

        return nil
    }

    let profileRepo: UserProfileRepository
    let doseRepo: DoseRepository
    let beverageRepo: BeverageRepository
    let planRepo: DailyPlanRepository
    let queryService: QueryService
    private var cancellables = Set<AnyCancellable>()

    var todayDoses: [DoseModel] { (try? doseRepo.dosesForDate(Date())) ?? [] }
    var todayPlanItems: [DailyPlanItemModel] { planRepo.items }

    init(
        profileRepo: UserProfileRepository,
        doseRepo: DoseRepository,
        beverageRepo: BeverageRepository,
        planRepo: DailyPlanRepository
    ) {
        self.profileRepo = profileRepo
        self.doseRepo = doseRepo
        self.beverageRepo = beverageRepo
        self.planRepo = planRepo
        self.queryService = QueryService(doseRepo: doseRepo)

        self.profile = profileRepo.profile
        self.doses = doseRepo.doses
        self.beverages = beverageRepo.beverages
        debugLog("AppState.init: planRepo.items = \(planRepo.items.count)")
        self.dailyPlanItems = planRepo.items
        self.todaySummary = queryService.summaryForDate(Date())
        self.todayCaffeineTotal = queryService.totalCaffeineForDay(Date())

        startObserving()
    }

    private func startObserving() {
        profileRepo.$profile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                self?.profile = profile
            }
            .store(in: &cancellables)

        doseRepo.$doses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] doses in
                guard let self = self else { return }
                self.doses = doses
                self.todaySummary = self.queryService.summaryForDate(Date())
                self.todayCaffeineTotal = self.queryService.totalCaffeineForDay(Date())

                // Update PK-based caffeine levels
                self.updateCaffeineLevels()
            }
            .store(in: &cancellables)

        beverageRepo.$beverages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] beverages in
                self?.beverages = beverages
            }
            .store(in: &cancellables)

        planRepo.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                debugLog("planRepo.$items received: \(items.count) items")
                self?.dailyPlanItems = items
            }
            .store(in: &cancellables)
    }

    /// Fallback summary when the query service is unavailable mid-teardown.
    static let emptySummary = DailySummary(
        date: Date(), totalCaffeineMg: 0, doseCount: 0)
}
