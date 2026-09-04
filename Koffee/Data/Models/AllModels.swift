import Foundation
import GRDB

enum PlanItemStatus: String, Codable, DatabaseValueConvertible {
    case pending
    case taken
    case skipped
    case optimizedAway
}

enum PlanItemSource: String, Codable, DatabaseValueConvertible {
    case baseStack
    case optimizer
    case manual
    case optimizerReplacement
}

struct DoseModel: FetchableRecord, PersistableRecord, Codable, Identifiable, Equatable {
    static let databaseTableName = "doses"

    var id: String
    var beverageId: String?
    var timestamp: Date
    var caffeineMg: Double
    var beverageName: String?
    var compoundUuid: String?
    var isPlanItem: Bool = false

    enum Columns: String, ColumnExpression {
        case id, beverageId, timestamp, caffeineMg, beverageName, compoundUuid, isPlanItem
    }

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case beverageId = "beverage_id"
        case timestamp
        case caffeineMg = "caffeine_mg"
        case beverageName = "beverage_name"
        case compoundUuid = "compound_uuid"
        case isPlanItem = "is_plan_item"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID.description
    }

    init(id: String = UUID().uuidString, beverageId: String? = nil, timestamp: Date, caffeineMg: Double,
         beverageName: String? = nil, compoundUuid: String? = nil, isPlanItem: Bool = false) {
        self.id = id
        self.beverageId = beverageId
        self.timestamp = timestamp
        self.caffeineMg = caffeineMg
        self.beverageName = beverageName
        self.compoundUuid = compoundUuid
        self.isPlanItem = isPlanItem
    }
}

struct SupplementLogModel: FetchableRecord, PersistableRecord, Codable, Identifiable, Equatable {
    static let databaseTableName = "supplement_logs"

    var id: String
    var compoundName: String
    var timestamp: Date
    var status: PlanItemStatus

    enum Columns: String, ColumnExpression {
        case id, compoundName, timestamp, status
    }

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case compoundName = "compound_name"
        case timestamp
        case status
    }

    init(id: String = UUID().uuidString, compoundName: String, timestamp: Date = Date(), status: PlanItemStatus = .taken) {
        self.id = id
        self.compoundName = compoundName
        self.timestamp = timestamp
        self.status = status
    }
}

struct HydrationEntryModel: FetchableRecord, PersistableRecord, Codable, Identifiable, Equatable {
    static let databaseTableName = "hydration_entries"

    var id: String
    var amountMl: Double
    var timestamp: Date

    enum Columns: String, ColumnExpression {
        case id, amountMl, timestamp
    }

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case amountMl = "amount_ml"
        case timestamp
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID.description
    }

    init(id: String = UUID().uuidString, amountMl: Double, timestamp: Date = Date()) {
        self.id = id
        self.amountMl = amountMl
        self.timestamp = timestamp
    }
}

struct ExerciseLogModel: FetchableRecord, PersistableRecord, Codable, Identifiable, Equatable {
    static let databaseTableName = "exercise_logs"

    var id: String
    var activityName: String
    var timestamp: Date
    var durationMinutes: Int?

    enum Columns: String, ColumnExpression {
        case id, activityName, timestamp, durationMinutes
    }

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case activityName = "activity_name"
        case timestamp
        case durationMinutes = "duration_minutes"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID.description
    }

    init(id: String = UUID().uuidString, activityName: String, timestamp: Date = Date(), durationMinutes: Int? = nil) {
        self.id = id
        self.activityName = activityName
        self.timestamp = timestamp
        self.durationMinutes = durationMinutes
    }
}

