import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notifyDisconnect(deviceName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Scooter Disconnected"
        content.body = "\(deviceName) has disconnected."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func notifyLowBattery(percent: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Low Battery"
        content.body = "Battery at \(percent)%. Consider charging soon."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "low-battery",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
