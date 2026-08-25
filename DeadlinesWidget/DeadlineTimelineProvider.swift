import WidgetKit

/// Produces entries covering every moment the display changes: one per hour
/// for the next 24 hours, plus one just after each due date in that window so
/// the switch to overdue happens on time. All entries share the same deadline
/// array — countdowns are computed in the view from the entry date.
///
/// Kept synchronous and light (a single JSON read): widget extension
/// processes are killed quickly.
struct DeadlineTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeadlineEntry {
        DeadlineEntry(date: Date(), deadlines: Deadline.samples())
    }

    func getSnapshot(in context: Context, completion: @escaping (DeadlineEntry) -> Void) {
        let deadlines = context.isPreview
            ? Deadline.samples()
            : DeadlineStore.upcoming(in: DeadlineStore.load())
        completion(DeadlineEntry(date: Date(), deadlines: deadlines))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeadlineEntry>) -> Void) {
        let deadlines = DeadlineStore.upcoming(in: DeadlineStore.load())
        let now = Date()
        let windowEnd = now.addingTimeInterval(24 * 3600)

        var dates: Set<Date> = []
        for hour in 0...24 {
            dates.insert(now.addingTimeInterval(TimeInterval(hour) * 3600))
        }
        for deadline in deadlines where deadline.due > now && deadline.due <= windowEnd {
            // One second past due, so this entry renders as overdue.
            dates.insert(deadline.due.addingTimeInterval(1))
        }

        let entries = dates.sorted().prefix(50).map { date in
            DeadlineEntry(date: date, deadlines: deadlines)
        }

        // Refresh as soon as the next deadline passes; otherwise when the
        // 24-hour window of entries runs out.
        let nextDue = deadlines.first { $0.due > now }?.due
        let policy: TimelineReloadPolicy = if let nextDue, nextDue <= windowEnd {
            .after(nextDue.addingTimeInterval(1))
        } else {
            .atEnd
        }
        completion(Timeline(entries: entries, policy: policy))
    }
}
