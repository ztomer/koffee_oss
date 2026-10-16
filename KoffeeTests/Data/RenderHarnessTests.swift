import XCTest
import LiquidContainer
@testable import Koffee

/// G4 (Phase 0c). The harness exists so a visual change can be seen at native pixels without
/// launching the app over the user's live data — which is exactly how the launch path's data loss
/// (L1) was found. These are its own gates: a surface it cannot draw, a render that is not
/// reproducible, and a picture with nothing in it all fail here, rather than being discovered later
/// as a bad screenshot.
@MainActor
final class RenderHarnessTests: XCTestCase {

    /// The size every surface is drawn at, from the harness.
    private let nativePixels = (wide: 2000, high: 1440)

    /// Renders a surface twice over, so the second render sees the same process the first did.
    ///
    /// When two renders differ, the failure says *where*: a picture that varies only in the clock's
    /// own readout is a different problem from one that varies all over, and the region is what
    /// tells them apart.
    func test_two_renders_of_a_surface_are_the_same_bytes() throws {
        for surface in RenderHarness.Surface.allCases {
            let first = try png(of: surface)
            let second = try png(of: surface)

            XCTAssertEqual(
                first, second,
                "\(surface.rawValue) is not reproducible: \(difference(between: first, and: second))"
            )
        }
    }

    /// The region two renders disagree in, for the failure message above.
    private func difference(between first: Data, and second: Data) -> String {
        guard
            let before = NSBitmapImageRep(data: first),
            let after = NSBitmapImageRep(data: second)
        else { return "one of them is not a PNG" }

        var count = 0
        var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1
        for y in 0..<Swift.min(before.pixelsHigh, after.pixelsHigh) {
            for x in 0..<Swift.min(before.pixelsWide, after.pixelsWide) {
                guard packed(before.colorAt(x: x, y: y)) != packed(after.colorAt(x: x, y: y)) else {
                    continue
                }
                count += 1
                minX = Swift.min(minX, x)
                maxX = Swift.max(maxX, x)
                minY = Swift.min(minY, y)
                maxY = Swift.max(maxY, y)
            }
        }

        guard count > 0 else { return "every pixel agrees, so only the PNG encoding differs" }
        return "\(count) px of \(before.pixelsWide)×\(before.pixelsHigh) differ, "
            + "within x \(minX)–\(maxX), y \(minY)–\(maxY)"
    }

    /// Native pixels, not points: the whole point of the screenshot is to see what the user sees on
    /// the display they have.
    func test_every_surface_in_the_catalog_draws_a_picture_at_native_pixels() throws {
        for surface in RenderHarness.Surface.allCases {
            let representation = NSBitmapImageRep(data: try png(of: surface))
            XCTAssertNotNil(representation, "\(surface.rawValue) did not produce a PNG")
            XCTAssertEqual(representation?.pixelsWide, nativePixels.wide, "\(surface.rawValue) is not at 2x")
            XCTAssertEqual(representation?.pixelsHigh, nativePixels.high, "\(surface.rawValue) is not at 2x")
        }
    }

    /// A file that exists but is one flat colour is not a screenshot of anything: it would satisfy a
    /// "did a PNG appear" check while showing the reader nothing, which is the failure a harness with
    /// no gate of its own ships.
    func test_the_pictures_have_something_in_them() throws {
        for surface in RenderHarness.Surface.allCases {
            let representation = try XCTUnwrap(NSBitmapImageRep(data: try png(of: surface)))
            XCTAssertGreaterThanOrEqual(
                distinctColours(in: representation), 20,
                "\(surface.rawValue) rendered as a flat image"
            )
        }
    }

    /// The script contract: a name outside the catalog is refused, so a typo in a command line is a
    /// non-zero exit rather than a picture of something else. No name at all is the app's own path.
    func test_the_catalog_refuses_a_surface_it_cannot_draw() {
        XCTAssertEqual(RenderHarness.run(surface: "not-a-surface"), 1)
        XCTAssertEqual(RenderHarness.run(surface: nil), 0)
    }

    // MARK: - The bubble layout

    /// The dashboard's bubbles are the one thing in a render that comes from the system's entropy, so
    /// the seed is what makes them the same picture twice. These are the two halves of that claim: the
    /// same seed reproduces the layout, and a different seed does not — without the second half, the
    /// first would pass just as well if the generator ignored the generator it was handed.
    func test_a_seeded_bubble_layout_is_the_same_layout_twice() {
        let first = dashboardBubbles(count: 30, seed: RenderHarness.bubbleSeed)
        let second = dashboardBubbles(count: 30, seed: RenderHarness.bubbleSeed)

        XCTAssertEqual(fingerprint(first), fingerprint(second))
    }

    func test_the_seed_is_what_decides_the_layout() {
        let seeded = dashboardBubbles(count: 30, seed: RenderHarness.bubbleSeed)
        let other = dashboardBubbles(count: 30, seed: RenderHarness.bubbleSeed &+ 1)

        XCTAssertNotEqual(fingerprint(seeded), fingerprint(other))
    }

    /// No seed is the app's own path, which still draws from the system — the same count, in range.
    func test_without_a_seed_the_layout_is_drawn_from_the_system() {
        let bubbles = dashboardBubbles(count: 30, seed: nil)

        XCTAssertEqual(bubbles.count, 30)
        XCTAssertTrue(bubbles.allSatisfy { $0.x >= 20 && $0.baseY >= 20 && $0.size >= 4 })
    }

    private func fingerprint(_ bubbles: [BubbleState]) -> [String] {
        bubbles.map { "\($0.x)|\($0.baseY)|\($0.size)" }
    }

    // MARK: - Helpers

    private func png(of surface: RenderHarness.Surface) throws -> Data {
        let representation = try RenderHarness.render(surface)
        return try XCTUnwrap(representation.representation(using: .png, properties: [:]))
    }

    private func distinctColours(in representation: NSBitmapImageRep) -> Int {
        var colours = Set<UInt32>()
        let stride = 7

        for y in Swift.stride(from: 0, to: representation.pixelsHigh, by: stride) {
            for x in Swift.stride(from: 0, to: representation.pixelsWide, by: stride) {
                guard let colour = packed(representation.colorAt(x: x, y: y)) else { continue }
                colours.insert(colour)
            }
        }
        return colours.count
    }

    /// A pixel as one number, in a fixed colour space, so two of them can be compared directly.
    private func packed(_ colour: NSColor?) -> UInt32? {
        guard let colour = colour?.usingColorSpace(.deviceRGB) else { return nil }
        return UInt32(colour.redComponent * 255) << 16
            | UInt32(colour.greenComponent * 255) << 8
            | UInt32(colour.blueComponent * 255)
    }
}
