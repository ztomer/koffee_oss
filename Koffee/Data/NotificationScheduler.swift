import Foundation

// MARK: - Notification Scheduler

struct NotificationScheduler {
    static func calculateCutoffTime(
        sleepTime: Date,
        sensitivity: Sensitivity,
        metabolism: MetabolismRate,
        doses: [(Date, Double)]
    ) -> Date? {
        let baseHalfLife = sensitivity.hoursBeforeBedForLastDose
        let effectiveHalfLife = baseHalfLife / metabolism.halfLifeMultiplier

        guard let cutoff = Calendar.current.date(
            byAdding: .hour,
            value: -Int(effectiveHalfLife),
            to: sleepTime
        ) else { return nil }

        return cutoff
    }

    static func createFocusWindowNotification(
        optimalDoseTime: Date,
        recommendedDose: Double,
        beverage: String
    ) -> NotificationItem? {
        let now = Date()
        let minutesUntil = optimalDoseTime.timeIntervalSince(now) / 60

        guard minutesUntil > 0 && minutesUntil < 60 else { return nil }

        let message = "\(Int(minutesUntil)) mins until optimal focus window. Consider \(Int(recommendedDose))mg \(beverage)."

        return NotificationItem(
            type: .focusWindowOpening,
            message: message,
            timeUntil: minutesUntil * 60,
            shouldWarn: true
        )
    }

    static func calculateDynamicLimitWarning(
        currentLoad: Double,
        dailyLimit: Double,
        activeMetabolism: Double = 0
    ) -> NotificationItem {
        let projectedBedtime = currentLoad + activeMetabolism
        let warningThreshold = dailyLimit * 0.8
        let criticalThreshold = dailyLimit * 0.95

        if projectedBedtime >= criticalThreshold {
            return NotificationItem(
                type: .approachingLimit,
                message: "Critical: Approaching daily limit. Current load: \(Int(currentLoad))mg",
                timeUntil: nil,
                shouldWarn: true
            )
        } else if projectedBedtime >= warningThreshold {
            return NotificationItem(
                type: .approachingLimit,
                message: "Warning: Approaching \(Int((currentLoad/dailyLimit)*100))% of daily limit",
                timeUntil: nil,
                shouldWarn: true
            )
        }

        return NotificationItem(
            type: .approachingLimit,
            message: "",
            timeUntil: nil,
            shouldWarn: false
        )
    }

    static func calculateRiskLevel(
        caffeineAtBedtime: Double,
        safeLimit: Double,
        currentLoad: Double,
        dailyLimit: Double,
        weightKg: Double
    ) -> RiskLevel {
        _ = caffeineAtBedtime / max(safeLimit, 1)
        let dailyRatio = currentLoad / max(dailyLimit, 1)
        let mgPerKg = weightKg > 0 ? currentLoad / weightKg : 0

        if caffeineAtBedtime > safeLimit * 1.5 || mgPerKg > 8 || dailyRatio > 1.0 {
            return .critical
        } else if caffeineAtBedtime > safeLimit || mgPerKg > 6 || dailyRatio > 0.9 {
            return .high
        } else if caffeineAtBedtime > safeLimit * 0.5 || mgPerKg > 4 || dailyRatio > 0.7 {
            return .medium
        } else {
            return .low
        }
    }
}
