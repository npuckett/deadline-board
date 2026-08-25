import SwiftUI

struct EditorView: View {
    let store: DeadlineStore
    @Bindable var navigation: AppNavigation

    enum Filter: String, CaseIterable {
        case upcoming = "Upcoming"
        case done = "Done"
        case all = "All"
    }

    @State private var filter: Filter = .upcoming
    @State private var editing: Deadline?
    @State private var pendingDelete: Deadline?
    @State private var doneSectionExpanded = false

    var body: some View {
        List {
            switch filter {
            case .upcoming:
                rows(store.upcoming, emptyText: "No upcoming deadlines")
                if !store.done.isEmpty {
                    Section("Done", isExpanded: $doneSectionExpanded) {
                        rows(store.done, emptyText: nil)
                    }
                }
            case .done:
                rows(store.done, emptyText: "Nothing done yet")
            case .all:
                rows(store.deadlines.sorted { $0.due < $1.due }, emptyText: "No deadlines")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Deadlines")
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
            Text("This deadline isn't done yet.")
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
                    // Confirm only for items that are not yet done.
                    if deadline.isDone {
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
            Button {
                store.toggleDone(id: deadline.id)
            } label: {
                Image(systemName: deadline.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(deadline.isDone ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(deadline.isDone ? "Mark not done" : "Mark done")

            VStack(alignment: .leading, spacing: 1) {
                Text(deadline.title)
                    .strikethrough(deadline.isDone)
                    .foregroundStyle(deadline.isDone ? .secondary : .primary)
                Text(deadline.due.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !deadline.isDone {
                Text(Countdown.label(from: Date(), to: deadline.due))
                    .monospacedDigit()
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(urgency.color)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
        .contextMenu {
            Button("Edit…", action: onEdit)
            Button(deadline.isDone ? "Mark Not Done" : "Mark Done") {
                store.toggleDone(id: deadline.id)
            }
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
