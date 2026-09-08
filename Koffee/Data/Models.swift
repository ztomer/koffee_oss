import Foundation

// MARK: - Caffeine Protocol

struct CaffeineProtocol {
    struct RecalculationResult {
        let dailySchedule: [Dose]
        let pkCurve: PKCurveData
        let adjustedHalfLife: Double
        let notifications: [NotificationItem]
    }

    struct PKCurveData {
        let points: [PKCurvePoint]
        let totalAreaUnderCurve: Double
        let optimalWindow: FocusWindow?
    }
}

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
    metabolism: MetabolismRate = .medium,
    interactions: [(extensionHours: Double, description: String)] = []
) -> Double {
    let effectiveHalfLife = halfLife * metabolism.halfLifeMultiplier

    // Apply interaction extensions - reduce the decay rate when interactions are active
    let totalExtension = interactions.reduce(0.0) { $0 + $1.extensionHours }
    let decayMultiplier = totalExtension > 0 ? (halfLife + totalExtension) / halfLife : 1.0

    var total: Double = 0.0
    for (doseTime, amount) in doses {
        guard doseTime <= targetTime else { continue }
        let hoursElapsed = targetTime.timeIntervalSince(doseTime) / 3600
        let extendedHalfLife = effectiveHalfLife * decayMultiplier
        let remaining = amount * pow(0.5, hoursElapsed / extendedHalfLife)
        total += remaining
    }
    return total
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

// MARK: - Caffeine Calculator Core

func calculateOptimal(
    weightKg: Double,
    wakeTime: Date,
    sleepTime: Date,
    sensitivity: Sensitivity
) -> CaffeineResult {
    let kgToLbs: Double = 2.20462
    let maxDailyCaffeineMg: Double = 400.0
    let mgCaffeinePerLb: Double = 2.72
    let caffeineHalfLifeHours: Double = 5.0
    let caffeineDelayAfterWakeMinutes: Double = 90
    _ = caffeineHalfLifeHours
    let minDoseIntervalHours: Double = 4.0

    let weightLbs = weightKg * kgToLbs
    let baseLimit = min(weightLbs * mgCaffeinePerLb, maxDailyCaffeineMg)
    let dailyLimit = baseLimit * sensitivity.multiplier

    var adjustedSleepTime = sleepTime
    if sleepTime <= wakeTime {
        adjustedSleepTime = Calendar.current.date(byAdding: .day, value: 1, to: sleepTime) ?? sleepTime
    }

    let safeAtBedtime = sensitivity.safeCaffeineAtBedtime
    let bufferHours = sensitivity.hoursBeforeBedForLastDose

    guard let latestSafeTime = Calendar.current.date(
        byAdding: .hour,
        value: -Int(bufferHours),
        to: adjustedSleepTime
    ) else {
        return emptyCaffeineResult(dailyLimit: dailyLimit, sensitivity: sensitivity, sleepTime: adjustedSleepTime)
    }

    guard let firstDoseTime = Calendar.current.date(
        byAdding: .minute,
        value: Int(caffeineDelayAfterWakeMinutes),
        to: wakeTime
    ) else {
        return emptyCaffeineResult(dailyLimit: dailyLimit, sensitivity: sensitivity, sleepTime: adjustedSleepTime)
    }

    guard latestSafeTime > firstDoseTime else {
        return emptyCaffeineResult(dailyLimit: dailyLimit, sensitivity: sensitivity, sleepTime: adjustedSleepTime)
    }

    guard let secondDoseTime = Calendar.current.date(
        byAdding: .hour,
        value: -2,
        to: latestSafeTime
    ) else {
        return emptyCaffeineResult(dailyLimit: dailyLimit, sensitivity: sensitivity, sleepTime: adjustedSleepTime)
    }

    let hoursBetweenDoses = secondDoseTime.timeIntervalSince(firstDoseTime) / 3600
    let secondDoseAvailable = hoursBetweenDoses >= minDoseIntervalHours

    var doses: [(Date, Double)] = []

    if secondDoseAvailable {
        let firstAmount = dailyLimit * 0.4
        let secondAmount = dailyLimit * 0.6
        doses.append((firstDoseTime, firstAmount))
        doses.append((secondDoseTime, secondAmount))
    } else {
        let singleDose = dailyLimit * 0.6
        doses.append((firstDoseTime, singleDose))
    }

    if doses.isEmpty {
        return emptyCaffeineResult(dailyLimit: dailyLimit, sensitivity: sensitivity, sleepTime: adjustedSleepTime)
    }

    doses.sort { $0.0 < $1.0 }

    let firstDose = Dose(
        time: doses.count > 0 ? doses[0].0 : nil,
        amount: doses.count > 0 ? doses[0].1 : 0
    )
    let secondDose = Dose(
        time: doses.count > 1 ? doses[1].0 : nil,
        amount: doses.count > 1 ? doses[1].1 : 0
    )
    let thirdDose = Dose(time: nil, amount: 0)

    let latestSafeCaffeineTime = formatTime(latestSafeTime)

    var warnings: [String] = []
    let caffeineAtBedtime = calculateCaffeineAtTime(
        doses: doses.map { ($0.0, $0.1) },
        targetTime: adjustedSleepTime
    )

    if caffeineAtBedtime > safeAtBedtime {
        warnings.append("For \(sensitivity.displayName.lowercased()) sensitivity, keep caffeine under \(Int(safeAtBedtime))mg "
                     + "at bedtime. Current plan leaves ~\(Int(caffeineAtBedtime))mg.")
    }

    return CaffeineResult(
        dailyLimit: dailyLimit,
        firstDose: firstDose,
        secondDose: secondDose,
        thirdDose: thirdDose,
        warnings: warnings,
        latestSafeCaffeineTime: latestSafeCaffeineTime
    )
}

private func emptyCaffeineResult(dailyLimit: Double, sensitivity: Sensitivity, sleepTime: Date) -> CaffeineResult {
    let latestSafeTime = Calendar.current.date(
        byAdding: .hour,
        value: -Int(sensitivity.hoursBeforeBedForLastDose),
        to: sleepTime
    )
    return CaffeineResult(
        dailyLimit: dailyLimit,
        firstDose: Dose(),
        secondDose: Dose(),
        thirdDose: Dose(),
        warnings: [],
        latestSafeCaffeineTime: latestSafeTime.map { formatTime($0) } ?? nil
    )
}

func calculateCaffeineAtTime(doses: [(Date, Double)], targetTime: Date, halfLife: Double = 5.0) -> Double {
    var total: Double = 0.0
    for (doseTime, amount) in doses {
        guard doseTime <= targetTime else { continue }
        let hoursElapsed = targetTime.timeIntervalSince(doseTime) / 3600
        let remaining = amount * pow(0.5, hoursElapsed / halfLife)
        total += remaining
    }
    return total
}

func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}
