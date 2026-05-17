# Repository Guidelines

## Project Structure & Module Organization

This is a Swift Package for a small macOS menu bar app.

- `Sources/HealthReminder/`: macOS app entry point, menu bar UI, notifications, and launch-at-login setup.
- `Sources/HealthReminderCore/`: pure reminder timing logic that can be tested without macOS UI.
- `Tests/HealthReminderCoreTests/`: XCTest coverage for timer behavior.
- `Scripts/package_app.sh`: builds and signs `build/HealthReminder.app`.
- `release/`: local release artifacts only. DMG files are ignored and should be uploaded to GitHub Releases, not committed.

Current macOS-specific pieces:

- `ReminderOverlayPresenter`: AppKit `NSPanel` shell plus SwiftUI/Vortex overlay content.
- `OverlaySettingsWindowController`: menu-bar `设置...` window for appearance preview, dynamic health reminders, Kanban source, and About settings; saves to `~/.config/HealthReminder/config.env` and takes effect after app restart.
- `FocusTaskStore`, `KanbanTaskReader`, `FocusReminderEngine`: main-task recall and read-only Obsidian Kanban intake.
- `ReminderPresentationComposer`: combines reminders triggered on the same tick into at most one overlay message.
- `EnvConfigurationWriter`: updates selected `.env` keys while preserving unrelated user configuration.

## Build, Test, and Development Commands

```bash
swift build
```

Builds the debug executable and verifies the package compiles.

```bash
swift test
```

Runs XCTest coverage for `HealthReminderCore`.

```bash
bash Scripts/package_app.sh
```

Builds the release executable, wraps it as `build/HealthReminder.app`, writes the app version into `Info.plist`, and ad-hoc signs the app.

```bash
open build/HealthReminder.app
```

Runs the local packaged app. First launch may request notification permission.

```bash
hdiutil create -volname HealthReminder -srcfolder build/HealthReminder.app -ov -format UDZO release/HealthReminder-<version>.dmg
```

Creates the local release DMG. Keep `Scripts/package_app.sh` version, Git tag, DMG filename, and GitHub Release version in sync.

Current release target is `v0.5.0`.

## Coding Style & Naming Conventions

Use Swift 5 language mode with 4-space indentation. Keep AppKit-specific code in `Sources/HealthReminder/` and testable business rules in `Sources/HealthReminderCore/`. Prefer clear type names such as `ReminderEngine`, `ReminderEngineState`, and `ReminderEngineTests`. Avoid adding dependencies unless they materially simplify the app.

## Testing Guidelines

Use XCTest. Test files should mirror the type under test, for example `ReminderEngineTests.swift`. Add tests for any change to reminder timing, idle detection rules, automatic reminder reset, or reset behavior. Run `swift test` before committing.

Also add tests for configuration parsing/writing changes, especially new `OVERLAY_*` keys and `.env` preservation behavior.

## Commit & Pull Request Guidelines

Current history uses concise, imperative commit messages, for example `Initial health reminder app`. Keep commits focused. Pull requests should include a short summary, test results, and user-facing behavior changes. Include screenshots only when menu bar UI or notification behavior changes visibly.

## Security & Configuration Tips

Do not commit build outputs, `.build/`, `.app`, or `.dmg` artifacts. The app writes a user `LaunchAgents` plist only when run from the packaged `.app`; avoid changing login-item behavior without documenting the user impact. When debugging user reports, confirm which app bundle is actually running because `/Applications/HealthReminder.app` may differ from the freshly built `build/HealthReminder.app`.

macOS appearance, health reminder, Kanban, and About settings are split between the menu `设置...` UI and `~/.config/HealthReminder/config.env`. The settings window does not hot-reload saved values; tell users to restart the app after saving. Keep `config.example.env`, `README.md`, and `AppConfigurationTests` aligned whenever adding or renaming a config key.

App icons live in `Sources/HealthReminder/Resources/`. Keep the full-color app icon and the monochrome status-bar template icon separate; menu bar icons should remain template-safe for dark and light menu bars.

Do not change the Windows version for macOS overlay, particle, Kanban, or main-task recall work unless explicitly requested.
