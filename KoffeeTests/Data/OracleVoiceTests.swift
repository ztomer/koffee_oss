import XCTest
@testable import Koffee

final class OracleVoiceTests: XCTestCase {
    func testSleepReadyThanksLine() {
        let line = oracleLine(bedtimeMg: 20, limit: 100, thresholdName: "the 100mg research limit")
        XCTAssertTrue(line.contains("20mg"))
        XCTAssertTrue(line.lowercased().contains("thanks"))
    }

    func testMonitorWiredLine() {
        let line = oracleLine(bedtimeMg: 70, limit: 100, thresholdName: "the 100mg research limit")
        XCTAssertTrue(line.contains("70mg"))
        XCTAssertTrue(line.lowercased().contains("wired"))
    }

    func testOverPutDownLine() {
        let line = oracleLine(bedtimeMg: 150, limit: 100, thresholdName: "the 100mg research limit")
        XCTAssertTrue(line.contains("150mg"))
        XCTAssertTrue(line.lowercased().contains("pot down"))
    }

    func testNoEmojiInAnyState() {
        for mg in [0.0, 20, 50, 70, 100, 150] {
            let line = oracleLine(bedtimeMg: mg, limit: 100, thresholdName: "the 100mg research limit")
            XCTAssertTrue(line.unicodeScalars.allSatisfy { !$0.properties.isEmoji || $0.value < 0x2000 })
        }
    }
}
