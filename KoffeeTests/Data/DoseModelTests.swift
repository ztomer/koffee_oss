import XCTest
@testable import Koffee
import GRDB
import Combine
import SwiftUI

@MainActor
final class DoseModelTests: XCTestCase {

    func testInsertAndFetch() throws {
        let db = try DatabaseQueue()
        try setupSchema(db)

        let dose = DoseModel(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")
        try db.write { db in
            try dose.insert(db)
        }

        let fetched = try db.read { db in
            try DoseModel.fetchAll(db)
        }

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].caffeineMg, 95.0)
        XCTAssertEqual(fetched[0].beverageName, "Coffee")
    }

    func testDelete() throws {
        let db = try DatabaseQueue()
        try setupSchema(db)

        let dose = DoseModel(timestamp: Date(), caffeineMg: 95.0, beverageName: "Coffee")
        try db.write { db in
            try dose.insert(db)
        }

        try db.write { db in
            _ = try dose.delete(db)
        }

        let fetched = try db.read { db in
            try DoseModel.fetchAll(db)
        }

        XCTAssertEqual(fetched.count, 0)
    }

    func testDeleteNonExistentThrows() throws {
        let db = try DatabaseQueue()
        try setupSchema(db)

        let dose = DoseModel(id: "nonexistent", timestamp: Date(), caffeineMg: 95.0)

        XCTAssertThrowsError(try db.write { db in
            let deleted = try dose.delete(db)
            guard deleted else {
                throw RepositoryError.notFound("Dose \(dose.id)")
            }
        })
    }

    private func setupSchema(_ db: DatabaseQueue) throws {
        try DatabaseManager.makeMigrator().migrate(db)
    }
}
