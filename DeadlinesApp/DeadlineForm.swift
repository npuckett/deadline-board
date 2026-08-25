import SwiftUI

/// Add/edit sheet. Pass `existing: nil` to create a new deadline.
struct DeadlineForm: View {
    let store: DeadlineStore
    let existing: Deadline?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var due: Date
    @State private var linkText: String
    @State private var offsets: Set<TimeInterval>

    init(store: DeadlineStore, existing: Deadline?) {
        self.store = store
        self.existing = existing
        _title = State(initialValue: existing?.title ?? "")
        _due = State(initialValue: existing?.due ?? Self.defaultDue)
        _linkText = State(initialValue: existing?.url?.absoluteString ?? "")
        _offsets = State(initialValue: Set(existing?.notifyOffsets ?? Deadline.Offset.loadDefaults()))
    }

    /// Tomorrow at 17:00 — a plausible starting point.
    private static var defaultDue: Date {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        return Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: tomorrow)!
    }

    private var trimmedLink: String {
        linkText.trimmingCharacters(in: .whitespaces)
    }

    /// Empty is allowed; otherwise require something URL-shaped with a scheme.
    private var linkIsValid: Bool {
        if trimmedLink.isEmpty { return true }
        guard let url = URL(string: trimmedLink), let scheme = url.scheme else { return false }
        return ["http", "https"].contains(scheme.lowercased())
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && linkIsValid
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Title", text: $title)
                DatePicker("Due", selection: $due, displayedComponents: [.date, .hourAndMinute])
                TextField("Link", text: $linkText, prompt: Text("https:// (optional)"))
                if !linkIsValid {
                    Text("Enter a full http(s) URL, or leave the link empty.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Section("Remind me before") {
                    ForEach(Deadline.Offset.all, id: \.self) { offset in
                        Toggle(Deadline.Offset.label(for: offset), isOn: Binding(
                            get: { offsets.contains(offset) },
                            set: { on in
                                if on { offsets.insert(offset) } else { offsets.remove(offset) }
                            }
                        ))
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                if existing != nil {
                    Button("Delete", role: .destructive) {
                        if let existing {
                            store.remove(id: existing.id)
                        }
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(existing == nil ? "Add" : "Save") {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(12)
        }
        .frame(width: 380, height: 460)
    }

    private func save() {
        let url = trimmedLink.isEmpty ? nil : URL(string: trimmedLink)
        let sortedOffsets = offsets.sorted(by: >)
        if var updated = existing {
            updated.title = title.trimmingCharacters(in: .whitespaces)
            updated.due = due
            updated.url = url
            updated.notifyOffsets = sortedOffsets
            store.update(updated)
        } else {
            store.add(Deadline(
                title: title.trimmingCharacters(in: .whitespaces),
                due: due,
                url: url,
                notifyOffsets: sortedOffsets
            ))
        }
    }
}
