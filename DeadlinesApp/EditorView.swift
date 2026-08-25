import SwiftUI

/// Editor window. Phase 4 replaces this scaffold with the full list
/// (upcoming/done/all filter, add/edit/delete, DeadlineForm sheet).
struct EditorView: View {
    let store: DeadlineStore

    var body: some View {
        List {
            if store.upcoming.isEmpty {
                Text("No upcoming deadlines")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(store.upcoming) { deadline in
                    HStack {
                        Text(deadline.title)
                        Spacer()
                        Text(Countdown.label(from: Date(), to: deadline.due))
                            .monospacedDigit()
                            .foregroundStyle(Urgency(from: Date(), to: deadline.due).color)
                    }
                }
            }
        }
        .navigationTitle("Deadlines")
    }
}
