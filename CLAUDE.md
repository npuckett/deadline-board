# Deadlines — development guide

macOS desktop widget + menu bar host app for tracking deadlines. The authoritative specification is `deadlines-widget-plan.md` — read it before making changes. Work follows its phases in order, stopping at each checkpoint for review. Current status is tracked in the README's "Development status" checklist; update it when a phase completes.

## Build

The `.xcodeproj` is **generated** — never edit `project.pbxproj` by hand. Targets, entitlements, and Info.plist keys all live in `project.yml`.

```bash
./scripts/generate.sh                                        # regenerate after project.yml or file add/remove
xcodebuild -scheme Deadlines -destination 'platform=macOS' build
xcodebuild -scheme Deadlines -destination 'platform=macOS' test
```

Full Xcode is required (widget extension target); Command Line Tools alone will fail with "requires Xcode". If `xcodebuild` errors that way, check `xcode-select -p`.

## Architecture invariants

- Swift + SwiftUI only, no third-party dependencies in the app. XcodeGen is build tooling only; nothing links into the product.
- Deployment target macOS 14.0. No newer APIs without a fallback.
- Three targets: `Deadlines` (app), `DeadlinesWidget` (ExtensionKit widget extension), `DeadlinesTests` (unit tests). `Shared/` sources compile into all three.
- Data is `deadlines.json` in the App Group container (`SAV2V7GXQ5.group.com.puckett.Deadlines`), ISO 8601 dates, written atomically. `DeadlineStore.save()` reloads widget timelines.
- The app observes `DeadlineStore` (`@Observable`); the widget uses static `DeadlineStore.load()` because the extension process runs briefly and exits.
- Notifications are scheduled only by the host app — widget extensions cannot use `UNUserNotificationCenter`.
- Widget rows deep-link through the app (`deadlines://open/<uuid>`), never directly to external URLs.
- Tests inject a temp `fileURL` and `reloadsWidgets: false` into `DeadlineStore` — never touch the real App Group container or WidgetCenter from tests.
- Countdown strings are computed from an explicit `now` (the timeline entry date), never `Date()` inside widget views.
- Deviations from the plan, per user feedback: deadlines **auto-disappear** from upcoming when they pass (the plan's "overdue stays at top" is overridden; passed items live in the editor's Past filter). There is **no mark-as-done UI** — no circle button on widget or editor rows, and ToggleDoneIntent was removed; clicking an editor row opens the same form as Add, which handles edit and delete. The `isDone` model field remains for JSON compatibility. Do not reintroduce done-toggling without asking.

Identifiers: app `com.puckett.Deadlines`, widget `com.puckett.Deadlines.Widget`, group `SAV2V7GXQ5.group.com.puckett.Deadlines` (team-prefixed, deviating from the plan — `group.`-style groups require provisioning profiles on Xcode 15+ and trigger a consent prompt on macOS 15), URL scheme `deadlines`, team `SAV2V7GXQ5`.

Signing is Manual with the Developer ID Application identity for **all** configurations (set in `project.yml`) — automatic signing would require an Apple ID account in Xcode to generate development profiles, which this machine doesn't have. CI overrides with `CODE_SIGNING_ALLOWED=NO`.

## Gotchas (from the plan — verified costly)

- Missing `containerBackground(for: .widget)` on macOS 14 → widget renders blank with no error.
- `Text(date, style:)` timer/relative styles cannot produce `12d 4h`; compute the string manually.
- App Intent files must be members of **both** app and widget targets or the widget button silently does nothing (in `project.yml`, `Shared/` is in both source lists — keep intents under `Shared/Intents/`).
- Missing the App Group on either target's entitlements → widget shows empty data.
- After changing entitlements, delete the app and widget from the Mac and reinstall.
- `MenuBarExtra` `.menu` style only supports simple `Button`/`Text` rows; use `.window` style for real layout.
- `SMAppService` launch-at-login needs the app in `/Applications` to register reliably.
- Keep the timeline provider synchronous and light — widget processes are killed quickly.

## Release (Phase 8)

Local only, never CI. Signing identity on this machine: `Developer ID Application: Nicholas Puckett (SAV2V7GXQ5)`. Confirm before assuming anything is missing:

```bash
security find-identity -v -p codesigning
xcrun notarytool history --keychain-profile <name>
```

`scripts/release.sh <notary-profile>` drives archive → export → DMG → sign → notarize → staple → `gh release create`. The version comes from `MARKETING_VERSION` in `project.yml`. The notarytool keychain profile on this machine is named `PrimusCentral Notary` (documented in the PrimusV3 repo's `V3_5/PACKAGING.md`):

```bash
./scripts/release.sh "PrimusCentral Notary"
```
