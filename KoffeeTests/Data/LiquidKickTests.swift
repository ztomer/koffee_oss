import XCTest
@testable import Koffee

final class LiquidKickTests: XCTestCase {
    func testBubbleCountScalesWithFill() {
        XCTAssertEqual(bubbleCount(forFillRatio: 0), 20)
        XCTAssertEqual(bubbleCount(forFillRatio: 1), 40)
        XCTAssertGreaterThan(bubbleCount(forFillRatio: 0.9), bubbleCount(forFillRatio: 0.1))
    }

    func testBubbleCountClamps() {
        XCTAssertEqual(bubbleCount(forFillRatio: -1), 20)
        XCTAssertEqual(bubbleCount(forFillRatio: 5), 40)
    }
}
