import Foundation

/// Constants for the App Group container shared by the app and the widget.
enum AppGroup {
    // Team-ID prefixed (macOS style) rather than "group." (iOS style): Xcode 15+
    // requires a provisioning profile for "group."-style groups, and macOS 15
    // shows a user consent prompt for them. Team-prefixed groups need neither.
    static let identifier = "SAV2V7GXQ5.group.com.puckett.Deadlines"

    /// The shared container directory. Crashes if the App Group entitlement is
    /// missing, which is a build configuration error worth failing loudly on.
    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else {
            fatalError("App Group container unavailable — check the \(identifier) entitlement on this target.")
        }
        return url
    }

    static var storeURL: URL {
        containerURL.appendingPathComponent("deadlines.json")
    }
}
