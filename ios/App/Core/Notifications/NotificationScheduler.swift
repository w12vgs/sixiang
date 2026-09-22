import Foundation
import UserNotifications
import SwiftData

/// 本地通知：任务提醒 + 日程提醒（离线可用；APNs 为后续增强）
enum NotificationScheduler {
    static func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// 重建未来 30 天内的全部提醒（同步完成后调用，简单可靠）
    @MainActor
    static func rescheduleAll(context: ModelContext) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let horizon = Date().addingTimeInterval(30 * 24 * 3600)

        if let tasks = try? context.fetch(FetchDescriptor<TaskItem>()) {
            for task in tasks where task.deletedAt == nil && task.completedAt == nil {
                guard let remind = task.reminderAt, remind > Date(), remind < horizon else { continue }
                add(identifier: "task-\(task.id)", title: task.title, body: "任务提醒", date: remind)
            }
        }

        if let events = try? context.fetch(FetchDescriptor<EventItem>()) {
            for event in events where event.deletedAt == nil {
                guard event.startAt > Date(), event.startAt < horizon else { continue }
                let offset = TimeInterval(-(event.remindOffsetMinutes ?? 0) * 60)
                let remindAt = event.startAt.addingTimeInterval(offset)
                guard remindAt > Date() else { continue }
                add(
                    identifier: "event-\(event.id)",
                    title: event.title,
                    body: event.location.isEmpty ? "日程提醒" : "📍 \(event.location)",
                    date: remindAt
                )
            }
        }
    }

    private static func add(identifier: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
