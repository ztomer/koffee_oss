import XCTest
@testable import Koffee
import Foundation

final class HistoryStreakTests: XCTestCase {
    private func dose(at date: Date) -> DoseModel {
        DoseModel(beverageId: "a", timestamp: date, caffeineMg: 95, beverageName: "A")
    }

    func testThreeMorningsInARow() {
        let cal = Calendar.current
        let now = Date()
        let doses = (0..<3).map { dose(at: cal.date(byAdding: .day, value: -$0, to: now)!) }
        XCTAssertEqual(consecutiveDayStreak(doses: doses, calendar: cal, now: now), 3)
        XCTAssertEqual(streakLine(3), "3 mornings in a row")
    }

    func testStreakBreaksOnGap() {
        let cal = Calendar.current
        let now = Date()
        let doses = [
            dose(at: now),
            dose(at: cal.date(byAdding: .day, value: -2, to: now)!)
        ]
        XCTAssertEqual(consecutiveDayStreak(doses: doses, calendar: cal, now: now), 1)
    }

    func testEmptyStreakIsZero() {
        XCTAssertEqual(consecutiveDayStreak(doses: [], calendar: .current), 0)
    }
}
