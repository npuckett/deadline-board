import SwiftUI
import WidgetKit

struct DeadlineRow: View {
    let deadline: Deadline
    let now: Date

    private var urgency: Urgency {
        Urgency(from: now, to: deadline.due)
    }

    // Routed through the app rather than linking the external URL directly:
    // the app decides whether to open the browser or the editor.
    private var deepLink: URL {
        URL(string: "deadlines://open/\(deadline.id.uuidString)")!
    }

    var body: some View {
        Link(destination: deepLink) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(urgency.color)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(deadline.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .opacity(urgency == .overdue ? 0.55 : 1)
                    Text(deadline.due.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(Countdown.label(from: now, to: deadline.due))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(urgency.color)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(deadline.title), due \(deadline.due.formatted(date: .abbreviated, time: .shortened)), \(Countdown.label(from: now, to: deadline.due))")
    }
}
