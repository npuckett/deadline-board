import Foundation

struct Deadline: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var due: Date
    var url: URL?
    var notifyOffsets: [TimeInterval]   // seconds before due, e.g. 7 days, 1 day, 2 hours
    var isDone: Bool = false
    var createdAt: Date = Date()
}

extension Deadline {
    /// Common notification offsets offered in the UI, in seconds before due.
    enum Offset {
        static let fourteenDays: TimeInterval = 14 * 24 * 3600
        static let sevenDays: TimeInterval = 7 * 24 * 3600
        static let threeDays: TimeInterval = 3 * 24 * 3600
        static let oneDay: TimeInterval = 24 * 3600
        static let twelveHours: TimeInterval = 12 * 3600
        static let twoHours: TimeInterval = 2 * 3600
        static let oneHour: TimeInterval = 3600

        /// Everything offered in settings and the form.
        static let all: [TimeInterval] = [
            fourteenDays, sevenDays, threeDays, oneDay, twelveHours, twoHours, oneHour,
        ]

        /// Shipped defaults: 7 days, 1 day, 2 hours.
        static let defaults: [TimeInterval] = [sevenDays, oneDay, twoHours]
    }

    /// Plausible sample data for widget gallery placeholders and previews.
    static func samples(relativeTo now: Date = Date()) -> [Deadline] {
        [
            Deadline(
                title: "CHI paper submission",
                due: now.addingTimeInterval(9 * 3600),
                url: URL(string: "https://chi.acm.org"),
                notifyOffsets: Offset.defaults
            ),
            Deadline(
                title: "Grant report draft",
                due: now.addingTimeInterval(3 * 24 * 3600 + 5 * 3600),
                url: nil,
                notifyOffsets: Offset.defaults
            ),
            Deadline(
                title: "Ars Electronica open call",
                due: now.addingTimeInterval(12 * 24 * 3600 + 4 * 3600),
                url: URL(string: "https://ars.electronica.art"),
                notifyOffsets: Offset.defaults
            ),
        ]
    }
}
