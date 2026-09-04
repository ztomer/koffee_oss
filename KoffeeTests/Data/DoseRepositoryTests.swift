import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
final class DoseRepositoryTests: XCTestCase {

    var db: DatabaseQueue!
    var repo: DoseRepository!

    override func setUp() async throws {
        db = try DatabaseQueue()
        try DatabaseManager.makeMigrator().migrate(db)
        repo = DoseRepository(db: db)
    }

    func testAddDose() throws {
        try repo.add(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")

        let expectation = expectation(description: "doses updated")
        let cancellable = repo.$doses.dropFirst().sink { doses in
            XCTAssertEqual(doses.count, 1)
            XCTAssertEqual(doses[0].caffeineMg, 95.0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }

    func testAddDoseNegativeCaffeineThrows() {
        XCTAssertThrowsError(try repo.add(timestamp: Date(), caffeineMg: -10.0)) { error in
            XCTAssertTrue(error is RepositoryError)
            guard let repoError = error as? RepositoryError else { return }
            if case .validationFailed(let msg) = repoError {
                XCTAssertTrue(msg.contains("non-negative"))
            } else {
                XCTFail("Expected validationFailed error")
            }
        }
    }

    func testAddDoseExcessiveCaffeineThrows() {
        XCTAssertThrowsError(try repo.add(timestamp: Date(), caffeineMg: 1500.0)) { error in
            XCTAssertTrue(error is RepositoryError)
            guard let repoError = error as? RepositoryError else { return }
            if case .validationFailed(let msg) = repoError {
                XCTAssertTrue(msg.contains("maximum"))
            } else {
                XCTFail("Expected validationFailed error")
            }
        }
    }

    func testDeleteDose() throws {
        try repo.add(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")

        let addExpectation = expectation(description: "dose added")
        let cancellable1 = repo.$doses.dropFirst().sink { doses in
            XCTAssertEqual(doses.count, 1)
            addExpectation.fulfill()
        }
        wait(for: [addExpectation], timeout: 2.0)
        cancellable1.cancel()

        let dose = repo.doses[0]
        try repo.delete(dose)

        let deleteExpectation = expectation(description: "dose deleted")
        let cancellable2 = repo.$doses.dropFirst().sink { doses in
            XCTAssertEqual(doses.count, 0)
            deleteExpectation.fulfill()
        }
        wait(for: [deleteExpectation], timeout: 2.0)
        cancellable2.cancel()
    }

    func testDosesForDateSQL() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        try repo.add(timestamp: yesterday, caffeineMg: 50.0, beverageName: "Tea")
        try repo.add(timestamp: today, caffeineMg: 95.0, beverageName: "Coffee")
        try repo.add(timestamp: calendar.date(byAdding: .hour, value: 2, to: today)!, caffeineMg: 95.0, beverageName: "Coffee")

        let todayDoses = try repo.dosesForDate(Date())
        XCTAssertEqual(todayDoses.count, 2)
        XCTAssertTrue(todayDoses.allSatisfy { $0.caffeineMg == 95.0 })

        let yesterdayDoses = try repo.dosesForDate(yesterday)
        XCTAssertEqual(yesterdayDoses.count, 1)
        XCTAssertEqual(yesterdayDoses[0].caffeineMg, 50.0)
    }

    func testDosesOrderedByTimestamp() throws {
        let now = Date()
        try repo.add(timestamp: now.addingTimeInterval(60), caffeineMg: 100.0, beverageName: "Second")
        try repo.add(timestamp: now, caffeineMg: 50.0, beverageName: "First")

        let exp = expectation(description: "doses ordered")
        exp.assertForOverFulfill = false
        var updateCount = 0
        let cancellable = repo.$doses.dropFirst().sink { doses in
            updateCount += 1
            if updateCount >= 2 {
                XCTAssertEqual(doses.count, 2)
                XCTAssertEqual(doses[0].beverageName, "First")
                XCTAssertEqual(doses[1].beverageName, "Second")
                exp.fulfill()
            }
        }

        wait(for: [exp], timeout: 2.0)
        cancellable.cancel()
    }
}
