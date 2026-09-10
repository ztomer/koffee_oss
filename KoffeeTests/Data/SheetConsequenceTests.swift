import XCTest
@testable import Koffee
import GRDB
import Combine

@MainActor
final class SheetConsequenceTests: XCTestCase {
    var appState: AppState!
    var cancellables = Set<AnyCancellable>()

    override func setUp() async throws {
        let db = try DatabaseQueue()
        try DatabaseManager.makeMigrator().migrate(db)
        appState = AppState(
            profileRepo: UserProfileRepository(db: db),
            doseRepo: DoseRepository(db: db),
            beverageRepo: BeverageRepository(db: db),
            planRepo: DailyPlanRepository(db: db)
        )
        var profile = try appState.getOrCreateProfile()
        profile.wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        profile.sleepTime = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        try appState.saveProfile(profile)
    }

    func testUsualBeverageIdPicksMostLogged() throws {
        XCTAssertNil(appState.usualBeverageId)
        try appState.addDose(beverageId: "a", timestamp: Date(), caffeineMg: 95, beverageName: "A")
        try appState.addDose(beverageId: "b", timestamp: Date(), caffeineMg: 95, beverageName: "B")
        try appState.addDose(beverageId: "a", timestamp: Date(), caffeineMg: 95, beverageName: "A")
        waitForDoseCount(3)
        XCTAssertEqual(appState.usualBeverageId, "a")
    }

    func testUsualBeverageIdTieGoesToMostRecent() throws {
        try appState.addDose(beverageId: "a", timestamp: Date(timeIntervalSince1970: 1000), caffeineMg: 95, beverageName: "A")
        try appState.addDose(beverageId: "b", timestamp: Date(timeIntervalSince1970: 2000), caffeineMg: 95, beverageName: "B")
        waitForDoseCount(2)
        XCTAssertEqual(appState.usualBeverageId, "b")
    }

    func testProjectedBedtimeMatchesFunnel() throws {
        waitForProfile()
        let beverage = BeverageModel(id: "x", name: "X", caffeineMg: 100, category: "Coffee", icon: "Coffee")
        let at = Date()
        let projected = appState.projectedBedtimeCaffeine(byAdding: beverage, at: at)
        let todayDoses = appState.dosesForDate(Date()).map { ($0.timestamp, $0.caffeineMg) }
        var combined = todayDoses
        combined.append((at, 100))
        let profile = try appState.getOrCreateProfile()
        let metabolism = MetabolismRate(swiftDataValue: profile.metabolismRate) ?? .medium
        let expected = projectBedtimeCaffeine(
            doses: combined,
            wakeTime: profile.wakeTime,
            sleepTime: profile.sleepTime,
            metabolism: metabolism
        )
        XCTAssertEqual(projected, expected, accuracy: 0.001)
    }

    private func waitForDoseCount(_ count: Int, timeout: TimeInterval = 2.0) {
        if appState.doses.count == count { return }
        let exp = expectation(description: "doses = \(count)")
        exp.assertForOverFulfill = false
        var cancellable: AnyCancellable?
        cancellable = appState.$doses.sink { doses in
            if doses.count == count {
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: timeout)
        cancellable?.cancel()
    }

    private func waitForProfile(timeout: TimeInterval = 2.0) {
        if appState.profile != nil { return }
        let exp = expectation(description: "profile set")
        exp.assertForOverFulfill = false
        var cancellable: AnyCancellable?
        cancellable = appState.$profile.sink { profile in
            if profile != nil { exp.fulfill() }
        }
        wait(for: [exp], timeout: timeout)
        cancellable?.cancel()
    }
}
