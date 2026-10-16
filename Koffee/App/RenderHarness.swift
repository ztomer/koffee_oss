import AppKit
import Foundation
import GRDB
import SwiftUI

/// A seedable generator, so a render's bubbles are the same every time.
///
/// `Int.random` draws from the system's entropy, which made the bubble layout the one part of a
/// dashboard render that differed between two runs of the same surface. SplitMix64 is the standard
/// tiny generator for exactly this: a fixed seed, a fixed sequence, no state beyond one word.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// G4 (Phase 0c). "User-POV screenshot at native pixels for every visual change" is a standing
/// constraint that had nothing behind it: there was no render path in the repo, so the only way to
/// take one was to launch the app on top of the owner's own data.
///
///     KOFFEE_RENDER=<surface> KOFFEE_RENDER_OUT=out.png .build/…/Koffee.app/Contents/MacOS/Koffee
///
/// One surface, headless — no window is shown and `app.run()` is never reached — deterministic, and
/// written to the path you pass in at native pixels. The fixture is built in an in-memory database,
/// so a render never reads or writes the user's file.
///
/// What it must never claim: the animated liquid. A render is one instant of it, and the physics
/// engine is drawn from rest.
enum RenderHarness {

    /// The surfaces the harness can draw. A catalog, so a surface is one case and one fixture.
    enum Surface: String, CaseIterable {
        /// The dashboard: the plan's first item at wake (K2) and the bedtime sentence (K4).
        case dashboard
        /// The notifications preview: the dose-dependent cutoff line (K3).
        case notifications
    }

    /// Set to a `Surface`'s raw value to draw that surface and exit.
    static var requestedSurface: String? {
        ProcessInfo.processInfo.environment["KOFFEE_RENDER"]
    }

    /// True in a process asked to draw a surface rather than to run the app.
    static var isRendering: Bool { requestedSurface != nil }

    /// `BubbleGenerator` otherwise lays its bubbles out with `Int.random`; while rendering they come
    /// from this seed, so two renders of one surface are byte-identical.
    static let bubbleSeed: UInt64 = 0x5EED_0FFEE

    /// The bubble seed for a render, or `nil` in the app — which keeps drawing from the system's
    /// entropy, as it always has.
    static var bubbleSeedWhenRendering: UInt64? {
        isRendering ? bubbleSeed : nil
    }

    /// Where the PNG goes: `KOFFEE_RENDER_OUT`, or a file in the temporary directory.
    static var outputURL: URL {
        let path = ProcessInfo.processInfo.environment["KOFFEE_RENDER_OUT"]
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("koffee-render.png").path
        return URL(fileURLWithPath: path)
    }

    /// Twelve hours into the fixture's day — the instant the surfaces' existing exhibits were drawn
    /// and verified at, and the one an unqualified render uses.
    ///
    /// Noon because it is a state with something in it: the plan's first item is still ahead of the
    /// clock (K2's row) and the day's logged dose is behind it (the tank is not a picture of nothing
    /// by accident). This is a real `Date()` read — the harness's, to pick which day to draw — and one
    /// of the two the seam's check allows.
    static var defaultInstant: Date {
        DateHelper.calendar.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
    }

    /// `KOFFEE_RENDER_AT=HH:MM`, on the day `day` falls in.
    ///
    /// The clock seam makes a render a function of an instant rather than of when you ran it, so the
    /// human workflow gets to name the instant: "the 200mg dose is in the tank" is a change you draw
    /// at 16:00 rather than a change you edit code for.
    ///
    /// - Returns: `nil` when the value is not a time, so `run` can refuse it the way it refuses a
    ///   surface that is not in the catalog.
    static func instant(from raw: String, on day: Date) -> Date? {
        let parts = raw.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return DateHelper.calendar.startOfDay(for: day).addingTimeInterval(Double(hour * 3600 + minute * 60))
    }

    /// The instant a `run` asks for: `KOFFEE_RENDER_AT` if it is set and parses, else `defaultInstant`.
    /// A value that does not parse is an error, not a silent noon.
    static func resolveInstant(_ raw: String?) -> Result<Date, BadInstant> {
        guard let raw else { return .success(defaultInstant) }
        guard let instant = instant(from: raw, on: Date()) else {
            return .failure(BadInstant(raw: raw))
        }
        return .success(instant)
    }

