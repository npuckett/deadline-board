import SwiftUI

@main
struct DeadlinesApp: App {
    @State private var store = DeadlineStore()

    var body: some Scene {
        MenuBarExtra("Deadlines", systemImage: "calendar.badge.clock") {
            MenuBarContent(store: store)
        }

        Window("Deadlines", id: "editor") {
            EditorView(store: store)
        }
        .defaultSize(width: 480, height: 520)
    }
}

/// Menu bar dropdown. Phase 4 fills this out with the next three deadlines,
/// Add Deadline… (⌘N), and Settings….
struct MenuBarContent: View {
    let store: DeadlineStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(store.upcoming.prefix(3)) { deadline in
            Text("\(deadline.title)  —  \(Countdown.label(from: Date(), to: deadline.due))")
        }
        if !store.upcoming.isEmpty {
            Divider()
        }
        Button("Open Editor…") {
            openWindow(id: "editor")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit Deadlines") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
