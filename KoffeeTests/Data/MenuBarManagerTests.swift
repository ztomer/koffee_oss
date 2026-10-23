import XCTest
@testable import Koffee
import GRDB
import Combine

@MainActor
final class MenuBarManagerTests: XCTestCase {
    var testDB: TestDatabase!
    var appState: AppState!

    override func setUp() async throws {
        testDB = try TestDatabase()
        appState = testDB.appState
        _ = try appState.getOrCreateProfile()
    }

    func testMenuBarManagerBindsToAppStateAndCalculatesStatus() async throws {
        let manager = MenuBarManager()
        manager.bind(appState: appState)

        // Seed an espresso beverage
        let bev = BeverageModel(id: "espresso-1", name: "Espresso", caffeineMg: 64, category: "Coffee", icon: "cup.and.saucer")
        try await testDB.db.write { db in
            try bev.insert(db)
        }

        let exp = expectation(description: "caffeine level updated")
        exp.assertForOverFulfill = false
        let cancellable = manager.$currentLevel.dropFirst().sink { level in
            if level > 0 { exp.fulfill() }
        }

        // Log a dose
        let now = DateHelper.now
        try appState.addDose(beverageId: bev.id, timestamp: now, caffeineMg: 64.0, beverageName: bev.name)

        await fulfillment(of: [exp], timeout: 3.0)
        cancellable.cancel()

        XCTAssertGreaterThan(manager.currentLevel, 0.0)
    }

    func testQuickLogDoseLogsUsualBeverage() async throws {
        let manager = MenuBarManager()
        manager.bind(appState: appState)

        let bev = BeverageModel(id: "espresso-1", name: "Espresso", caffeineMg: 64, category: "Coffee", icon: "cup.and.saucer")
        try await testDB.db.write { db in
            try bev.insert(db)
        }

        // Initially no doses
        XCTAssertEqual(appState.doses.count, 0)

        let exp = expectation(description: "doses updated")
        exp.assertForOverFulfill = false
        let cancellable = appState.$doses.dropFirst().sink { doses in
            if !doses.isEmpty { exp.fulfill() }
        }

        // Log dose via manager
        manager.logDose(beverage: bev)

        await fulfillment(of: [exp], timeout: 3.0)
        cancellable.cancel()

        XCTAssertEqual(appState.doses.count, 1)
        XCTAssertEqual(appState.doses.first?.beverageName, "Espresso")
        XCTAssertEqual(appState.doses.first?.caffeineMg, 64.0)
    }
}
