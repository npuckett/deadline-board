# Deadlines

A native macOS desktop widget that lists project, conference, and submission deadlines ranked soonest to furthest, showing days and hours remaining. A small menu bar host app handles entry and editing, stores the data, and fires local notifications before each deadline.

The widget is the product. The app is a settings pane, not a destination.

Full specification: [deadlines-widget-plan.md](deadlines-widget-plan.md).

## Requirements

- macOS 14.0 (Sonoma) or later — first version with desktop widgets and interactive widgets
- Xcode 15 or later (full Xcode; Command Line Tools alone cannot build the widget extension)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the `.xcodeproj` is generated from `project.yml`

## Getting started

```bash
./scripts/bootstrap.sh
```

This checks the toolchain, generates `Deadlines.xcodeproj`, and prints anything missing. Then open the project in Xcode, or build from the command line:

```bash
xcodebuild -scheme Deadlines -destination 'platform=macOS' build
xcodebuild -scheme Deadlines -destination 'platform=macOS' test
```

After changing `project.yml` or adding/removing source files, regenerate with `./scripts/generate.sh`.

## Project structure

| Path | Purpose |
| --- | --- |
| `project.yml` | XcodeGen project definition — targets, entitlements, Info.plist content |
| `Shared/` | Model, store, countdown logic, App Intents — compiled into both targets |
| `DeadlinesApp/` | Menu bar host app (`LSUIElement`, no dock icon) |
| `DeadlinesWidget/` | Widget extension (medium and large desktop widgets) |
| `DeadlinesTests/` | Unit tests for the shared model and countdown logic |
| `scripts/` | `bootstrap.sh`, `generate.sh`, and (Phase 8) `release.sh` |

Data is a single `deadlines.json` in the App Group container (`SAV2V7GXQ5.group.com.puckett.Deadlines` — team-prefixed rather than the plan's `group.` style, because Xcode 15+ requires provisioning profiles for `group.`-style groups and macOS 15 adds a consent prompt for them), read by both targets. Local only — no iCloud, no sync, no accounts, no third-party dependencies.

## Development status

Work proceeds in the phases defined in the plan, with a review checkpoint after each:

- [x] **Phase 1 — Scaffold**: project, both targets, entitlements, App Group, URL scheme — builds, signs, and the widget extension registers with the system
- [x] **Phase 2 — Shared model and store**: `Deadline`, `DeadlineStore`, `Countdown` — all 12 unit tests pass
- [x] **Phase 3 — Widget**: timeline provider, entry view, rows *(light/dark + hourly tick verification pending)*
- [x] **Phase 4 — Host app**: menu bar, editor, form, deep links, settings, launch at login
- [x] **Phase 5 — Intents**: `ToggleDoneIntent` (widget), `AddDeadlineIntent` (Spotlight/Shortcuts)
- [x] **Phase 6 — Notifications**: scheduler, authorization, notification category *(live fire test pending)*
- [ ] **Phase 7 — Polish**: empty state, `+N more`, overdue styling, icons, accessibility
- [ ] **Phase 8 — Release**: signed, notarized, stapled DMG published as a GitHub release

## CI

`.github/workflows/build.yml` builds and runs tests on every push and pull request. Signing and notarization are deliberately excluded from CI — releases are produced locally where the Developer ID keys live.

## Release

Phase 8 adds `scripts/release.sh`: archive → export with Developer ID → DMG via `hdiutil` → sign → `notarytool submit --wait` → staple → `gh release create`. See the plan for the full checklist.
