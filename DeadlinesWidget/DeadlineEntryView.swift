import SwiftUI
import WidgetKit

struct DeadlineEntryView: View {
    let entry: DeadlineEntry
    @Environment(\.widgetFamily) private var family

    private var maxRows: Int {
        family == .systemLarge ? 9 : 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Deadlines")
                .font(.caption)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            // Entries share one deadline array; filter against the entry date
            // so a deadline disappears at the entry just past its due moment.
            let visible = entry.deadlines.filter { $0.due > entry.date }

            if visible.isEmpty {
                Spacer()
                Text("No upcoming deadlines")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                let shown = Array(visible.prefix(maxRows))
                let hidden = visible.count - shown.count

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(shown) { deadline in
                        DeadlineRow(deadline: deadline, now: entry.date)
                    }
                    if hidden > 0 {
                        Text("+\(hidden) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 14)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview("Medium", as: .systemMedium) {
    DeadlinesWidget()
} timeline: {
    DeadlineEntry(date: Date(), deadlines: Deadline.samples())
    DeadlineEntry(date: Date(), deadlines: [])
}

#Preview("Large", as: .systemLarge) {
    DeadlinesWidget()
} timeline: {
    DeadlineEntry(date: Date(), deadlines: Deadline.samples())
}
