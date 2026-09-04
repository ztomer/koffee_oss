import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
final class SupplementLogRepositoryTests: XCTestCase {

    var db: DatabaseQueue!
    var repo: SupplementLogRepository!

    override func setUp() async throws {
        db = try DatabaseQueue()
        try DatabaseManager.makeMigrator().migrate(db)
        repo = SupplementLogRepository(db: db)
    }

    func testAddSupplement() throws {
        try repo.add(compoundName: "Creatine")

        let expectation = expectation(description: "log added")
        let cancellable = repo.$logs.dropFirst().sink { logs in
            XCTAssertEqual(logs.count, 1)
            XCTAssertEqual(logs[0].compoundName, "Creatine")
            XCTAssertEqual(logs[0].status, .taken)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }

    func testAddEmptyNameThrows() {
        XCTAssertThrowsError(try repo.add(compoundName: "")) { error in
            guard let repoError = error as? RepositoryError else { return XCTFail("expected RepositoryError, got \(error)") }
            if case .validationFailed = repoError { } else { XCTFail("expected .validationFailed error") }
        }
    }

    func testAddWithCustomStatus() throws {
        try repo.add(compoundName: "L-Theanine", status: .skipped)

        let expectation = expectation(description: "log added")
        let cancellable = repo.$logs.dropFirst().sink { logs in
            XCTAssertEqual(logs[0].status, .skipped)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }
}
