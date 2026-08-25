# Deadlines: macOS desktop widget + minimal host app

Build plan for Claude Code. Read the whole document before starting. Work through the phases in order and stop at each checkpoint for review.

## Goal

A native macOS desktop widget that lists project, conference, and submission deadlines ranked soonest to furthest, showing days and hours remaining. A very small host app handles entry and editing, stores the data, and fires local notifications at configurable intervals before each deadline.

The widget is the product. The app should feel like a settings pane, not a destination.

## Constraints and decisions

- Swift and SwiftUI only. No third party dependencies.
- Deployment target macOS 14.0 (Sonoma). This is the first version with desktop widgets, interactive widgets, and `containerBackground`. Do not use APIs newer than macOS 14 without a fallback.
- Xcode project, not a Swift package as the top level. Two targets in one project: the app and a Widget Extension.
- Data lives in a JSON file inside an App Group container so both targets read the same file.
- Notifications are scheduled only by the host app. Widget extensions cannot schedule `UNUserNotificationCenter` requests.
- Widgets cannot accept text input. All entry happens in the app or through an App Intent. Do not attempt text fields in the widget.
- The app is a menu bar app (`LSUIElement = YES`) with one editor window. No dock icon.
- Local only. No iCloud, no sync, no accounts.
- This machine already has the Developer ID signing identity and notarization credentials installed. Use them. Do not create new certificates or prompt for Apple ID login. Check with `security find-identity -v -p codesigning` and `xcrun notarytool history` before assuming anything is missing.

## Project layout

```
Deadlines/
  Deadlines.xcodeproj
  Shared/                    compiled into both targets
    Deadline.swift           model
    DeadlineStore.swift      load/save, sorting, App Group path
    Countdown.swift          time remaining formatting and urgency level
    AppGroup.swift           group identifier constant
    Intents/
      ToggleDoneIntent.swift
      AddDeadlineIntent.swift
  DeadlinesApp/              host app target
    DeadlinesApp.swift       @main, MenuBarExtra, window scene
    EditorView.swift         list of deadlines with add/edit/delete
    DeadlineForm.swift       add/edit sheet
    NotificationScheduler.swift
    SettingsView.swift       default notification offsets, launch at login
    Assets.xcassets
    Info.plist
    DeadlinesApp.entitlements
  DeadlinesWidget/           widget extension target
    DeadlinesWidget.swift    Widget definition and configuration
    DeadlineTimelineProvider.swift
    DeadlineEntryView.swift  medium and large layouts
    DeadlineRow.swift
    Assets.xcassets
    Info.plist
    DeadlinesWidget.entitlements
```

Bundle identifiers, replace the prefix as appropriate:

- App: `com.puckett.Deadlines`
- Widget: `com.puckett.Deadlines.Widget`
- App Group: `group.com.puckett.Deadlines`
- URL scheme: `deadlines`

Both entitlements files must include the App Group. Both targets must be signed with the same team. Missing the group on either target is the most common reason the widget shows empty data.

## Data model

```swift
struct Deadline: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var due: Date
    var url: URL?
    var notifyOffsets: [TimeInterval]   // seconds before due, e.g. 7 days, 1 day, 2 hours
    var isDone: Bool = false
    var createdAt: Date = Date()
}
```

`DeadlineStore`:

- Reads and writes `deadlines.json` at `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`.
- Writes atomically.
- `upcoming` returns deadlines with `isDone == false`, sorted by `due` ascending. Overdue items stay at the top rather than disappearing, so nothing is silently lost.
- `save()` calls `WidgetCenter.shared.reloadAllTimelines()` after writing.
- The app observes the store as an `@Observable` class. The widget uses a static `load()` since it runs briefly and exits.

`Countdown`:

