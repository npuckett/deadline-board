import SwiftUI
import UserNotifications

/// UI navigation state shared between the menu bar, deep links, and the editor.
@Observable
final class AppNavigation {
    var selectedDeadlineID: UUID?
    var showingAddSheet = false
}

/// Handles notification taps by routing through the same deadlines:// deep
/// link path as the widget rows.
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let id = response.notification.request.content.userInfo["deadlineID"] as? String,
              let url = URL(string: "deadlines://open/\(id)")
        else { return }
        NSWorkspace.shared.open(url)
    }
}

@main
struct DeadlinesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: DeadlineStore
    @State private var navigation = AppNavigation()

    init() {
        let store = DeadlineStore()
        _store = State(initialValue: store)
        // Refresh the app's instance and rebuild notifications whenever any
        // store in this process saves (the AddDeadlineIntent writes through
        // its own instance).
        DeadlineStore.onSave = { [weak store] in
            Task { @MainActor in
                guard let store else { return }
                store.reload()
                await NotificationScheduler.shared.rescheduleAll(deadlines: store.deadlines)
            }
        }
        Task { @MainActor [weak store] in
            await NotificationScheduler.shared.setUp()
            if let store {
                await NotificationScheduler.shared.rescheduleAll(deadlines: store.deadlines)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra("Deadlines", systemImage: "calendar.badge.clock") {
            MenuBarContent(store: store, navigation: navigation)
        }

        Window("Deadlines", id: "editor") {
            EditorView(store: store, navigation: navigation)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .defaultSize(width: 480, height: 520)
        // Routes deadlines:// URLs here, opening the window if needed.
        .handlesExternalEvents(matching: ["deadlines"])

        Settings {
            SettingsView()
        }
    }

    /// `deadlines://open/<uuid>`: open the deadline's link in the browser, or
    /// select it in the editor if it has none. `deadlines://add`: add sheet.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "deadlines" else { return }
        switch url.host() {
        case "open":
            let uuidString = url.lastPathComponent
            guard let id = UUID(uuidString: uuidString),
                  let deadline = store.deadline(id: id)
            else { return }
            if let link = deadline.url {
                NSWorkspace.shared.open(link)
            } else {
                navigation.selectedDeadlineID = id
                NSApp.activate(ignoringOtherApps: true)
            }
        case "add":
            navigation.showingAddSheet = true
            NSApp.activate(ignoringOtherApps: true)
        default:
            break
        }
    }
}

struct MenuBarContent: View {
    let store: DeadlineStore
    let navigation: AppNavigation
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // .menu style: keep to simple Button/Text rows only.
        ForEach(store.upcoming.prefix(3)) { deadline in
            Text("\(deadline.title)  —  \(Countdown.label(from: Date(), to: deadline.due))")
        }
        if !store.upcoming.isEmpty {
            Divider()
        }
        Button("Add Deadline…") {
            navigation.showingAddSheet = true
            openWindow(id: "editor")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("n")
        Button("Open Editor…") {
            openWindow(id: "editor")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Deadlines") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
