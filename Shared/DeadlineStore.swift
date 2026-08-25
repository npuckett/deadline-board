import Foundation
import Observation
import WidgetKit

/// Loads and saves `deadlines.json` in the App Group container.
///
/// The app holds an observable instance. The widget, which runs briefly and
/// exits, uses the static `load(from:)` instead of instantiating the class.
@Observable
final class DeadlineStore {
    private(set) var deadlines: [Deadline]

    private let fileURL: URL
    private let reloadsWidgets: Bool

    /// - Parameters:
    ///   - fileURL: override in tests to avoid the App Group container.
    ///   - reloadsWidgets: false in tests so saving doesn't touch WidgetCenter.
    init(fileURL: URL = AppGroup.storeURL, reloadsWidgets: Bool = true) {
        self.fileURL = fileURL
        self.reloadsWidgets = reloadsWidgets
        self.deadlines = Self.load(from: fileURL)
    }

    /// Not-done deadlines sorted by due date ascending. Overdue items sort
    /// first rather than disappearing, so nothing is silently lost.
    var upcoming: [Deadline] {
        deadlines.filter { !$0.isDone }.sorted { $0.due < $1.due }
    }

    var done: [Deadline] {
        deadlines.filter(\.isDone).sorted { $0.due > $1.due }
    }

    func add(_ deadline: Deadline) {
        deadlines.append(deadline)
        save()
    }

    func update(_ deadline: Deadline) {
        guard let index = deadlines.firstIndex(where: { $0.id == deadline.id }) else { return }
        deadlines[index] = deadline
        save()
    }

    func remove(id: UUID) {
        deadlines.removeAll { $0.id == id }
        save()
    }

    func toggleDone(id: UUID) {
        guard let index = deadlines.firstIndex(where: { $0.id == id }) else { return }
        deadlines[index].isDone.toggle()
        save()
    }

    func deadline(id: UUID) -> Deadline? {
        deadlines.first { $0.id == id }
    }

    func save() {
        do {
            let data = try Self.encoder.encode(deadlines)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save deadlines: \(error)")
            return
        }
        if reloadsWidgets {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func load(from url: URL = AppGroup.storeURL) -> [Deadline] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try decoder.decode([Deadline].self, from: data)
        } catch {
            assertionFailure("Failed to decode deadlines: \(error)")
            return []
        }
    }

    /// Same filtering and sorting as `upcoming`, for use with a static load.
    static func upcoming(in deadlines: [Deadline]) -> [Deadline] {
        deadlines.filter { !$0.isDone }.sorted { $0.due < $1.due }
    }

    // ISO 8601 dates keep the JSON file human-readable. Note this truncates
    // sub-second precision, which is irrelevant for deadlines.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
