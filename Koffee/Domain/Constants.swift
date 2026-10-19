import Foundation

// MARK: - Time Constants
enum TimeConstants {
    static let secondsPerMinute: TimeInterval = 60
    static let halfHourSeconds: TimeInterval = 1800
    static let secondsPerHour: TimeInterval = 3600
    static let twoHourSeconds: TimeInterval = 7200
    static let fourHourSeconds: TimeInterval = 14400
    static let sevenHourSeconds: TimeInterval = 25200
    static let pKStepSeconds: TimeInterval = 300
    static let pKIntervalSeconds: TimeInterval = halfHourSeconds
    static let competitionWindowSeconds: TimeInterval = secondsPerHour
    static let absorptionWindowSeconds: TimeInterval = twoHourSeconds

    static let defaultWakeHour: Int = 7
    static let defaultSleepHour: Int = 23

    /// A profile-less reader's wake and sleep, as 07:00 and 23:00 *today*.
    ///
    /// Computed rather than stored, because they are derived from the clock: a `static let` would
    /// evaluate `DateHelper.now` once, at whatever instant first touched it, and hold that day's date
    /// for the life of the process — the same class of mistake as half a model being derived and half
    /// being frozen. The clock seam (G4's limit) is why this is visible at all: nothing reads them yet,
    /// and the one that did would have read a date rather than an hour.
    static var defaultWakeTime: Date? {
        Calendar.current.date(bySettingHour: defaultWakeHour, minute: 0, second: 0, of: DateHelper.now)
    }

    static var defaultSleepTime: Date? {
        Calendar.current.date(bySettingHour: defaultSleepHour, minute: 0, second: 0, of: DateHelper.now)
    }
}

// K5. `MathConstants` (halfLifeDecayFactor, recoveryPenalty, lTheanineRatio,
// deepSleepMinimumMinutes, sleepScoreThreshold, lowSleepScoreThreshold) and
// `PKEngineeringConstants` (michaelisConstantKm, maxEliminationRateVmax) both
// stood here with zero readers between them. They are deleted rather than
// emptied: an empty enum is a second version of the same mistake, and
// `InteractionExtensionRefutedTests` refuses the names -- and the enum
// declarations -- coming back.
//
// `lTheanineRatio` deserves its note, because it is the reason this matters. It
// encoded theanine at 1.5x caffeine, half of the theanine-extends-caffeine model
// the audit refuted (Grzegorzewski 2022: theanine has no CYP1A2 effect). A
// constant nobody reads is still a claim the codebase is willing to make.

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

    /// The bedtime threshold used when there is no profile to read one from.
    ///
    /// K4. This is a FALLBACK for a reader who has not said anything about
    /// themselves — it is not a second copy of `Sensitivity.safeCaffeineAtBedtime`.
    /// Until 2026-10-15 this enum also carried `high/medium/lowSensitivityBedtimeMg`
    /// (25 / 50 / 100), which restated that switch verbatim and were used by
    /// nothing at all. They are gone, and `BedtimeThresholdProvenanceTests` refuses
    /// them returning: a dead copy of a safety number is one edit away from being
    /// the live one, and nothing would announce it.
    ///
    /// 50 mg here rather than 100 mg is deliberate — conservative in the direction
    /// the standing rule permits, matching koffee_big's fallback.
    static let defaultBedtimeMg: Double = 50

    /// The adult daily ceiling, mg. EFSA 2015: single doses up to 200 mg and a
    /// daily total up to 400 mg for healthy adults. This is a POPULATION safety
    /// limit, so nothing in this app may raise it -- not a sensitivity setting,
    /// not a weight, not a declared habit (roadmap K1).
    static let dailyCeilingMg: Double = 400

    /// The level at which the app calls the day caffeine-free, in mg.
    ///
    /// P1. Caffeine never reaches zero -- the decay is exponential -- so "caffeine-free"
    /// has to mean a line, and this is the line: **1 mg is the app's own reporting
    /// resolution** (the dashboard prints milligrams as whole numbers, so below this the
    /// level reads 0). It is a display convention, NOT a pharmacological threshold, and the
    /// copy that shows the forecast names it ("under 1mg") so the sentence cannot be read
    /// as a stronger claim than it is.
    ///
    /// Declared once: the derivation and the copy read this, so the forecast's meaning
    /// cannot drift between them.
    static let caffeineFreeThresholdMg: Double = 1.0

    static let compoundIdPrefix: String = "CAFFEINE"
    static let caffeineCompoundUuid: String = "caffeine"
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
