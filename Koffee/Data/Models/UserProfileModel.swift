import Foundation
import GRDB

struct UserProfileModel: FetchableRecord, PersistableRecord, Codable, Identifiable, Equatable {
    static let databaseTableName = "user_profile"

    var id: String
    var weight: Double
    var age: Int
    var heightCm: Double
    var biologicalSex: String
    var sensitivity: String
    var wakeTime: Date
    var sleepTime: Date
    var metabolismRate: String
    var toleranceDaysSinceReset: Int
    var toleranceResetDaysRequired: Int
    var optimizationGoal: String
    var stackCompounds: [String]
    var updatedAt: Date
    var autoRefreshPlan: Bool
    var notificationsEnabled: Bool
    var toleranceAlertsEnabled: Bool

    enum Columns: String, ColumnExpression {
        case id, weight, age, heightCm, biologicalSex, sensitivity
        case wakeTime, sleepTime, metabolismRate
        case toleranceDaysSinceReset, toleranceResetDaysRequired
        case optimizationGoal, stackCompounds, updatedAt, autoRefreshPlan
        case notificationsEnabled, toleranceAlertsEnabled
    }

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id, weight, age
        case heightCm = "height_cm"
        case biologicalSex = "biological_sex"
        case sensitivity
        case wakeTime = "wake_time"
        case sleepTime = "sleep_time"
        case metabolismRate = "metabolism_rate"
        case toleranceDaysSinceReset = "tolerance_days_since_reset"
        case toleranceResetDaysRequired = "tolerance_reset_days_required"
        case optimizationGoal = "optimization_goal"
        case stackCompounds = "stack_compounds"
        case updatedAt = "updated_at"
        case autoRefreshPlan = "auto_refresh_plan"
        case notificationsEnabled = "notifications_enabled"
        case toleranceAlertsEnabled = "tolerance_alerts_enabled"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID.description
    }

    init(
        id: String = UUID().uuidString,
        weight: Double = 70.0,
        age: Int = 30,
        heightCm: Double = 175.0,
        biologicalSex: String = "male",
        sensitivity: String = "medium",
        wakeTime: Date,
        sleepTime: Date,
        metabolismRate: String = "medium",
        toleranceDaysSinceReset: Int = 0,
        toleranceResetDaysRequired: Int = 14,
        optimizationGoal: String = "balanced",
        stackCompounds: [String] = [],
        updatedAt: Date = Date(),
        autoRefreshPlan: Bool = true,
        notificationsEnabled: Bool = true,
        toleranceAlertsEnabled: Bool = true
    ) {
        self.id = id
        self.weight = weight
        self.age = age
        self.heightCm = heightCm
        self.biologicalSex = biologicalSex
        self.sensitivity = sensitivity
        self.wakeTime = wakeTime
        self.sleepTime = sleepTime
        self.metabolismRate = metabolismRate
        self.toleranceDaysSinceReset = toleranceDaysSinceReset
        self.toleranceResetDaysRequired = toleranceResetDaysRequired
        self.optimizationGoal = optimizationGoal
        self.stackCompounds = stackCompounds
        self.updatedAt = updatedAt
        self.autoRefreshPlan = autoRefreshPlan
        self.notificationsEnabled = notificationsEnabled
        self.toleranceAlertsEnabled = toleranceAlertsEnabled
    }
}

extension UserProfileModel: TableRecord {}

struct BeverageModel: FetchableRecord, PersistableRecord, Codable, Identifiable, Equatable {
    static let databaseTableName = "beverages"

    var id: String
    var name: String
    var caffeineMg: Int
    var category: String
    var icon: String
    var sortOrder: Int

    enum Columns: String, ColumnExpression {
        case id, name, caffeineMg, category, icon, sortOrder
    }

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id, name, category, icon
        case caffeineMg = "caffeine_mg"
        case sortOrder = "sort_order"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID.description
    }

    init(id: String = UUID().uuidString, name: String, caffeineMg: Int, category: String, icon: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.caffeineMg = caffeineMg
        self.category = category
        self.icon = icon
        self.sortOrder = sortOrder
    }
}
