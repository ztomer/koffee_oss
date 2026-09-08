import Foundation
import UserNotifications

/// Caffeine-only reminders: cutoff warning before bed and the morning
/// first-coffee nudge. The former stack / hydration / compound reminders
/// were removed in the coffee-only strip.
class NotificationManager {
    private let notificationCenter = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("Notification permission denied: \(error)")
            return false
        }
    }

    func scheduleCaffeineCutoff(sleepTime: Date, sensitivity: Sensitivity, metabolism: MetabolismRate) async {
        let hoursBeforeBed = sensitivity.hoursBeforeBedForLastDose / metabolism.halfLifeMultiplier
        guard let cutoffTime = Calendar.current.date(byAdding: .hour, value: -Int(hoursBeforeBed), to: sleepTime) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Caffeine Cutoff"
        content.body = "Avoid caffeine after \(formatTime(cutoffTime)) to protect tonight's sleep."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: cutoffTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "koffee.caffeine.cutoff",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule cutoff: \(error)")
        }
    }

    func scheduleMorningWakeUp(wakeTime: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Good Morning"
        content.body = "Time to start your day. First coffee in 90 minutes for optimal cortisol alignment."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: wakeTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "koffee.morning.wakeup",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule wakeup: \(error)")
        }
    }

    func scheduleCaffeineReminder(doseMg: Double, scheduledTime: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Time for coffee"
        content.body = "\(Int(doseMg))mg caffeine scheduled now."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "koffee.caffeine.reminder",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule caffeine reminder: \(error)")
        }
    }

    func cancelAllKoffeeNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let koffeeIds = pending.filter { $0.identifier.hasPrefix("koffee.") }.map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: koffeeIds)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
