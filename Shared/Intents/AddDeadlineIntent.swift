import AppIntents
import Foundation

/// Adds a deadline from Spotlight or Shortcuts without opening a window.
///
/// Runs in the app process (launched in the background if needed), so the
/// app's `DeadlineStore.onSave` hook refreshes the UI and reschedules
/// notifications.
struct AddDeadlineIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Deadline"
    static let description = IntentDescription("Adds a new deadline with the default reminders.")
    static let openAppWhenRun = false

    @Parameter(title: "Title")
    var name: String

    @Parameter(title: "Due")
    var due: Date

    @Parameter(title: "Link")
    var link: URL?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$name) due \(\.$due)") {
            \.$link
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = DeadlineStore()
        store.add(Deadline(
            title: name,
            due: due,
            url: link,
            notifyOffsets: Deadline.Offset.loadDefaults()
        ))
        let dueText = due.formatted(date: .abbreviated, time: .shortened)
        return .result(dialog: "Added “\(name)”, due \(dueText).")
    }
}
