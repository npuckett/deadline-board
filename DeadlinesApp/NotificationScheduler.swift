import Foundation
import Observation
import UserNotifications

/// Schedules local notifications for deadline reminders. Only the host app
/// schedules — widget extensions cannot use UNUserNotificationCenter.
@MainActor
@Observable
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    static let identifierPrefix = "deadline."
    static let categoryID = "deadline"
    static let openLinkActionID = "openLink"

    /// Surfaced in Settings so the user can see if permission was denied.
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    /// Called once at launch: registers the category and requests
    /// authorization on first run.
    func setUp() async {
        let openLink = UNNotificationAction(identifier: Self.openLinkActionID, title: "Open Link")
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [openLink],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])

        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        return granted
    }

    /// Removes all pending requests with our identifier prefix and rebuilds
    /// from the current store. Rebuilding from scratch is simpler and safer
    /// than diffing; done or deleted deadlines drop out automatically.
    func rescheduleAll(deadlines: [Deadline]) async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let now = Date()
        for deadline in deadlines where !deadline.isDone {
            for offset in deadline.notifyOffsets {
                let fireDate = deadline.due.addingTimeInterval(-offset)
                guard fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = deadline.title
                content.body = body(due: deadline.due, fireDate: fireDate)
                content.sound = .default
                content.categoryIdentifier = Self.categoryID
                content.userInfo = ["deadlineID": deadline.id.uuidString]

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: fireDate
                )
                let request = UNNotificationRequest(
                    identifier: "\(Self.identifierPrefix)\(deadline.id.uuidString).\(Int(offset))",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
                try? await center.add(request)
            }
        }
    }

    /// "Due in 2 hours", "Due tomorrow" — natural phrasing from the relative
    /// distance between the fire date and the due date.
    private func body(due: Date, fireDate: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return "Due \(formatter.localizedString(for: due, relativeTo: fireDate))"
    }
}
