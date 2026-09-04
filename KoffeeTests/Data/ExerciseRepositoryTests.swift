import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
final class ExerciseRepositoryTests: XCTestCase {

    var db: DatabaseQueue!
    var repo: ExerciseRepository!

    override func setUp() async throws {
        db = try DatabaseQueue()
        try DatabaseManager.makeMigrator().migrate(db)
        repo = ExerciseRepository(db: db)
    }

    func testAddExercise() throws {
        try repo.add(activityName: "Running", durationMinutes: 30)

        let expectation = expectation(description: "log added")
        let cancellable = repo.$logs.dropFirst().sink { logs in
            XCTAssertEqual(logs.count, 1)
            XCTAssertEqual(logs[0].activityName, "Running")
            XCTAssertEqual(logs[0].durationMinutes, 30)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }

    func testAddEmptyNameThrows() {
        XCTAssertThrowsError(try repo.add(activityName: "")) { error in
            guard let repoError = error as? RepositoryError else { return XCTFail("expected RepositoryError, got \(error)") }
            if case .validationFailed = repoError { } else { XCTFail("expected .validationFailed error") }
        }
    }

    func testAddZeroDurationThrows() {
        XCTAssertThrowsError(try repo.add(activityName: "Running", durationMinutes: 0)) { error in
            guard let repoError = error as? RepositoryError else { return XCTFail("expected RepositoryError, got \(error)") }
            if case .validationFailed = repoError { } else { XCTFail("expected .validationFailed error") }
        }
    }

    func testAddExcessiveDurationThrows() {
        XCTAssertThrowsError(try repo.add(activityName: "Running", durationMinutes: 500)) { error in
            guard let repoError = error as? RepositoryError else { return XCTFail("expected RepositoryError, got \(error)") }
            if case .validationFailed = repoError { } else { XCTFail("expected .validationFailed error") }
        }
    }

    func testAddWithoutDuration() throws {
        try repo.add(activityName: "Walking")

        let expectation = expectation(description: "log added")
        let cancellable = repo.$logs.dropFirst().sink { logs in
            XCTAssertEqual(logs[0].durationMinutes, nil)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }
}
