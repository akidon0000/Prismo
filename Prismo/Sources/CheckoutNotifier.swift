import AppKit
import UserNotifications

enum CheckoutNotifier {
    static func notifySuccess(repository: String, path: String) {
        DispatchQueue.main.async {
            NSApp.requestUserAttention(.informationalRequest)
        }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Checkout 完了"
            content.subtitle = repository
            content.body = path
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "prismo.checkout.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
