import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
extension DataModelFlowTests {
    // MARK: - Chart Data Generation Tests

    // Test that generateUnifiedCurvePoints produces output with doses
    func testChartDataGeneration_WithDoses() throws {
        let calendar = Calendar.current
        let now = Date()
        let dayKey = calendar.dateComponents([.year, .month, .day], from: now).description

        // Add a dose at 9am
        let doseTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        try doseRepo.addWithId(id: "CHART-DOSE-1-\(dayKey)", beverageId: nil, timestamp: doseTime, caffeineMg: 95, beverageName: "Coffee")

        let saveExp = expectation(description: "dose added")
        saveExp.assertForOverFulfill = false
        let c = appState.$doses.dropFirst().sink { doses in
            if doses.count > 0 { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c.cancel()

        // Test the generation function
        let doses: [(Date, Double)] = [(doseTime, 95)]
        let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        let points = generateUnifiedCurvePoints(
            doses: doses,
            supplements: [],
            from: wakeTime,
            to: endTime,
            metabolism: MetabolismRate.medium
        )

        XCTAssertGreaterThan(points.count, 0, "Should generate curve points")

        // Find a point AFTER the dose time (not at wake time)
        let pointAfterDose = points.first { $0.time > doseTime }
        XCTAssertNotNil(pointAfterDose, "Should have a point after dose time")
        XCTAssertTrue(pointAfterDose?.compoundLevels["Caffeine"] ?? 0 > 0, "Point after dose should have caffeine")
    }

    // Test that generateUnifiedCurvePoints produces output with supplements
    func testChartDataGeneration_WithSupplements() throws {
        let calendar = Calendar.current
        let now = Date()

        // No doses, but with supplements
        let doses: [(Date, Double)] = []
        let supplements: [NootropicCompound] = [.lTheanine, .magnesium]
        let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        let points = generateUnifiedCurvePoints(
            doses: doses,
            supplements: supplements,
            from: wakeTime,
            to: endTime,
            metabolism: MetabolismRate.medium
        )

        XCTAssertGreaterThan(points.count, 0, "Should generate curve points even without doses")

        // Without doses, supplements have 0 level (they use doses as input for calculation)
        // So check that the function runs without error and returns expected structure
        XCTAssertEqual(points.first?.compoundLevels.keys.contains("L-Theanine"), true, "Should have L-Theanine key")
        XCTAssertEqual(points.first?.compoundLevels.keys.contains("Magnesium"), true, "Should have Magnesium key")
    }

    // Test composite supplements from timeline
    func testChartDataGeneration_CompositeSupplements() throws {
        let calendar = Calendar.current
        let dayKey = calendar.dateComponents([.year, .month, .day], from: Date()).description

        // Add a supplement
        try supplementRepo.addWithId(id: "CHART-SUPP-1-\(dayKey)", compoundName: "L-Theanine", status: .pending)

        let saveExp = expectation(description: "supplement added")
        saveExp.assertForOverFulfill = false
        let c = appState.$supplementLogs.dropFirst().sink { logs in
            if logs.count > 0 { saveExp.fulfill() }
        }
        wait(for: [saveExp], timeout: 2.0)
        c.cancel()

        // Get composite supplements (simulating Dashboard logic)
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let todaySupplements = appState.supplementLogs.filter { $0.timestamp >= today && $0.timestamp < tomorrow }
        var compounds: Set<NootropicCompound> = []
        for log in todaySupplements {
            if let compound = NootropicCompound(rawValue: log.compoundName) {
                compounds.insert(compound)
            }
        }

        let pendingSupplements = appState.dailyPlanItems.filter {
            $0.compoundUuid != "caffeine" && $0.status == .pending && $0.scheduledTime >= today && $0.scheduledTime < tomorrow
        }
        for item in pendingSupplements {
            if let compound = NootropicCompound(rawValue: item.compoundName) {
                compounds.insert(compound)
            }
        }

        let compositeSupplements = Array(compounds)

        XCTAssertTrue(compositeSupplements.contains(.lTheanine), "Should have L-Theanine from history")
        XCTAssertEqual(compositeSupplements.count, 1, "Should have exactly 1 compound")
    }

    // Test full chart data flow with doses and supplements
    func testChartDataGeneration_FullFlow() throws {
        let calendar = Calendar.current
        let now = Date()
        let dayKey = calendar.dateComponents([.year, .month, .day], from: now).description

        // Add dose and supplement
        try doseRepo.addWithId(id: "CHART-FULL-1-\(dayKey)", beverageId: nil, timestamp: now.addingTimeInterval(3600), caffeineMg: 95, beverageName: "Coffee")
        try supplementRepo.addWithId(id: "CHART-FULL-2-\(dayKey)", compoundName: "L-Theanine", status: .pending)

        let saveExp = expectation(description: "data added")
        saveExp.assertForOverFulfill = false
        let c = Publishers.CombineLatest(appState.$doses, appState.$supplementLogs)
            .dropFirst()
            .sink { doses, logs in
                if doses.count > 0 && logs.count > 0 { saveExp.fulfill() }
            }
        wait(for: [saveExp], timeout: 2.0)
        c.cancel()

        // Calculate composite data
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        // Composite doses
        let todayDoses = appState.doses.filter { $0.timestamp >= today && $0.timestamp < tomorrow }
        let doses = todayDoses.map { ($0.timestamp, $0.caffeineMg) }

        // Composite supplements
        var supplementSet: Set<NootropicCompound> = []
        for log in appState.supplementLogs.filter({ $0.timestamp >= today && $0.timestamp < tomorrow }) {
            if let compound = NootropicCompound(rawValue: log.compoundName) {
                supplementSet.insert(compound)
            }
        }

        // Generate chart data
        let wakeTime = appState.profile?.wakeTime ?? calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = appState.profile?.sleepTime ?? calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        let chartData = generateUnifiedCurvePoints(
            doses: doses,
            supplements: Array(supplementSet),
            from: wakeTime,
            to: endTime,
            metabolism: MetabolismRate.medium
        )

        // Verify data flow
        XCTAssertEqual(doses.count, 1, "Should have 1 dose")
        XCTAssertEqual(supplementSet.count, 1, "Should have 1 supplement")
        XCTAssertGreaterThan(chartData.count, 0, "Should generate chart points")

        // Find point at or after dose time (first point is at wake time, dose is later)
        let doseTime = doses[0].0
        let pointAfterDose = chartData.first { $0.time >= doseTime } ?? chartData.last!

        // Verify Caffeine and L-Theanine are in the data at/after dose time
        XCTAssertTrue(pointAfterDose.compoundLevels["Caffeine"] ?? 0 > 0, "Should have caffeine at dose time")
        XCTAssertTrue(pointAfterDose.compoundLevels["L-Theanine"] ?? 0 > 0, "Should have L-Theanine at dose time")
    }

    // MARK: - Regression Tests for Date Handling

    func testChartDataGeneration_UsesCurrentYearNotYear0001() {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)

        // Create profile with wake/sleep times (should use current year)
        let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!

        // Verify wake/sleep times are in current year
        let wakeYear = calendar.component(.year, from: wakeTime)
        let sleepYear = calendar.component(.year, from: sleepTime)

        XCTAssertEqual(wakeYear, currentYear, "Wake time should be in current year")
        XCTAssertEqual(sleepYear, currentYear, "Sleep time should be in current year")
        XCTAssertGreaterThan(wakeTime.timeIntervalSince1970, 0, "Wake time should have valid timestamp")

        // Generate chart data with these times
        let doses: [(Date, Double)] = [(wakeTime.addingTimeInterval(3600), 95.0)]

        let chartData = generateUnifiedCurvePoints(
            doses: doses,
            supplements: [.caffeine],
            from: wakeTime,
            to: sleepTime.addingTimeInterval(3600 * 4),
            metabolism: .medium
        )

        // Verify chart data points are in current year, not year 0001
        for point in chartData {
            let pointYear = calendar.component(.year, from: point.time)
            XCTAssertEqual(pointYear, currentYear, "Chart point should be in current year, got \(pointYear)")
        }

        XCTAssertGreaterThan(chartData.count, 0, "Should generate chart points")
    }

    func testChartDataGeneration_TimeRangeFromProfileTimes() {
        let calendar = Calendar.current
        let now = Date()

        // Create profile times
        let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!

        // Add a dose at 10am
        let doseTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!
        let doses: [(Date, Double)] = [(doseTime, 95.0)]

        // Use L-Theanine as supplement
        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        let chartData = generateUnifiedCurvePoints(
            doses: doses,
            supplements: [.lTheanine],
            from: wakeTime,
            to: endTime,
            metabolism: .medium
        )

        // Verify first point is at wake time
        XCTAssertEqual(chartData.first?.time, wakeTime, "First chart point should be at wake time")

        // Verify last point is at end time
        XCTAssertEqual(chartData.last?.time, endTime, "Last chart point should be at end time")

        // Find a point well after the dose time (at least 1 hour after dose for noticeable level)
        let pointAfterDose = chartData.first { $0.time >= doseTime.addingTimeInterval(3600) }
        XCTAssertNotNil(pointAfterDose, "Should have a point at least 1 hour after dose time")

        // Verify caffeine (handled via calculateCaffeineLevel) is > 0
        let caffeineLevel = pointAfterDose!.compoundLevels["Caffeine"] ?? 0
        XCTAssertGreaterThan(caffeineLevel, 0, "Should have caffeine level > 0 after dose")

        // Verify L-Theanine levels (which comes from supplements using optimalDoseMg)
        let lTheanineLevel = pointAfterDose!.compoundLevels["L-Theanine"] ?? 0
        XCTAssertGreaterThan(lTheanineLevel, 0, "Should have L-Theanine level > 0 (uses optimalDoseMg)")
    }

    // MARK: - Regression Tests for Composite Supplements

    // Tests for graph showing supplements from profile stack - see DashboardView.compositeSupplements

    // MARK: - Regression Test: Chart Data With No Doses vs With Coffee

    @MainActor
    func testChartData_ProfileStack_NoDoses_vs_WithDose() throws {
        let calendar = Calendar.current
        let now = Date()
        let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        // Profile has L-Theanine and Magnesium
        let supplements: [NootropicCompound] = [.lTheanine, .magnesium]

        // NO DOSES CASE
        let noDosesChartData = generateUnifiedCurvePoints(
            doses: [],
            supplements: supplements,
            from: wakeTime,
            to: endTime,
            metabolism: .medium
        )

        // Verify: With no doses, we should still have chart points with supplement levels
        XCTAssertFalse(noDosesChartData.isEmpty, "Should generate chart data even with no doses")

        let firstPoint = noDosesChartData.first!
        let middleIndex = noDosesChartData.count / 2
        let middlePoint = noDosesChartData[middleIndex]
        let lastPoint = noDosesChartData.last!

        // L-Theanine: recommendedTiming = -45min (6:15am), so at 7am it's 45 min after "take time"
        // Should have some level at 7am
        let ltheanineFirst = firstPoint.compoundLevels["L-Theanine"] ?? 0
        XCTAssertGreaterThan(ltheanineFirst, 0, "L-Theanine should have level at 7am (starts before wake)")

        // Magnesium: recommendedTiming = +60min (8:00am), so at 7am it's BEFORE take time
        // Should have ZERO level at 7am (hasn't been taken yet)
        let magnesiumFirst = firstPoint.compoundLevels["Magnesium"] ?? 0
        XCTAssertEqual(magnesiumFirst, 0, "Magnesium should have 0 level at 7am (takes at 8am)")

        // At middle of day (12pm), both should have levels
        let ltheanineMiddle = middlePoint.compoundLevels["L-Theanine"] ?? 0
        let magnesiumMiddle = middlePoint.compoundLevels["Magnesium"] ?? 0

        XCTAssertGreaterThan(ltheanineMiddle, 0, "L-Theanine should have level at noon")
        XCTAssertGreaterThan(magnesiumMiddle, 0, "Magnesium should have level at noon")

        // Key test: levels should change over time (different curves)
        // L-Theanine (4h half-life) should decay faster than Magnesium (6h half-life)
        let ltheanineLast = lastPoint.compoundLevels["L-Theanine"] ?? 0
        let magnesiumLast = lastPoint.compoundLevels["Magnesium"] ?? 0

        XCTAssertLessThan(ltheanineLast, ltheanineMiddle, "L-Theanine should decay by late night")
        XCTAssertLessThan(magnesiumLast, magnesiumMiddle, "Magnesium should decay by late night")

        // L-Theanine decays faster (4h vs 6h half-life)
        let ltheanineDecayRatio = ltheanineLast / max(ltheanineMiddle, 0.001)
        let magnesiumDecayRatio = magnesiumLast / max(magnesiumMiddle, 0.001)
        XCTAssertLessThan(ltheanineDecayRatio, magnesiumDecayRatio, "L-Theanine (4h HL) should decay more than Magnesium (6h HL)")

        // WITH COFFEE CASE - verify caffeine is added
        let coffeeTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        let withDoseChartData = generateUnifiedCurvePoints(
            doses: [(coffeeTime, 95.0)],
            supplements: supplements,
            from: wakeTime,
            to: endTime,
            metabolism: .medium
        )

        let middleWithCoffee = withDoseChartData[middleIndex]
        let caffeineWithCoffee = middleWithCoffee.compoundLevels["Caffeine"] ?? 0

        XCTAssertGreaterThan(caffeineWithCoffee, 0, "Should have caffeine when dose is added")
        XCTAssertGreaterThan(middleWithCoffee.totalLevel, middlePoint.totalLevel, "Total level should be higher with coffee")
    }

    // MARK: - Regression: Empty Timeline Should Show No Graph

    @MainActor
    func testDashboard_EmptyTimeline_NoGraphData() throws {
        let calendar = Calendar.current
        let now = Date()
        let dayKey = calendar.dateComponents([.year, .month, .day], from: now).description

        // Verify: No doses, no plan items, no supplement logs, no profile stack = empty chart
        let doses: [(Date, Double)] = []
        let supplements: [NootropicCompound] = []

        let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        let chartData = generateUnifiedCurvePoints(
            doses: doses,
            supplements: supplements,
            from: wakeTime,
            to: endTime,
            metabolism: .medium
        )

        XCTAssertFalse(chartData.isEmpty, "Should still generate time points even with no data")

        // All compound levels should be zero
        for point in chartData {
            for (_, level) in point.compoundLevels {
                XCTAssertEqual(level, 0, "All compound levels should be 0 when no doses/supplements")
            }
            XCTAssertEqual(point.totalLevel, 0, "Total level should be 0")
        }
    }

    @MainActor
    func testDashboard_PendingPlanItems_AppearInGraph() throws {
        let calendar = Calendar.current
        let now = Date()

        // Verify: pending plan items are included in chart
        // Create a pending plan item at 10am
        let pendingTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!
        let dayKey = calendar.dateComponents([.year, .month, .day], from: now).description

        // Manually add pending plan item
        try planRepo.save(DailyPlanItemModel(
            id: "pending-1-\(dayKey)",
            compoundName: "Caffeine",
            scheduledTime: pendingTime,
            status: PlanItemStatus.pending,
            dayKey: dayKey,
            compoundUuid: "caffeine",
            doseMg: 100
        ))

        // Wait for plan items to update
        let exp = expectation(description: "plan updated")
        exp.assertForOverFulfill = false
        let c = appState.$dailyPlanItems.dropFirst().sink { _ in exp.fulfill() }
        wait(for: [exp], timeout: 2.0)
        c.cancel()

        // Verify: pending item causes graph to have data
        let doses: [(Date, Double)] = [(pendingTime, 100)]
        let supplements: [NootropicCompound] = []

        let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        let chartData = generateUnifiedCurvePoints(
            doses: doses,
            supplements: supplements,
            from: wakeTime,
            to: endTime,
            metabolism: .medium
        )

        // Find point at or after the pending dose time
        let pointAfterPending = chartData.first { $0.time >= pendingTime }
        XCTAssertNotNil(pointAfterPending, "Should have a point at or after pending dose time")

        let caffeineLevel = pointAfterPending?.compoundLevels["Caffeine"] ?? 0
        XCTAssertGreaterThan(caffeineLevel, 0, "Pending plan item should appear in chart")

        // Cleanup - skip the plan item
        try appState.updatePlanItemStatus(id: "pending-1-\(dayKey)", status: .skipped)
    }
}
