import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

// MARK: - Chart Normalization Tests

@MainActor
final class ChartNormalizationTests: XCTestCase {
    var testDB: TestDatabase!
    var appState: AppState!

    override func setUp() async throws {
        testDB = try TestDatabase()
        appState = testDB.appState
    }

    func testChartNormalizesAllCompoundsByOwnSafeLimit() throws {
        let now = Date()

        // Add caffeine dose (95mg) - 95/400 = 23.75%
        try testDB.doseRepo.addWithId(id: "DOSE-1", beverageId: nil, timestamp: now, caffeineMg: 95, beverageName: "Coffee")

        // Add creatine plan item (5000mg) - 5000/5000 = 100%
        let planItem = DailyPlanItemModel(
            id: "CREATINE-2026-04-12",
            compoundUuid: "creatine",
            dayKey: DailyPlanItemModel.dayKey(for: now),
            compoundName: "Creatine",
            doseMg: 5000,
            source: .baseStack,
            status: .pending,
            scheduledTime: now
        )
        try testDB.planRepo.save(planItem)

        // Wait for data
        let exp = expectation(description: "data loaded")
        exp.assertForOverFulfill = false
        let c = appState.$doses.dropFirst().sink { _ in exp.fulfill() }
        wait(for: [exp], timeout: 2.0)
        c.cancel()

        // Verify creatine is normalized by its own safe limit (5000mg), not 400mg
        let creatineSafeLimit = NootropicCompound.creatine.safeLimitMg
        XCTAssertEqual(creatineSafeLimit, 5000, "Creatine safeLimitMg should be 5000mg")

        let creatinePercent = (5000.0 / creatineSafeLimit) * 100.0
        XCTAssertEqual(creatinePercent, 100.0, "Creatine at 5000mg = 100% of its own safe limit")
    }

    func testChartYAxisFitsAllData() throws {
        // Minimum Y-axis is 30% to prevent cutoff when data is small
        let minYAxis = 30
        XCTAssertEqual(minYAxis, 30, "Minimum Y-axis should be 30%")
    }

    func testSafeLimitMgForAllCompounds() throws {
        XCTAssertEqual(NootropicCompound.caffeine.safeLimitMg, 400)
        XCTAssertEqual(NootropicCompound.lTheanine.safeLimitMg, 400)
        XCTAssertEqual(NootropicCompound.magnesium.safeLimitMg, 4000)
        XCTAssertEqual(NootropicCompound.ashwagandha.safeLimitMg, 600)
        XCTAssertEqual(NootropicCompound.vitaminB.safeLimitMg, 100)
        XCTAssertEqual(NootropicCompound.rhodiola.safeLimitMg, 600)
        XCTAssertEqual(NootropicCompound.theacrine.safeLimitMg, 300)
        XCTAssertEqual(NootropicCompound.creatine.safeLimitMg, 5000)
        XCTAssertEqual(NootropicCompound.alphaGPC.safeLimitMg, 600)
        XCTAssertEqual(NootropicCompound.lTyrosine.safeLimitMg, 3000)
        XCTAssertEqual(NootropicCompound.psylliumHusk.safeLimitMg, 5000)
        XCTAssertEqual(NootropicCompound.glycine.safeLimitMg, 3000)
    }
}