    static var requestedInstant: Result<Date, BadInstant> {
        resolveInstant(ProcessInfo.processInfo.environment["KOFFEE_RENDER_AT"])
    }

    /// A `KOFFEE_RENDER_AT` that is not a time. Its own type so the refusal cannot be mistaken for a
    /// surface that failed to draw.
    struct BadInstant: Error {
        let raw: String
    }

    /// Draws the requested surface.
    ///
    /// - Returns: the status the process should exit with — 0 when a PNG was written, 1 when the
    ///   request could not be answered (a surface that is not in the catalog, a `KOFFEE_RENDER_AT`
    ///   that is not a time, or a failure drawing it), so a caller scripting this can tell "wrote the
    ///   picture" from "did not".
    @MainActor
    static func run() -> Int32 {
        run(surface: requestedSurface)
    }

    /// The body of `run`, taking the name as an argument so a test can ask for a surface — or for one
    /// that does not exist — without setting the environment of the test runner.
    @MainActor
    static func run(surface name: String?) -> Int32 {
        guard let name else { return 0 }

        guard let surface = Surface(rawValue: name) else {
            warn("no surface named '\(name)'. Known: \(Surface.allCases.map(\.rawValue).joined(separator: ", "))")
            return 1
        }

        let instant: Date
        switch requestedInstant {
        case .success(let requested):
            instant = requested
        case .failure(let bad):
            warn("KOFFEE_RENDER_AT must be HH:MM, not '\(bad.raw)'")
            return 1
        }

        // Views want an application behind them: fonts, appearance, colour spaces. Accessory, so a
        // render never takes the foreground from whatever the owner is doing.
        _ = NSApplication.shared
        NSApplication.shared.setActivationPolicy(.accessory)

        do {
            let rep = try render(surface, at: instant)
            try write(rep, to: outputURL)
            debugLog("koffee-render: wrote \(surface.rawValue) at \(instant) to \(outputURL.path)")
            return 0
        } catch {
            warn("\(name) failed: \(error)")
            return 1
        }
    }

    // MARK: - Drawing

    /// Native pixels: 2× the point size, which is what the displays in this estate use.
    private static let scale: CGFloat = 2
    private static let size = NSSize(width: 1000, height: 720)

    /// Draws a surface at the default instant.
    @MainActor
    static func render(_ surface: Surface) throws -> NSBitmapImageRep {
        try render(surface, at: defaultInstant)
    }

    /// Draws a surface with the clock frozen at `instant`, and restores what it found.
    ///
    /// The freeze is what makes two renders comparable: every "when is now" read in the app state and
    /// the views goes through `DateHelper`, so with the instant pinned the picture depends on the
    /// fixture and the instant and on nothing else — not on how many seconds apart the two draws were,
    /// and not on which side of a 30-minute sample the second hand was on.
    @MainActor
    static func render(_ surface: Surface, at instant: Date) throws -> NSBitmapImageRep {
        let previous = DateHelper.pinnedNow
        DateHelper.pinnedNow = instant
        defer { DateHelper.pinnedNow = previous }

        switch surface {
        case .dashboard:
            let fixture = try Fixture.overBedtimeLimit()
            return try draw(
                DashboardView(
                    appState: fixture.state,
                    columnVisibility: .constant(.all),
                    physicsEngine: SharedPhysicsEngine(),
                    window: nil
                )
                .frame(width: size.width, height: size.height)
            )
        case .notifications:
            let fixture = try Fixture.cutoffDay()
            return try draw(
                NotificationsView(appState: fixture.state)
                    .frame(width: size.width, height: size.height)
            )
        }
    }

