import AppIntents

/// Marks a deadline done (or not done) from the widget's row button.
///
/// Must be a member of both the app and widget targets, or the widget button
/// silently does nothing. Runs in whichever process invoked it; saving
/// reloads all widget timelines, so the widget updates immediately.
struct ToggleDoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Deadline Done"
    static let description = IntentDescription("Marks a deadline as done or not done.")
    static let isDiscoverable = false   // internal plumbing, not for Shortcuts

    @Parameter(title: "Deadline ID")
    var id: String

    init() {}

    init(id: UUID) {
        self.id = id.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: id) else {
            return .result()
        }
        let store = DeadlineStore()
        store.toggleDone(id: uuid)
        return .result()
    }
}
