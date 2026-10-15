import Foundation
import UserNotifications

/// Every string this app puts in front of the user from a notification, named.
///
/// K2: these were inline literals in `scheduleMorningWakeUp`, which meant the
/// claim they carried — "first coffee in 90 minutes for optimal cortisol
/// alignment" — could not be asserted on by any test. Copy that cannot be
/// tested is copy that cannot be corrected, and nothing about a string literal
/// records where its claim came from. Naming them is what makes the K2 scan
/// possible; the scan is in `NoPostWakeDelayClaimTests`.
enum NotificationCopy {
    static let morningTitle = "Good Morning"

    /// No delay from waking, and no mechanism. See K2.
    static let morningBody = "Time to start your day."
}

/// Caffeine-only reminders: cutoff warning before bed and the morning
/// first-coffee nudge. The former stack / hydration / compound reminders
/// were removed in the coffee-only strip.
class NotificationManager {
    private let notificationCenter = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            debugLog("Notification permission denied: \(error)")
            return false
        }
    }

    /// Schedules the caffeine cutoff notification.
    ///
    /// K3. `referenceDoseMg` sizes the wall — the day's largest logged dose, so a
    /// 400 mg cold brew draws a much earlier cutoff than a 50 mg tea. The old
    /// signature had no dose at all, which is why the table underneath it was
    /// necessarily dose-blind.
    func scheduleCaffeineCutoff(
        sleepTime: Date,
        sensitivity: Sensitivity,
        metabolism: MetabolismRate,
        referenceDoseMg: Double
    ) async {
        let hoursBeforeBed = sensitivity.hoursBeforeBedForLastDose(
            doseMg: referenceDoseMg,
            halfLifeHours: 5.0 * metabolism.halfLifeMultiplier
        )
        guard let cutoffTime = Calendar.current.date(byAdding: .minute, value: -Int(hoursBeforeBed * 60), to: sleepTime) else { return }

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
            debugLog("Failed to schedule cutoff: \(error)")
        }
    }

    func scheduleMorningWakeUp(wakeTime: Date) async {
        let content = UNMutableNotificationContent()
        content.title = NotificationCopy.morningTitle
        content.body = NotificationCopy.morningBody
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
            debugLog("Failed to schedule wakeup: \(error)")
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
            debugLog("Failed to schedule caffeine reminder: \(error)")
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
