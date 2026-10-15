import Foundation

// MARK: - PK Curve Generation

private enum PKConstants {
    static let confidenceVariance: Double = 0.15
    static let highConfidenceZScore: Double = 1.96
    static let standardConfidenceZScore: Double = 1.645
    static let highConfidenceThreshold: Double = 0.9
}

func generateCurvePoints(
    doses: [(Date, Double)],
    from startTime: Date,
    to endTime: Date,
    metabolism: MetabolismRate = .medium
) -> [PKCurvePoint] {
    var points: [PKCurvePoint] = []
    var currentTime = startTime

    while currentTime <= endTime {
        let level = calculateCaffeineLevel(doses: doses, at: currentTime, metabolism: metabolism)
        let band = calculateConfidenceBand(doses: doses, at: currentTime, metabolism: metabolism)

        points.append(PKCurvePoint(
            time: currentTime,
            expected: level,
            upper: band.upper,
            lower: band.lower
        ))

        currentTime = currentTime.addingTimeInterval(1800)
    }

    return points
}

func calculateCaffeineLevel(
    doses: [(Date, Double)],
    at targetTime: Date,
    halfLife: Double = 5.0,
    metabolism: MetabolismRate = .medium
) -> Double {
    // One model, the one the evidence supports: exponential decay at
    // `halfLife`, lengthened for a slow metaboliser and shortened for a fast one.
    //
    // K5. This used to take a fifth parameter -- an array of (hours, description)
    // pairs -- and lengthened the half-life by the hours in it. The model it
    // encoded was theanine-extends-caffeine, which the audit koffee_oss was forked
    // BEFORE REFUTED (Grzegorzewski 2022: theanine has no CYP1A2 effect, so it
    // cannot change caffeine's clearance).
    //
    // The coffee-only strip had already removed every caller, so the parameter was
    // dead -- but "dead" understates an unused parameter. It is a seam: the next
    // compound added to the stack would find a hand-hold for extending caffeine's
    // half-life and nothing recording that the model behind it was wrong. Deleting
    // it is how the refutation survives.
    //
    // The parameter is deliberately NOT named here. `InteractionExtensionRefutedTests`
    // requires the identifier to be absent from the file entirely, including in
    // prose, because a comment that spells the signature is a template for putting
    // it back. A refutation is described; a rejected API is not transcribed.
    let effectiveHalfLife = halfLife * metabolism.halfLifeMultiplier

    var total: Double = 0.0
    for (doseTime, amount) in doses {
        guard doseTime <= targetTime else { continue }
        let hoursElapsed = targetTime.timeIntervalSince(doseTime) / 3600
        let remaining = amount * pow(0.5, hoursElapsed / effectiveHalfLife)
        total += remaining
    }
    return total
}

/// THE bedtime-projection funnel. Every surface that shows "caffeine at
/// bedtime" (toolbar, dashboard oracle, history) must call this — never a
/// local heuristic. Day-boundary handling: when sleep is at/before wake
/// (overnight schedule), both move a day forward; doses logged before wake
/// belong to the coming day.
func projectBedtimeCaffeine(
    doses: [(Date, Double)],
    wakeTime: Date,
    sleepTime: Date,
    metabolism: MetabolismRate = .medium
) -> Double {
    var adjustedSleepTime = sleepTime
    if sleepTime <= wakeTime {
        adjustedSleepTime = Calendar.current.date(byAdding: .day, value: 1, to: sleepTime) ?? sleepTime
    }

    var adjustedDoses: [(Date, Double)] = []
    for (doseTime, amount) in doses {
        guard amount > 0 else { continue }
        var t = doseTime
        if t <= wakeTime {
            t = Calendar.current.date(byAdding: .day, value: 1, to: t) ?? t
        }
        adjustedDoses.append((t, amount))
    }

    return calculateCaffeineLevel(doses: adjustedDoses, at: adjustedSleepTime, metabolism: metabolism)
}

func calculateConfidenceBand(
    doses: [(Date, Double)],
    at targetTime: Date,
    confidenceLevel: Double = 0.95,
    metabolism: MetabolismRate = .medium
) -> (expected: Double, upper: Double, lower: Double) {
    let expected = calculateCaffeineLevel(doses: doses, at: targetTime, metabolism: metabolism)

    let variance = expected * PKConstants.confidenceVariance
    let zScore = confidenceLevel > PKConstants.highConfidenceThreshold
        ? PKConstants.highConfidenceZScore
        : PKConstants.standardConfidenceZScore

    return (
        expected: expected,
        upper: min(expected + (variance * zScore), expected * 2),
        lower: max(expected - (variance * zScore), 0)
    )
}

func calculateOptimalFocusWindow(
    doses: [(Date, Double)],
    threshold: Double = 50.0
) -> FocusWindow? {
    guard !doses.isEmpty else { return nil }

    let sortedDoses = doses.sorted { $0.0 < $1.0 }
    let firstDose = sortedDoses[0]

    let peakTime = firstDose.0.addingTimeInterval(3600)
    let peakLevel = calculateCaffeineLevel(doses: doses, at: peakTime)

    var windowEnd = firstDose.0.addingTimeInterval(3600 * 4)

    while calculateCaffeineLevel(doses: doses, at: windowEnd) > threshold {
        windowEnd = windowEnd.addingTimeInterval(1800)
        if windowEnd.timeIntervalSince(firstDose.0) > 3600 * 12 {
            break
        }
    }

    return FocusWindow(
        start: firstDose.0.addingTimeInterval(1800),
        end: windowEnd,
        peakLevel: peakLevel
    )
}

// MARK: - Unified Curve Generation

func generateUnifiedCurvePoints(
    doses: [(Date, Double)],
    from startTime: Date,
    to endTime: Date,
    metabolism: MetabolismRate = .medium
) -> [UnifiedCurvePoint] {
    debugLog("generateUnifiedCurvePoints: \(doses.count) doses, start=\(startTime), end=\(endTime)")
    for (t, m) in doses {
        debugLog("  input dose: time=\(t.timeIntervalSince1970), mg=\(m)")
    }

    var points: [UnifiedCurvePoint] = []
    var currentTime = startTime

    // Chart what the caller passed - no wall-clock filtering here. The old
    // `$0.0 <= now` filter made this pure function clock-dependent and
    // silently dropped planned/future doses the caller asked to display.
    let caffeineDoses = doses.filter { _, mg in mg <= 150 }
    debugLog("  caffeine for calc: \(caffeineDoses.count)/\(doses.count)")

    while currentTime <= endTime {
        let caffeineLevel = calculateCaffeineLevel(doses: caffeineDoses, at: currentTime, metabolism: metabolism)

        points.append(UnifiedCurvePoint(
            time: currentTime,
            compoundLevels: ["Caffeine": caffeineLevel],
            totalLevel: caffeineLevel
        ))

        currentTime = currentTime.addingTimeInterval(1800)
    }

    return points
}

func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}
