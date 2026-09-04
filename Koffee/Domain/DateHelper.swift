import Foundation

enum DateHelper {
    static var calendar: Calendar { Calendar.current }

    static var now: Date { Date() }

    static func startOfDay(for date: Date = Date()) -> Date {
        calendar.startOfDay(for: date)
    }

    static func endOfDay(for date: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: 1, to: startOfDay(for: date))!
    }

    static func date(byAddingMinute value: Int, to date: Date) -> Date? {
        calendar.date(byAdding: .minute, value: value, to: date)
    }

    static func date(byAddingHour value: Int, to date: Date) -> Date? {
        calendar.date(byAdding: .hour, value: value, to: date)
    }

    static func date(bySettingHour hour: Int, minute: Int, second: Int, of date: Date) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: second, of: date)
    }

    static func hour(of date: Date) -> Int {
        calendar.component(.hour, from: date)
    }

    static func dayKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func date(from dayKey: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayKey)
    }
}