- `remaining(from now: Date, to due: Date) -> (days: Int, hours: Int, isOverdue: Bool)`.
- `label` produces strings like `12d 4h`, `0d 9h`, and `overdue` for past dates. Under one hour show `<1h`.
- `Urgency` enum with cases `calm` (more than 7 days), `soon` (1 to 7 days), `critical` (under 24 hours), `overdue`. Each maps to a color. Keep the palette restrained. Suggested: system secondary text for calm, orange for soon, red for critical, red with strikethrough-free dimmed title for overdue.

## Widget

### Configuration

- `StaticConfiguration`. No user configuration needed for v1.
- `supportedFamilies`: `.systemMedium` and `.systemLarge`.
- `containerBackground(for: .widget)` is required on macOS 14 or the widget renders blank. Use a subtle material or solid background that reads well in both light and dark mode.
- `contentMarginsDisabled()` is optional; only use it if the default margins look wrong.

### Timeline provider

The provider must produce entries whose dates cover the moments the display changes. Strategy:

1. Load upcoming deadlines from the store.
2. Generate one entry per hour starting from now, for the next 24 hours.
3. Add an entry at the exact `due` date of each deadline within that window so the switch to overdue happens on time.
4. Sort entries by date, dedupe, cap at roughly 50.
5. Return `.atEnd` reload policy. Also return `.after(nextDueDate)` if the next deadline falls inside the window so the timeline refreshes as soon as it passes.

Each `TimelineEntry` holds the entry `date` and the full `[Deadline]` array. Countdown values are computed in the view from the entry date, not at provider time, so a single array reused across entries stays correct.

Placeholder and snapshot entries should use three plausible sample deadlines so the widget gallery preview looks real.

### Layout

Medium shows up to 4 rows. Large shows up to 9. If more exist, the last row shows a muted `+N more`. If none exist, show a single centered line reading `No upcoming deadlines` in secondary color.

Each row:

```
[urgency dot]  Title                              12d 4h
               Sat 14 Mar
```

- Title on one line, truncated with tail ellipsis.
- Due date on a second line in caption size, secondary color.
- Countdown right aligned, `.monospacedDigit()`, colored by urgency, semibold.
- The whole row is wrapped in `Link(destination:)` with a deep link `deadlines://open/<uuid>`. The host app receives it via `onOpenURL`, looks up the deadline, and opens its `url` in the default browser. If the deadline has no `url`, the app instead opens the editor with that item selected. Do not put the external `https` URL directly in the widget `Link`; routing through the app keeps behavior consistent and gives the app a chance to become active.
- A small circular `Button(intent: ToggleDoneIntent(id:))` at the trailing edge of the row marks it done. Give it a generous tap target and low visual weight so it doesn't compete with the countdown.

Typography: use system fonts throughout. Title at `.callout` or `.subheadline` weight `.medium`, countdown at `.subheadline` weight `.semibold`. Widget header at top left reading `Deadlines` in caption size, uppercase, tracking slightly increased, secondary color. Keep spacing consistent between rows using a `VStack(spacing:)` with a hairline `Divider` or none; test both and pick the cleaner result.

### Interactive intent

`ToggleDoneIntent` conforms to `AppIntent`, takes a `@Parameter var id: String`, loads the store, flips `isDone`, saves. Because `save()` reloads timelines the widget updates immediately. The intent file is in `Shared` and must be a member of both targets.

## Host app

### Structure

- `@main` app uses `MenuBarExtra` with a simple icon (SF Symbol `calendar.badge.clock` or a custom template asset).
- Menu bar dropdown contains: the next three deadlines with countdowns as non-interactive rows, a divider, `Add Deadline…` (⌘N), `Open Editor…`, `Settings…`, `Quit`.
- The editor is a single `Window` scene, roughly 480×520, with a `List` of all deadlines including done ones in a collapsed section at the bottom. Toolbar has add, and a segmented filter for `Upcoming / Done / All`.
- Selecting a row opens `DeadlineForm` as a sheet. Fields: title (`TextField`), due (`DatePicker` with date and hour/minute), link (`TextField` with URL validation, allow empty), notification offsets as a row of toggles.
- Default offsets come from `SettingsView` and are stored in the App Group `UserDefaults`. Ship with 7 days, 1 day, and 2 hours enabled. Offer 14d, 7d, 3d, 1d, 12h, 2h, 1h.
- Delete via swipe or context menu with a confirmation for items that are not yet done.
- `Settings` includes a `Launch at Login` toggle using `SMAppService.mainApp`.

