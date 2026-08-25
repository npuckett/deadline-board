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
