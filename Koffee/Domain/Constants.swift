import Foundation

// MARK: - Time Constants
enum TimeConstants {
    static let secondsPerMinute: TimeInterval = 60
    static let halfHourSeconds: TimeInterval = 1800
    static let secondsPerHour: TimeInterval = 3600
    static let twoHourSeconds: TimeInterval = 7200
    static let fourHourSeconds: TimeInterval = 14400
    static let sevenHourSeconds: TimeInterval = 25200
    static let firstDoseDelaySeconds: TimeInterval = 5400
    static let pKStepSeconds: TimeInterval = 300
    static let pKIntervalSeconds: TimeInterval = halfHourSeconds
    static let competitionWindowSeconds: TimeInterval = secondsPerHour
    static let absorptionWindowSeconds: TimeInterval = twoHourSeconds

    static let defaultWakeHour: Int = 7
    static let defaultSleepHour: Int = 23
    static let defaultWakeTime: Date? = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())
    static let defaultSleepTime: Date? = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())
}

// MARK: - Math Constants
enum MathConstants {
    static let halfLifeDecayFactor: Double = 0.5
    static let recoveryPenalty: Double = 0.7
    static let lTheanineRatio: Double = 1.5
    static let deepSleepMinimumMinutes: Double = 60
    static let sleepScoreThreshold: Double = 70
    static let lowSleepScoreThreshold: Double = 65
}

// MARK: - PK Engineering Constants
enum PKEngineeringConstants {
    static let michaelisConstantKm: Double = 150.0
    static let maxEliminationRateVmax: Double = 50.0
}

// MARK: - Chart Constants
enum ChartConstants {
    static let yAxisMinimum: Double = 30
    static let safeLimitLine: Double = 100
    static let sleepReadyThreshold: Double = 0.5
    static let warningThreshold: Double = 0.8
    static let criticalThreshold: Double = 0.95
}

// MARK: - UI Constants
enum UIConstants {
    static let meterSectionHeight: CGFloat = 180
    static let buttonSize: CGFloat = 44
    static let iconSize: CGFloat = 36
}

// MARK: - Status Strings
enum StatusConstants {
    static let pending: String = "pending"
    static let completed: String = "completed"
    static let optimizedAway: String = "optimizedAway"
    static let skipped: String = "skipped"
}

// MARK: - Source Strings
enum SourceConstants {
    static let baseStack: String = "baseStack"
    static let manual: String = "manual"
    static let optimizer: String = "optimizer"
}

// MARK: - Repository Constants
enum RepositoryConstants {
    static let maxCaffeinePerDose: Double = 1000
}

// MARK: - Caffeine Constants
enum CaffeineConstants {
    static let defaultDoseMg: Double = 95
    static let highSensitivityBedtimeMg: Double = 25
    static let mediumSensitivityBedtimeMg: Double = 50
    static let lowSensitivityBedtimeMg: Double = 100
    static let defaultBedtimeMg: Double = 50

    static let compoundIdPrefix: String = "CAFFEINE"
    static let caffeineCompoundUuid: String = "caffeine"
}

// MARK: - Optimization Constants
enum OptimizationConstants {
    static let defaultGoal: String = "balanced"
    static let balanced: String = "balanced"
    static let focus: String = "focus"
    static let sleep: String = "sleep"
    static let energy: String = "energy"

    static let allGoals: [String] = [balanced, focus, sleep, energy]
}

// MARK: - Compound Helpers
extension NootropicCompound {
    var isCaffeine: Bool { self == .caffeine }

    static func from(uuid: String) -> NootropicCompound? {
        allCases.first { $0.rawValue.lowercased() == uuid.lowercased() }
    }
}

func isCaffeineCompound(uuid: String) -> Bool {
    uuid.lowercased() == CaffeineConstants.caffeineCompoundUuid
}