### Deep links

Register the `deadlines` URL scheme in the app `Info.plist`. Handle `deadlines://open/<uuid>` and `deadlines://add` in `onOpenURL`. For `open`, if the deadline has a URL call `NSWorkspace.shared.open(url)`, otherwise show the editor with that item selected.

### Add Deadline intent

`AddDeadlineIntent` with parameters `title: String`, `due: Date`, `link: URL?`. Saves using default offsets, reschedules notifications by posting to the store, returns a short confirmation dialog. Mark it `openAppWhenRun = false`. This makes entry available from Spotlight and Shortcuts without opening a window. Because the intent runs in the app process, it may schedule notifications directly.

## Notifications

`NotificationScheduler`:

- On first launch request authorization with `.alert, .sound, .badge`. Surface the result in Settings so the user can see if permission was denied.
- `rescheduleAll()` removes all pending requests with the app's identifier prefix and rebuilds from the current store. Called after every save in the app, and on app launch. Rebuilding from scratch is simpler and safer than diffing.
- Request identifier format: `deadline.<uuid>.<offsetSeconds>`.
- Trigger: `UNCalendarNotificationTrigger` with the date components of `due - offset`. Skip any fire date already in the past.
- Content: title is the deadline title, body is `Due in 2 hours` or `Due tomorrow at 5:00 PM`, formatted with `RelativeDateTimeFormatter` or a hand-rolled string that reads naturally. Attach `userInfo["deadlineID"]` so tapping the notification can open the link via the same handler as the deep link.
- Add a `UNNotificationCategory` with an `Open Link` action.
- Done or deleted deadlines get their notifications cancelled by the rebuild.

## Phases and checkpoints

Stop after each phase and report what was built, what was tested, and anything uncertain.

**Phase 1. Scaffold.** Create the project, both targets, entitlements, App Group, URL scheme, `LSUIElement`. Confirm both targets build and the placeholder widget appears in the widget gallery on the desktop.

**Phase 2. Shared model and store.** Implement `Deadline`, `DeadlineStore`, `Countdown`, `AppGroup`. Add unit tests for sorting, countdown formatting at boundaries (exactly 24h, 59 minutes, past due), and JSON round trip.

**Phase 3. Widget.** Provider, entry view, row, sample data. Verify medium and large on the desktop in light and dark mode. Verify the countdown ticks over on the hour by setting a deadline a few minutes out and watching it. Verify `Link` reaches the app's `onOpenURL`.

**Phase 4. Host app.** Menu bar, editor window, form, deep link handling, settings, launch at login. Verify a saved edit reloads the widget within a second.

**Phase 5. Intents.** `ToggleDoneIntent` on the widget row, `AddDeadlineIntent` in Shortcuts and Spotlight.

**Phase 6. Notifications.** Scheduler, authorization, category with action. Test by creating a deadline 3 minutes out with a 2 minute offset.

**Phase 7. Polish.** Empty state, `+N more`, overdue styling, app icon, menu bar icon at 1x and 2x, keyboard shortcuts in the editor, accessibility labels on the widget button and rows.

**Phase 8. Release.** Produce a signed, notarized, stapled DMG and publish it as a GitHub release. Details below.

## Release process

Write this as a script at `scripts/release.sh` so it is repeatable, and document it in the README. Take the version from `MARKETING_VERSION` in the project. Steps:

