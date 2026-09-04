import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
final class QueryServiceTests: XCTestCase {

    var db: DatabaseQueue!
    var doseRepo: DoseRepository!
    var hydrationRepo: HydrationRepository!
    var supplementRepo: SupplementLogRepository!
    var exerciseRepo: ExerciseRepository!
    var queryService: QueryService!

    override func setUp() async throws {
        db = try DatabaseQueue()
        try DatabaseManager.makeMigrator().migrate(db)
        doseRepo = DoseRepository(db: db)
        hydrationRepo = HydrationRepository(db: db)
        supplementRepo = SupplementLogRepository(db: db)
        exerciseRepo = ExerciseRepository(db: db)
        let planRepo = DailyPlanRepository(db: db)
        queryService = QueryService(
            doseRepo: doseRepo,
            hydrationRepo: hydrationRepo,
            supplementRepo: supplementRepo,
            exerciseRepo: exerciseRepo
        )
    }

    func testSummaryForToday() throws {
        try doseRepo.add(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")
        try doseRepo.add(timestamp: Date(), caffeineMg: 50.0, beverageName: "Tea")
        try hydrationRepo.add(amountMl: 250.0)
        try supplementRepo.add(compoundName: "Creatine")
        try exerciseRepo.add(activityName: "Running", durationMinutes: 30)

        let summary = queryService.summaryForDate(Date())
        XCTAssertEqual(summary.doseCount, 2)
        XCTAssertEqual(summary.totalCaffeineMg, 145.0)
        XCTAssertEqual(summary.totalHydrationMl, 250.0)
        XCTAssertEqual(summary.supplementCount, 1)
        XCTAssertEqual(summary.exerciseCount, 1)
    }

    func testCaffeineCurve() throws {
        let now = Date()
        try doseRepo.add(timestamp: now, caffeineMg: 95.0, beverageName: "Coffee")
        try doseRepo.add(timestamp: now.addingTimeInterval(3600), caffeineMg: 50.0, beverageName: "Tea")

        let curve = queryService.caffeineCurveForDay(Date())
        XCTAssertEqual(curve.count, 2)
        XCTAssertEqual(curve[0].cumulativeMg, 95.0)
        XCTAssertEqual(curve[1].cumulativeMg, 145.0)
    }

    func testSummaryForEmptyDay() {
        let summary = queryService.summaryForDate(Date())
        XCTAssertEqual(summary.totalCaffeineMg, 0)
        XCTAssertEqual(summary.totalHydrationMl, 0)
        XCTAssertEqual(summary.doseCount, 0)
    }

    func testSummaryForYesterday() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        try db.write { db in
            try DoseModel(timestamp: yesterday, caffeineMg: 200.0, beverageName: "Espresso").insert(db)
        }

        let summary = queryService.summaryForDate(yesterday)
        XCTAssertEqual(summary.totalCaffeineMg, 200.0)
        XCTAssertEqual(summary.doseCount, 1)

        let todaySummary = queryService.summaryForDate(Date())
        XCTAssertEqual(todaySummary.totalCaffeineMg, 0)
    }
}
