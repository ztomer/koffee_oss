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

    // MARK: - The clock

    /// The same two halves as the bubble seed, for the clock: a pinned instant reproduces the picture,
    /// and a different one does not — without the second half the first would pass just as well if the
    /// render ignored the pin and drew the wall clock.
    ///
    /// The two instants straddle the dashboard fixture's own dose, which it logs eight hours after its
    /// 07:00 wake: at 12:00 that 200mg is still ahead of the clock, at 16:00 it is in the tank.
    func test_the_pinned_clock_is_what_decides_the_picture() throws {
        let day = RenderHarness.defaultInstant
        let ahead = try XCTUnwrap(RenderHarness.instant(from: "12:00", on: day))
        let behind = try XCTUnwrap(RenderHarness.instant(from: "16:00", on: day))

        let atAhead = try png(of: .dashboard, at: ahead)
        let atBehind = try png(of: .dashboard, at: behind)
        let atBehindAgain = try png(of: .dashboard, at: behind)

        XCTAssertNotEqual(
            atAhead, atBehind,
            "the render ignored the pinned clock: 12:00 and 16:00 drew the same picture"
        )
        XCTAssertEqual(
            atBehind, atBehindAgain,
            "a pinned instant is not reproducible: \(difference(between: atBehind, and: atBehindAgain))"
        )
    }

    /// The script contract for the other variable: a time that is not a time is refused rather than
    /// quietly becoming noon, so `KOFFEE_RENDER_AT=16h` cannot pass as an evening screenshot.
    func test_a_render_at_that_is_not_a_time_is_refused() {
        let day = DateHelper.calendar.startOfDay(for: RenderHarness.defaultInstant)

        XCTAssertNil(RenderHarness.instant(from: "25:00", on: day))
        XCTAssertNil(RenderHarness.instant(from: "12", on: day))
        XCTAssertNil(RenderHarness.instant(from: "noon", on: day))
        XCTAssertNil(RenderHarness.instant(from: "16:70", on: day))
        XCTAssertEqual(
            RenderHarness.instant(from: "16:30", on: day),
            day.addingTimeInterval(16 * 3600 + 30 * 60)
        )

        guard case .failure = RenderHarness.resolveInstant("sixteen") else {
            return XCTFail("a bad KOFFEE_RENDER_AT resolved instead of failing")
        }
        guard case .success(let defaulted) = RenderHarness.resolveInstant(nil) else {
            return XCTFail("no KOFFEE_RENDER_AT should resolve to the default instant")
        }
        XCTAssertEqual(defaulted, RenderHarness.defaultInstant)
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
        try png(of: surface, at: RenderHarness.defaultInstant)
    }

    private func png(of surface: RenderHarness.Surface, at instant: Date) throws -> Data {
        let representation = try RenderHarness.render(surface, at: instant)
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
