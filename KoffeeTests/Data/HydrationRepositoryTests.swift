import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
final class HydrationRepositoryTests: XCTestCase {

    var db: DatabaseQueue!
    var repo: HydrationRepository!

    override func setUp() async throws {
        db = try DatabaseQueue()
        try DatabaseManager.makeMigrator().migrate(db)
        repo = HydrationRepository(db: db)
    }

    func testAddHydration() throws {
        try repo.add(amountMl: 250.0)

        let expectation = expectation(description: "entry added")
        let cancellable = repo.$entries.dropFirst().sink { entries in
            XCTAssertEqual(entries.count, 1)
            XCTAssertEqual(entries[0].amountMl, 250.0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }

    func testAddZeroHydrationThrows() {
        XCTAssertThrowsError(try repo.add(amountMl: 0)) { error in
            guard let repoError = error as? RepositoryError else { return XCTFail("expected RepositoryError, got \(error)") }
            if case .validationFailed = repoError { } else { XCTFail("expected .validationFailed error") }
        }
    }

    func testAddNegativeHydrationThrows() {
        XCTAssertThrowsError(try repo.add(amountMl: -100)) { error in
            guard let repoError = error as? RepositoryError else { return XCTFail("expected RepositoryError, got \(error)") }
            if case .validationFailed = repoError { } else { XCTFail("expected .validationFailed error") }
        }
    }

    func testAddExcessiveHydrationThrows() {
        XCTAssertThrowsError(try repo.add(amountMl: 10000)) { error in
            guard let repoError = error as? RepositoryError else { return XCTFail("expected RepositoryError, got \(error)") }
            if case .validationFailed = repoError { } else { XCTFail("expected .validationFailed error") }
        }
    }

    func testEntriesForDateSQL() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        try repo.add(amountMl: 200.0)
        try db.write { db in
            try HydrationEntryModel(amountMl: 500.0, timestamp: yesterday).insert(db)
        }

        let todayEntries = try repo.entriesForDate(Date())
        XCTAssertEqual(todayEntries.count, 1)
        XCTAssertEqual(todayEntries[0].amountMl, 200.0)
    }
}
