import XCTest
@testable import Koffee
import Foundation

// K4 (roadmap Phase 0b): the bedtime residual tiers, and which of them is sourced.
//
// 25 / 50 / 100 mg. koffee_big's evidence audit found a source for one of them
// only: efsa2015sleep reports that single doses around 100 mg "may increase sleep
// latency and reduce sleep duration in some adult individuals, particularly when
// consumed close to bedtime", and its own stated limitation is that this supports
// a warning rather than a precise per-person threshold. The 50 and the 25 are this
// app's own convention.
//
// The convention is kept, because it is STRICTER than the source rather than
// laxer. That direction is the whole question: warning earlier than the evidence
// requires is a preference the reader may hold; warning later would be a claim.
// So the load-bearing property here is one-directional.
final class BedtimeThresholdProvenanceTests: XCTestCase {

    // MARK: - The one-directional property

    /// No reader's threshold may be LAXER than the sourced figure.
    ///
    /// This is the assertion that stops a future session "finishing" K4 by
    /// collapsing all three tiers to 100 mg — which reads like tidying and is in
    /// fact the app starting to permit what it currently warns about.
    func testNoThresholdIsLaxerThanTheSourcedFigure() {
        let sourced = Sensitivity.low.safeCaffeineAtBedtime
        XCTAssertEqual(sourced, 100.0)
        for sensitivity in Sensitivity.allCases {
            XCTAssertLessThanOrEqual(
                sensitivity.safeCaffeineAtBedtime, sourced,
                "\(sensitivity.rawValue) permits \(sensitivity.safeCaffeineAtBedtime) mg, "
                    + "laxer than the sourced \(sourced) mg"
            )
        }
    }

    /// And the sourced figure must remain REACHABLE, not merely in the table: a
    /// reader who never touches the setting gets the number the evidence backs.
    func testTheSourcedFigureIsReachable() {
        XCTAssertTrue(Sensitivity.allCases.contains { $0.bedtimeThresholdIsSourced })
        XCTAssertEqual(
            Sensitivity.allCases.filter { $0.bedtimeThresholdIsSourced }.count, 1,
            "exactly one threshold is sourced; the rest are convention"
        )
    }

    // MARK: - The provenance is visible to the reader

    /// The two kinds of number are named differently on screen. A convention that
    /// renders exactly like a finding is a finding, whatever the docstring says.
    func testSourcedAndConventionalThresholdsAreNamedDifferently() {
        XCTAssertEqual(
            Sensitivity.low.bedtimeThresholdName, "the 100mg research limit",
            "the sourced figure names its source"
        )
        for sensitivity in Sensitivity.allCases where !sensitivity.bedtimeThresholdIsSourced {
            XCTAssertTrue(
                sensitivity.bedtimeThresholdName.contains("stricter"),
                "\(sensitivity.rawValue) must name its threshold as the reader's own "
                    + "choice, not as evidence"
            )
        }
        let names = Set(Sensitivity.allCases.map(\.bedtimeThresholdName))
        XCTAssertEqual(names.count, Sensitivity.allCases.count, "each reader gets its own name")
    }

    /// The sentence a reader actually reads carries the distinction, so the naming
    /// is not confined to an unreachable code path.
    func testTheOverLimitSentenceNamesWhereTheLimitCameFrom() {
        let sourced = oracleLine(bedtimeMg: 150, limit: 100, thresholdName: Sensitivity.low.bedtimeThresholdName)
        XCTAssertTrue(sourced.contains("150mg"))
        XCTAssertTrue(sourced.localizedCaseInsensitiveContains("research"))

        let stricter = oracleLine(bedtimeMg: 150, limit: 25, thresholdName: Sensitivity.high.bedtimeThresholdName)
        XCTAssertTrue(stricter.localizedCaseInsensitiveContains("your stricter"),
                      "a 25 mg limit must read as the reader's choice, got: \(stricter)")

        // The other two states must not acquire the clause: they are not about the wall.
        XCTAssertFalse(oracleLine(bedtimeMg: 20, limit: 100, thresholdName: "").lowercased().contains("research"))
        XCTAssertFalse(oracleLine(bedtimeMg: 70, limit: 100, thresholdName: "").lowercased().contains("research"))
    }

    // MARK: - The dead duplicate copy stays dead

    /// `CaffeineConstants` used to carry `high/medium/lowSensitivityBedtimeMg`
    /// (25 / 50 / 100) — a verbatim restatement of `Sensitivity`'s switch, used by
    /// nothing. A dead copy of a safety number is one edit away from being the live
    /// one, and nothing would announce the change.
    ///
    /// This matches the **declaration**, not every occurrence. A first revision
    /// grepped for the bare symbol and went red on the comment explaining their
    /// removal — which would have made the repo unable to record why they are gone.
    /// What matters is the symbol coming back, not somebody writing it down.
    func testTheDuplicateThresholdConstantsAreGone() throws {
        let source = try String(contentsOf: constantsFileURL(), encoding: .utf8)
        for dead in [
            "highSensitivityBedtimeMg",
            "mediumSensitivityBedtimeMg",
            "lowSensitivityBedtimeMg"
        ] {
            let declaration = "static let \(dead)"
            XCTAssertFalse(
                source.contains(declaration),
                "\(dead) restates Sensitivity.safeCaffeineAtBedtime and belongs nowhere else"
            )
        }
        // The one legitimate constant is still there, and still documented as a
        // fallback rather than a second copy of the tiers.
        XCTAssertTrue(source.contains("static let defaultBedtimeMg"))
        XCTAssertTrue(source.contains("fallback"))
    }

    /// The scan above must actually be able to see a banned symbol. An empty file,
    /// a wrong path or an unreadable encoding would make it pass forever.
    func testTheScanCanSeeASymbolItShould() throws {
        let source = try String(contentsOf: constantsFileURL(), encoding: .utf8)
        XCTAssertTrue(source.contains("enum CaffeineConstants"), "the scan read the real file")
        XCTAssertTrue(source.contains("defaultDoseMg"), "and it can see symbols in it")
    }

    private func constantsFileURL() -> URL {
        // `#filePath` is .../KoffeeTests/Data/BedtimeThresholdProvenanceTests.swift, so
        // three deletions reach the repo root: Data → KoffeeTests → <repo root>.
        //
        // Read via a `throws` test, not `try!`. A scan that silently read nothing
        // would report "no dead symbols" forever — exactly the false green this
        // test exists to prevent, and an earlier revision got the path one deletion
        // short. `try!` crashed there, which is loud, but the repo lint bans it; a
        // throwing test still fails the suite with the error named.
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        url.appendPathComponent("Koffee/Domain/Constants.swift")
        return url
    }
}