    /// Draws a view off-screen. The window is never shown and never ordered front — it exists so the
    /// view has a window and a backing scale to lay itself out against.
    @MainActor
    private static func draw(_ view: some View) throws -> NSBitmapImageRep {
        // Animations are off for a render: the banner's icon bounces when its status changes, which
        // it does as the fixture's state lands, and a snapshot taken mid-bounce is a different picture
        // each time. This is the harness's business, not the product's.
        let hosting = NSHostingView(rootView: view.transaction { $0.disablesAnimations = true })
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // Pinned light: on a dark-mode Mac the appearance would be the variable, not the change.
        window.appearance = NSAppearance(named: .aqua)
        // Opaque: an off-screen window has no backdrop, and a material in the view would otherwise be
        // blurring whatever happens to be behind the window — which made one circled element's rim
        // differ by one unit between two renders of the same surface.
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))

        settle { hosting.layoutSubtreeIfNeeded() }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { throw Failure.noBitmap }
        // Points, not pixels: the 2× pixel grid is a 2× scale rather than a window twice the size.
        rep.size = size

        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        return rep
    }

    /// Lets SwiftUI lay out and deliver its published values before the pixels are taken. The state
    /// is read through repositories whose publishers reach `AppState` on the main queue, so a render
    /// that skipped this would draw the empty state.
    private static func settle(_ during: () -> Void) {
        during()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        during()
    }

    static func write(_ rep: NSBitmapImageRep, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let png = rep.representation(using: .png, properties: [:]) else { throw Failure.noPNG }
        try png.write(to: url)
    }

    private static func warn(_ message: String) {
        FileHandle.standardError.write(Data("koffee-render: \(message)\n".utf8))
    }

    enum Failure: Error {
        case noBitmap
        case noPNG
    }

    // MARK: - The fixture

    /// A surface's inputs: an in-memory database, so a render never touches the user's file, and
    /// explicit rows, so what is drawn is the fixture's rather than the plan engine's.
    ///
    /// The rows are written through the same repositories the app uses and read back through
    /// `AppState`, so a surface shows the app's own derivation from these numbers.
    struct Fixture {
        let state: AppState
        let wakeTime: Date
        let sleepTime: Date

        static let sensitivity = "medium"
        static let metabolism = "medium"

        /// A medium reader on a 95 mg day with nothing pending: the state K3's cutoff line is quoted
        /// for (23:00 bedtime, a 95 mg reference dose).
        @MainActor
        static func cutoffDay() throws -> Fixture {
            try make(doses: [(hoursAfterWake: 1.5, mg: 95)], planDoseMg: nil)
        }

        /// A medium reader whose projected bedtime level is over their stricter 50 mg threshold, with
        /// the plan's first item still ahead: the state K2's row and K4's sentence are about.
        @MainActor
        static func overBedtimeLimit() throws -> Fixture {
            try make(doses: [(hoursAfterWake: 8, mg: 200)], planDoseMg: 95)
        }

        @MainActor
        private static func make(
            doses: [(hoursAfterWake: Double, mg: Double)],
            planDoseMg: Double?
        ) throws -> Fixture {
            let day = DateHelper.startOfDay()
            let wakeTime = DateHelper.calendar.date(byAdding: .hour, value: 7, to: day)!
            let sleepTime = DateHelper.calendar.date(byAdding: .hour, value: 23, to: day)!

            let db = try DatabaseQueue()
            try DatabaseManager.makeMigrator().migrate(db)

            try db.write { db in
                try UserProfileModel(
                    sensitivity: sensitivity,
                    wakeTime: wakeTime,
                    sleepTime: sleepTime,
                    metabolismRate: metabolism,
                    stackCompounds: [NootropicCompound.caffeine.rawValue]
                ).save(db)

                for dose in doses {
                    try DoseModel(
                        timestamp: wakeTime.addingTimeInterval(dose.hoursAfterWake * 3600),
                        caffeineMg: dose.mg,
                        beverageName: "Coffee"
                    ).save(db)
                }

                if let planDoseMg {
                    try DailyPlanItemModel(
                        compoundUuid: NootropicCompound.caffeine.rawValue,
                        dayKey: DailyPlanItemModel.dayKey(for: day),
                        compoundName: NootropicCompound.caffeine.rawValue,
                        doseMg: planDoseMg,
                        scheduledTime: wakeTime
                    ).save(db)
                }
            }

            let state = AppState(
                profileRepo: UserProfileRepository(db: db),
                doseRepo: DoseRepository(db: db),
                beverageRepo: BeverageRepository(db: db),
                planRepo: DailyPlanRepository(db: db)
            )

            return Fixture(state: state, wakeTime: wakeTime, sleepTime: sleepTime)
        }
    }
}
