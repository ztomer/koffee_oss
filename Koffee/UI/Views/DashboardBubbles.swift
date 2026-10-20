import LiquidContainer

// The dashboard's bubbles: how many of them, and where they sit.
//
// Cut out of DashboardView.swift for the 500-line cap. Both are pure, and both are
// read by tests: the count scales with the fill, the layout is seeded while a render
// is drawing so two screenshots of the same surface agree.

/// Idle bubble count scales with fill ratio using the existing generator.
/// Pure for testing: 20 empty … 40 full.
func bubbleCount(forFillRatio ratio: Double) -> Int {
    let clamped = min(max(ratio, 0), 1)
    return 20 + Int((clamped * 20).rounded())
}

/// The dashboard's bubbles.
///
/// While `KOFFEE_RENDER` is set they are drawn from a fixed seed, because `BubbleGenerator`'s layout
/// is the one thing in a dashboard render that comes from the system's entropy — two screenshots of
/// the same surface would otherwise differ only in where the bubbles sit. The app is unchanged: it
/// draws from the system, as before.
///
/// The seed is a parameter rather than a read of the environment so the seeded layout can be tested
/// for what it claims (the same seed twice is the same layout) in a process that is not rendering.
func dashboardBubbles(count: Int, seed: UInt64?) -> [BubbleState] {
    guard let seed else {
        return BubbleGenerator.generate(count: count, width: 400, height: 300)
    }
    var generator = SeededRandomNumberGenerator(seed: seed)
    return BubbleGenerator.generate(count: count, width: 400, height: 300, using: &generator)
}
