import SwiftUI
import WidgetKit

@main
struct DeadlinesWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeadlinesWidget()
    }
}

struct DeadlinesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DeadlinesWidget", provider: DeadlineTimelineProvider()) { entry in
            DeadlineEntryView(entry: entry)
                // Required on macOS 14 — omitting it renders the widget blank.
                .containerBackground(.regularMaterial, for: .widget)
        }
        .configurationDisplayName("Deadlines")
        .description("Upcoming deadlines ranked soonest first.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct DeadlineEntry: TimelineEntry {
    let date: Date
    let deadlines: [Deadline]
}

/// Phase 1 scaffold provider: a single entry from the store, sample data for
/// placeholder and snapshot. Phase 3 replaces this with the hourly timeline
/// strategy in DeadlineTimelineProvider.swift.
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
        let entry = DeadlineEntry(date: Date(), deadlines: deadlines)
        let nextHour = Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextHour)))
    }
}

/// Phase 1 scaffold view. Phase 3 replaces this with the full medium/large
/// layouts (DeadlineEntryView.swift, DeadlineRow.swift).
struct DeadlineEntryView: View {
    let entry: DeadlineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEADLINES")
                .font(.caption)
                .tracking(1)
                .foregroundStyle(.secondary)
            if entry.deadlines.isEmpty {
                Spacer()
                Text("No upcoming deadlines")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(entry.deadlines.prefix(4)) { deadline in
                    HStack {
                        Text(deadline.title)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Spacer()
                        Text(Countdown.label(from: entry.date, to: deadline.due))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Urgency(from: entry.date, to: deadline.due).color)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
