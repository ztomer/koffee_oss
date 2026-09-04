import Foundation
import UserNotifications

class NotificationManager {
    private let notificationCenter = UNUserNotificationCenter.current()
    private let optimizer: StackOptimizerEngine

    init(optimizer: StackOptimizerEngine) {
        self.optimizer = optimizer
    }

    func requestPermission() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("Notification permission denied: \(error)")
            return false
        }
    }

    func scheduleRecommendationNotifications(
        recommendations: [ActionableRecommendation],
        goal: OptimizationGoal
    ) async {
        await cancelAllKoffeeNotifications()

        for recommendation in recommendations where recommendation.priority <= 2 {
            guard let scheduledTime = recommendation.scheduledTime else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(recommendation.type.rawValue) \(recommendation.title)"
            content.body = recommendation.message
            content.sound = recommendation.priority == 1 ? .defaultCritical : .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: scheduledTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "koffee.\(recommendation.id.uuidString)",
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
            } catch {
                print("Failed to schedule notification: \(error)")
            }
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

    func scheduleHydrationReminder(deficitMl: Double, intervalMinutes: Int = 60) async {
        guard deficitMl > 200 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Hydration Reminder"
        content.body = "You're \(Int(deficitMl))ml behind. Drink 250ml now."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(intervalMinutes * 60), repeats: true)

        let request = UNNotificationRequest(
            identifier: "koffee.hydration.reminder",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule hydration: \(error)")
        }
    }

    func scheduleCompoundReminder(compound: NootropicCompound, scheduledTime: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Time for \(compound.rawValue)"
        content.body = compound.intendedPurpose
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "koffee.compound.\(compound.rawValue.lowercased())",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule compound: \(error)")
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