1. Confirm the identity. `security find-identity -v -p codesigning` should list a `Developer ID Application` certificate. Use its full name in the script rather than a hash so it survives certificate renewal. Confirm a stored notarytool profile exists with `xcrun notarytool history --keychain-profile <name>`; ask which profile name to use if more than one is present.
2. Set `Hardened Runtime` on both targets and `Code Sign Style` to Manual with the Developer ID identity for the Release configuration. Enable `Enable Hardened Runtime` and add no exceptions unless a specific one is required; the app needs none for this feature set.
3. Archive from the command line with `xcodebuild -scheme Deadlines -configuration Release archive -archivePath build/Deadlines.xcarchive`.
4. Export with an `ExportOptions.plist` using `method: developer-id`, `signingStyle: manual`, `teamID`, and `destination: export`. Output to `build/export/Deadlines.app`.
5. Verify the export. `codesign --verify --deep --strict --verbose=2 build/export/Deadlines.app` and `codesign -d --entitlements - build/export/Deadlines.app` should show the App Group and hardened runtime on both the app and the embedded widget appex. `spctl --assess --type execute` will fail until notarized, which is expected at this step.
6. Build the DMG with `hdiutil`. Create a staging folder containing `Deadlines.app` and a symlink to `/Applications`, then `hdiutil create -volname Deadlines -srcfolder staging -ov -format UDZO build/Deadlines-<version>.dmg`. A custom background image and icon positions are optional; skip unless time allows.
7. Sign the DMG with `codesign --sign "Developer ID Application: ..." --timestamp build/Deadlines-<version>.dmg`.
8. Notarize with `xcrun notarytool submit build/Deadlines-<version>.dmg --keychain-profile <name> --wait`. On failure, fetch the log with `xcrun notarytool log <id> --keychain-profile <name>` and fix the underlying issue rather than retrying blindly. The usual causes are a missing timestamp, hardened runtime not enabled on the appex, or an unsigned nested binary.
9. Staple with `xcrun stapler staple build/Deadlines-<version>.dmg` and validate with `xcrun stapler validate`. Also run `spctl --assess --type open --context context:primary-signature -v build/Deadlines-<version>.dmg`, which should report `accepted`.
10. Tag and publish. `git tag v<version>`, push the tag, then `gh release create v<version> build/Deadlines-<version>.dmg --title "Deadlines <version>" --notes-file CHANGELOG.md` (or generated notes). Confirm `gh` is authenticated before starting the release phase.

Add a `.github/workflows/build.yml` that builds and runs tests on push for confidence, but do not attempt signing or notarization in CI. Signing stays on this machine because the keys are here.

## Acceptance criteria

- Widget sits on the desktop, survives reboot, shows correct order and countdowns without opening the app.
- Adding, editing, marking done, or deleting in the app updates the widget within a second.
- Tapping a row opens the deadline's link in the default browser.
- Marking done from the widget works without the app running.
- Notifications fire at the configured offsets and open the link when actioned.
- `Add Deadline` works from Spotlight with only title and date.
- No third party code, no network access, no dock icon.
- A fresh download of the release DMG from GitHub opens on another Mac without a Gatekeeper warning, and the widget appears in that Mac's widget gallery after dragging the app to Applications and launching it once.

## Known gotchas

- Forgetting `containerBackground(for: .widget)` on macOS 14 produces an empty widget with no error.
- `Text(date, style: .timer)` and `.relative` styles don't produce a `days + hours` format and should not be used for the countdown. Compute the string manually from the entry date.
- App Intents must be in a file that is a member of both targets, otherwise the widget button silently does nothing.
- Widget extension processes are killed quickly; do not do anything asynchronous or heavy in the provider beyond reading the JSON file.
- After changing entitlements, delete the app and widget from the Mac and reinstall, or the old provisioning sticks around.
- `MenuBarExtra` with `.menu` style cannot host complex SwiftUI. Use `.window` style if the dropdown needs real layout, otherwise keep it to simple `Button` and `Text` rows.
- Launch at login through `SMAppService` requires the app to be in `/Applications` or the login item may not register during development. Note this in Settings help text.