struct DailyPlanItemModel: Identifiable, Equatable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "daily_plan_items"

    var id: String
    var compoundUuid: String
    var dayKey: String
    var compoundName: String
    var doseMg: Double
    var source: PlanItemSource
    var status: PlanItemStatus
    var scheduledTime: Date
    var actualTakenTime: Date?
    var nutritionTemplateId: String?
    var exerciseTemplateId: String?
    var quantity: Double

    enum Columns: String, ColumnExpression {
        case id, compoundUuid, dayKey, compoundName, doseMg, source, status, scheduledTime, actualTakenTime
        case nutritionTemplateId, exerciseTemplateId, quantity
    }

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case compoundUuid = "compound_uuid"
        case dayKey = "day_key"
        case compoundName = "compound_name"
        case doseMg = "dose_mg"
        case source
        case status
        case scheduledTime = "scheduled_time"
        case actualTakenTime = "actual_taken_time"
        case nutritionTemplateId = "nutrition_template_id"
        case exerciseTemplateId = "exercise_template_id"
        case quantity
    }

    init(
        id: String = UUID().uuidString,
        compoundUuid: String,
        dayKey: String,
        compoundName: String,
        doseMg: Double = 0,
        source: PlanItemSource = .baseStack,
        status: PlanItemStatus = .pending,
        scheduledTime: Date,
        actualTakenTime: Date? = nil,
        nutritionTemplateId: String? = nil,
        exerciseTemplateId: String? = nil,
        quantity: Double = 1.0
    ) {
        self.id = id
        self.compoundUuid = compoundUuid
        self.dayKey = dayKey
        self.compoundName = compoundName
        self.doseMg = doseMg
        self.source = source
        self.status = status
        self.scheduledTime = scheduledTime
        self.actualTakenTime = actualTakenTime
        self.nutritionTemplateId = nutritionTemplateId
        self.exerciseTemplateId = exerciseTemplateId
        self.quantity = quantity
    }

    // Convenience initializer for test compatibility
    init(
        id: String = UUID().uuidString,
        compoundName: String,
        scheduledTime: Date,
        status: PlanItemStatus,
        dayKey: String,
        compoundUuid: String? = nil,
        doseMg: Double = 0
    ) {
        self.id = id
        self.compoundUuid = compoundUuid ?? compoundName.lowercased()
        self.dayKey = dayKey
        self.compoundName = compoundName
        self.doseMg = doseMg
        self.source = .baseStack
        self.status = status
        self.scheduledTime = scheduledTime
        self.actualTakenTime = nil
        self.nutritionTemplateId = nil
        self.exerciseTemplateId = nil
        self.quantity = 1.0
    }

    static func == (lhs: DailyPlanItemModel, rhs: DailyPlanItemModel) -> Bool {
        lhs.id == rhs.id &&
        lhs.compoundUuid == rhs.compoundUuid &&
        lhs.dayKey == rhs.dayKey &&
        lhs.compoundName == rhs.compoundName &&
        lhs.doseMg == rhs.doseMg &&
        lhs.source == rhs.source &&
        lhs.status == rhs.status &&
        lhs.scheduledTime == rhs.scheduledTime &&
        lhs.actualTakenTime == rhs.actualTakenTime
    }

    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct NutritionTemplateModel: FetchableRecord, PersistableRecord, Codable, Identifiable, Equatable {
    static let databaseTableName = "nutrition_templates"

    var id: String
    var externalDbId: String?
    var name: String
    var category: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double
    var isAbsorptionBlocker: Bool
    var requiresFastedState: Bool

    enum Columns: String, ColumnExpression {
        case id, externalDbId, name, category, calories, proteinG, carbsG, fatG, fiberG
        case isAbsorptionBlocker, requiresFastedState
    }

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case externalDbId = "external_db_id"
        case name
        case category
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case isAbsorptionBlocker = "is_absorption_blocker"
        case requiresFastedState = "requires_fasted_state"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID.description
    }

    init(
        id: String = UUID().uuidString,
        externalDbId: String? = nil,
        name: String,
        category: String,
        calories: Double = 0,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        fiberG: Double = 0,
        isAbsorptionBlocker: Bool = false,
        requiresFastedState: Bool = false
    ) {
        self.id = id
        self.externalDbId = externalDbId
        self.name = name
        self.category = category
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.isAbsorptionBlocker = isAbsorptionBlocker
        self.requiresFastedState = requiresFastedState
    }
}

struct ExerciseTemplateModel: FetchableRecord, PersistableRecord, Codable, Identifiable, Equatable {
    static let databaseTableName = "exercise_templates"

    var id: String
    var externalDbId: String?
    var name: String
    var category: String
    var caloriesPerHour: Double
    var requiresFastedState: Bool

    enum Columns: String, ColumnExpression {
        case id, externalDbId, name, category, caloriesPerHour, requiresFastedState
    }

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case externalDbId = "external_db_id"
        case name
        case category
        case caloriesPerHour = "calories_per_hour"
        case requiresFastedState = "requires_fasted_state"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID.description
    }

    init(
        id: String = UUID().uuidString,
        externalDbId: String? = nil,
        name: String,
        category: String,
        caloriesPerHour: Double = 0,
        requiresFastedState: Bool = false
    ) {
        self.id = id
        self.externalDbId = externalDbId
        self.name = name
        self.category = category
        self.caloriesPerHour = caloriesPerHour
        self.requiresFastedState = requiresFastedState
    }
}

struct DailyBiometricsModel: FetchableRecord, PersistableRecord, Codable, Identifiable, Equatable {
    static let databaseTableName = "daily_biometrics"

    var id: String
    var sleepScore: Double?
    var deepSleepMinutes: Int?
    var remSleepMinutes: Int?
    var restingHeartRate: Double?
    var heartRateVariability: Double?
    var source: String
    var lastSyncedAt: Date

    enum Columns: String, ColumnExpression {
        case id, sleepScore, deepSleepMinutes, remSleepMinutes
        case restingHeartRate, heartRateVariability, source, lastSyncedAt
    }

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case sleepScore = "sleep_score"
        case deepSleepMinutes = "deep_sleep_minutes"
        case remSleepMinutes = "rem_sleep_minutes"
        case restingHeartRate = "resting_heart_rate"
        case heartRateVariability = "heart_rate_variability"
        case source
        case lastSyncedAt = "last_synced_at"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID.description
    }

    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    init(
        id: String,
        sleepScore: Double? = nil,
        deepSleepMinutes: Int? = nil,
        remSleepMinutes: Int? = nil,
        restingHeartRate: Double? = nil,
        heartRateVariability: Double? = nil,
        source: String = "Manual",
        lastSyncedAt: Date = Date()
    ) {
        self.id = id
        self.sleepScore = sleepScore
        self.deepSleepMinutes = deepSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.restingHeartRate = restingHeartRate
        self.heartRateVariability = heartRateVariability
        self.source = source
        self.lastSyncedAt = lastSyncedAt
    }
}
