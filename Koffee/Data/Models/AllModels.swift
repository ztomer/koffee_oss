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
    case manual
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
    var quantity: Double

    enum Columns: String, ColumnExpression {
        case id, compoundUuid, dayKey, compoundName, doseMg, source, status, scheduledTime, actualTakenTime
        case quantity
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
