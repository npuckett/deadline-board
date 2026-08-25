import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var defaultOffsets = Set(Deadline.Offset.loadDefaults())
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("Default reminders for new deadlines") {
                ForEach(Deadline.Offset.all, id: \.self) { offset in
                    Toggle(Deadline.Offset.label(for: offset), isOn: Binding(
                        get: { defaultOffsets.contains(offset) },
                        set: { on in
                            if on { defaultOffsets.insert(offset) } else { defaultOffsets.remove(offset) }
                            Deadline.Offset.saveDefaults(defaultOffsets.sorted(by: >))
                        }
                    ))
                }
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                            launchAtLoginError = nil
                        } catch {
                            launchAtLoginError = error.localizedDescription
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text("Registration may not stick unless the app is in the Applications folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }
}
