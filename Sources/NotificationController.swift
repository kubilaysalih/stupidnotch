import Cocoa
import Combine
import UserNotifications

struct InAppNotification: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let body: String
    let icon: NSImage?
    let timestamp: Date
}

final class NotificationController: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var current: InAppNotification? = nil
    @Published var queue: [InAppNotification] = []
    private var dismissWork: DispatchWorkItem?

    func start() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func stop() {
        UNUserNotificationCenter.current().delegate = nil
    }

    func post(title: String, body: String, icon: NSImage? = nil) {
        let n = InAppNotification(title: title, body: body, icon: icon, timestamp: Date())
        present(n)
    }

    private func present(_ n: InAppNotification) {
        current = n
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.current = nil }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4, execute: work)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let content = notification.request.content
        post(title: content.title, body: content.body)
        completionHandler([.banner, .sound])
    }
}
