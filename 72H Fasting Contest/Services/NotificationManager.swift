import Foundation
import UserNotifications

final class NotificationManager {
    func requestAuthorizationIfNeeded() async {
        do {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("Notification authorization failed: \(error)")
        }
    }

    func scheduleFastNotifications(from startDate: Date, preferences: NotificationPreferences) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: scheduledIdentifiers)
        guard preferences.remindersEnabled || preferences.milestoneNotificationsEnabled else { return }

        if preferences.remindersEnabled {
            var hour = preferences.reminderIntervalHours
            while hour < 72 {
                schedule(
                    id: "reminder-\(hour)",
                    title: hour.isMultiple(of: preferences.reminderIntervalHours * 2) ? "Check how you feel." : "Remember to drink water.",
                    secondsFromStart: TimeInterval(hour * 3600),
                    startDate: startDate
                )
                hour += preferences.reminderIntervalHours
            }
        }

        if preferences.milestoneNotificationsEnabled {
            schedule(id: "milestone-24", title: "You reached 24H.", secondsFromStart: 24 * 3600, startDate: startDate)
            schedule(id: "milestone-48", title: "You reached 48H.", secondsFromStart: 48 * 3600, startDate: startDate)
            schedule(id: "milestone-72", title: "You reached 72H.", secondsFromStart: 72 * 3600, startDate: startDate)
        }
    }

    func cancelFastNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: scheduledIdentifiers)
    }

    private var scheduledIdentifiers: [String] {
        (1...72).flatMap { ["reminder-\($0)", "milestone-\($0)"] }
    }

    private func schedule(id: String, title: String, secondsFromStart: TimeInterval, startDate: Date) {
        let fireDate = startDate.addingTimeInterval(secondsFromStart)
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "72H Fasting Contest"
        content.body = title
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
