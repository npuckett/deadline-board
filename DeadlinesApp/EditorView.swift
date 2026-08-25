import SwiftUI

struct EditorView: View {
    let store: DeadlineStore
    @Bindable var navigation: AppNavigation

    enum Filter: String, CaseIterable {
        case upcoming = "Upcoming"
        case past = "Past"
        case all = "All"
    }

    @State private var filter: Filter = .upcoming
    @State private var editing: Deadline?
    @State private var pendingDelete: Deadline?

    var body: some View {
        List {
            switch filter {
            case .upcoming:
                rows(store.upcoming, emptyText: "No upcoming deadlines")
            case .past:
                rows(store.past, emptyText: "No past deadlines")
            case .all:
                rows(store.deadlines.sorted { $0.due < $1.due }, emptyText: "No deadlines")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Deadlines")
        // ⌘1/⌘2/⌘3 switch filters; invisible but shortcut-active.
        .background {
            ForEach(Array(Filter.allCases.enumerated()), id: \.offset) { index, target in
                Button("") { filter = target }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { filter in
                        Text(filter.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Deadline", systemImage: "plus") {
                    navigation.showingAddSheet = true
                }
                .keyboardShortcut("n")
            }
        }
        .sheet(item: $editing) { deadline in
            DeadlineForm(store: store, existing: deadline)
        }
        .sheet(isPresented: $navigation.showingAddSheet) {
            DeadlineForm(store: store, existing: nil)
        }
        .confirmationDialog(
            "Delete “\(pendingDelete?.title ?? "")”?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let deadline = pendingDelete {
                    store.remove(id: deadline.id)
                }
                pendingDelete = nil
            }
        } message: {
            Text("This deadline hasn't passed yet.")
        }
        .onChange(of: navigation.selectedDeadlineID) { _, id in
            // Deep link selected an item: open it for editing.
            if let id, let deadline = store.deadline(id: id) {
                editing = deadline
                navigation.selectedDeadlineID = nil
            }
        }
    }

    @ViewBuilder
    private func rows(_ deadlines: [Deadline], emptyText: String?) -> some View {
        if deadlines.isEmpty {
            if let emptyText {
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            }
        } else {
            ForEach(deadlines) { deadline in
                EditorRow(deadline: deadline, store: store) {
                    editing = deadline
                } onDelete: {
                    // Confirm only for deadlines that haven't passed yet.
                    if deadline.due <= Date() {
                        store.remove(id: deadline.id)
                    } else {
                        pendingDelete = deadline
                    }
                }
            }
        }
    }
}

private struct EditorRow: View {
    let deadline: Deadline
    let store: DeadlineStore
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var urgency: Urgency {
        Urgency(from: Date(), to: deadline.due)
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(deadline.title)
                    .foregroundStyle(urgency == .overdue ? .secondary : .primary)
                Text(deadline.due.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(Countdown.label(from: Date(), to: deadline.due))
                .monospacedDigit()
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(urgency == .overdue ? Color.secondary : urgency.color)
        }
        .contentShape(Rectangle())
        // A click opens the same form as Add, where the item can be edited
        // or deleted.
        .onTapGesture(perform: onEdit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(deadline.title), due \(deadline.due.formatted(date: .abbreviated, time: .shortened))")
        .accessibilityHint("Opens the deadline for editing")
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button("Edit…", action: onEdit)
            if let url = deadline.url {
                Button("Open Link") {
                    NSWorkspace.shared.open(url)
                }
            }
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
