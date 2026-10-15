import XCTest
@testable import Koffee
import Foundation

// K5 (roadmap Phase 0b): the theanine-extends-caffeine model, and the constants
// that died beside it.
//
// `calculateCaffeineLevel(interactions:)` lengthened caffeine's half-life by
// `extensionHours`. The claim it encoded -- that theanine extends caffeine's
// action -- was REFUTED by the audit koffee_oss was forked before
// (Grzegorzewski 2022: theanine has no CYP1A2 effect, so it cannot change
// caffeine's clearance).
//
// The coffee-only strip removed every compound but caffeine, so nothing passes
// `interactions:` any more. That makes it dead, but "dead" understates it: an
// unused parameter is a seam. The next compound added to the stack would find a
// hand-hold labelled "extension hours" and no note saying the model was wrong.
// Deleting it is the only way the refutation survives.
//
// What died with it: `MathConstants` in its entirety and `PKEngineeringConstants`
// in its entirety -- eight constants, zero readers between them.
final class InteractionExtensionRefutedTests: XCTestCase {

    private func source(_ relativePath: String) throws -> String {
        // .../KoffeeTests/Data/ -> three deletions reach the repo root.
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        url.appendPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// The parameter, its machinery, and the entire enum it lived in.
    ///
    /// Matches the identifier anywhere rather than a declaration pattern, because
    /// here the point really is that the *name* must be gone: `extensionHours` is
    /// not a thing that may be spelled in a comment and merely undeclared. It is a
    /// claim the evidence refuted, and a comment inviting the next reader to
    /// reinstate it is how it comes back.
    func testTheRefutedModelIsGoneFromTheSource() throws {
        let models = try source("Koffee/Data/Models.swift")
        for banned in ["extensionHours", "interactions:"] {
            XCTAssertFalse(
                models.contains(banned),
                "\(banned) is the refuted theanine-extension seam; it must be deleted, "
                    + "not left unused"
            )
        }
        // The parameter must not be silently re-added as a default.
        XCTAssertFalse(models.contains("extension"))
    }

    /// Eight constants, zero readers. Deleted, and refused a return.
    func testTheDeadConstantsAreGoneFromTheSource() throws {
        let constants = try source("Koffee/Domain/Constants.swift")
        for dead in [
            "halfLifeDecayFactor",
            "recoveryPenalty",
            "lTheanineRatio",
            "deepSleepMinimumMinutes",
            "sleepScoreThreshold",
            "lowSleepScoreThreshold",
            "michaelisConstantKm",
            "maxEliminationRateVmax"
        ] {
            XCTAssertFalse(
                constants.contains("static let \(dead)"),
                "\(dead) has no readers; a live-looking constant with no consumer is "
                    + "an invitation to use it"
            )
        }
        // Both enum bodies are gone ENTIRELY, not merely emptied of members: an
        // empty enum is a second version of the same mistake.
        XCTAssertFalse(constants.contains("enum MathConstants {"))
        XCTAssertFalse(constants.contains("enum PKEngineeringConstants {"))
    }

    /// The scan above must actually be able to see a symbol. An empty file, a wrong
    /// path or an unreadable encoding would make every assertion pass forever.
    func testTheScanCanSeeWhatItIsLookingFor() throws {
        let models = try source("Koffee/Data/Models.swift")
        XCTAssertTrue(models.contains("func calculateCaffeineLevel"),
                      "the scan read the real file, and the function is still there")
        XCTAssertTrue(models.contains("halfLife * metabolism.halfLifeMultiplier"),
                      "the model it carries is the one the evidence supports")
    }

    /// The behaviour the seam was wrong about, asserted directly: a compound that
    /// has no CYP1A2 effect must not change caffeine's half-life. This is the
    /// refutation stated as code, so reintroducing the parameter fails here too.
    func testAnInteractionCannotLengthenTheHalfLife() {
        let dose = 200.0
        let taken = Date(timeIntervalSinceNow: -5 * 3600)       // exactly one half-life ago
        let doses: [(Date, Double)] = [(taken, dose)]
        let at = Date()
        // With a 5 h half-life, one half-life elapsed leaves half the dose. There is
        // no second argument that may move this.
        let level = calculateCaffeineLevel(doses: doses, at: at, halfLife: 5.0)
        XCTAssertEqual(level, 100.0, accuracy: 0.001)
        XCTAssertNotEqual(level, dose, "the interaction model must not exist to be wrong")
    }
}
