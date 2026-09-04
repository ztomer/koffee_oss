import Foundation

struct NotificationItem: Equatable {
    let type: WarningType
    let message: String
    let timeUntil: TimeInterval?
    let shouldWarn: Bool
}
