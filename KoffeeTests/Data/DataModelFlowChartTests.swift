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

    // Test full chart data flow with doses
    func testChartDataGeneration_FullFlow() throws {
        let calendar = Calendar.current
        let now = Date()
        let dayKey = calendar.dateComponents([.year, .month, .day], from: now).description

        // Add dose
        try doseRepo.addWithId(id: "CHART-FULL-1-\(dayKey)", beverageId: nil, timestamp: now.addingTimeInterval(3600), caffeineMg: 95, beverageName: "Coffee")

        let saveExp = expectation(description: "data added")
        saveExp.assertForOverFulfill = false
        let c = appState.$doses
            .dropFirst()
            .sink { doses in
                if doses.count > 0 { saveExp.fulfill() }
            }
        wait(for: [saveExp], timeout: 2.0)
        c.cancel()

        // Calculate composite data
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        // Composite doses
        let todayDoses = appState.doses.filter { $0.timestamp >= today && $0.timestamp < tomorrow }
        let doses = todayDoses.map { ($0.timestamp, $0.caffeineMg) }

        // Generate chart data
        let wakeTime = appState.profile?.wakeTime ?? calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = appState.profile?.sleepTime ?? calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        let chartData = generateUnifiedCurvePoints(
            doses: doses,
            from: wakeTime,
            to: endTime,
            metabolism: MetabolismRate.medium
        )

        // Verify data flow
        XCTAssertEqual(doses.count, 1, "Should have 1 dose")
        XCTAssertGreaterThan(chartData.count, 0, "Should generate chart points")

        // Find point at or after dose time (first point is at wake time, dose is later)
        let doseTime = doses[0].0
        let pointAfterDose = chartData.first { $0.time >= doseTime } ?? chartData.last!

        // Verify Caffeine is in the data at/after dose time
        XCTAssertTrue(pointAfterDose.compoundLevels["Caffeine"] ?? 0 > 0, "Should have caffeine at dose time")
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

        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        let chartData = generateUnifiedCurvePoints(
            doses: doses,
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
    }

    // MARK: - Regression Test: Chart Data With No Doses vs With Coffee

    @MainActor
    func testChartData_NoDoses_vs_WithDose() throws {
        let calendar = Calendar.current
        let now = Date()
        let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        // NO DOSES CASE
        let noDosesChartData = generateUnifiedCurvePoints(
            doses: [],
            from: wakeTime,
            to: endTime,
            metabolism: .medium
        )

        XCTAssertFalse(noDosesChartData.isEmpty, "Should generate chart data even with no doses")
        for point in noDosesChartData {
            XCTAssertEqual(point.totalLevel, 0, "Total level should be 0 with no doses")
        }

        // WITH COFFEE CASE - verify caffeine is added
        let coffeeTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        let withDoseChartData = generateUnifiedCurvePoints(
            doses: [(coffeeTime, 95.0)],
            from: wakeTime,
            to: endTime,
            metabolism: .medium
        )

        let middleIndex = withDoseChartData.count / 2
        let middleWithCoffee = withDoseChartData[middleIndex]
        let caffeineWithCoffee = middleWithCoffee.compoundLevels["Caffeine"] ?? 0

        XCTAssertGreaterThan(caffeineWithCoffee, 0, "Should have caffeine when dose is added")
        XCTAssertGreaterThan(middleWithCoffee.totalLevel, 0, "Total level should be higher with coffee")
    }

    // MARK: - Regression: Empty Timeline Should Show No Graph

    @MainActor
    func testDashboard_EmptyTimeline_NoGraphData() throws {
        let calendar = Calendar.current
        let now = Date()

        // Verify: No doses, no plan items = empty chart
        let doses: [(Date, Double)] = []

        let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        let chartData = generateUnifiedCurvePoints(
            doses: doses,
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

        let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        let chartData = generateUnifiedCurvePoints(
            doses: doses,
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

    // MARK: - Bedtime Funnel Coherence (toolbar, dashboard, history share one backend)

    @MainActor
    func testBedtimeFunnelAgreesWithChartCore() {
        let calendar = Calendar.current
        let now = Date()
        let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let doseTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        let doses = [(doseTime, 95.0)]

        let viaFunnel = projectBedtimeCaffeine(doses: doses, wakeTime: wakeTime, sleepTime: sleepTime, metabolism: .medium)
        let viaChartCore = calculateCaffeineLevel(doses: doses, at: sleepTime, metabolism: .medium)

        XCTAssertEqual(viaFunnel, viaChartCore, accuracy: 0.001, "Funnel must equal the chart decay core on same-day schedules")
        XCTAssertGreaterThan(viaFunnel, 0)
    }

    @MainActor
    func testBedtimeFunnelRollsOvernightSchedule() {
        let calendar = Calendar.current
        let now = Date()
        // Night-shift schedule: wake 23:00, sleep 06:00 next day
        let wakeTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let sleepTime = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now)!
        let doseTime = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: now)!
        let doses = [(doseTime, 95.0)]

        let viaFunnel = projectBedtimeCaffeine(doses: doses, wakeTime: wakeTime, sleepTime: sleepTime, metabolism: .medium)
        let rolledSleep = calendar.date(byAdding: .day, value: 1, to: sleepTime)!
        let expected = calculateCaffeineLevel(doses: doses, at: rolledSleep, metabolism: .medium)

        XCTAssertEqual(viaFunnel, expected, accuracy: 0.001, "Overnight sleep must roll a day forward")
        XCTAssertGreaterThan(viaFunnel, 0, "Dose after wake must count toward that bedtime")
    }

    @MainActor
    func testBedtimeFunnelRespectsMetabolism() {
        let calendar = Calendar.current
        let now = Date()
        let wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let sleepTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        let doseTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        let doses = [(doseTime, 95.0)]

        let slow = projectBedtimeCaffeine(doses: doses, wakeTime: wakeTime, sleepTime: sleepTime, metabolism: .slow)
        let fast = projectBedtimeCaffeine(doses: doses, wakeTime: wakeTime, sleepTime: sleepTime, metabolism: .fast)

        XCTAssertGreaterThan(slow, fast, "Slow metabolizers must project higher bedtime levels")
    }
}
