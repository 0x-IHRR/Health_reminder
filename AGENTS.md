# Repository Guidelines

## Project Structure & Module Organization

This is a Swift Package for a small macOS menu bar app.

- `Sources/HealthReminder/`: macOS app entry point, menu bar UI, notifications, and launch-at-login setup.
- `Sources/HealthReminderCore/`: pure reminder timing logic that can be tested without macOS UI.
- `Tests/HealthReminderCoreTests/`: XCTest coverage for timer behavior.
- `Scripts/package_app.sh`: builds and signs `build/HealthReminder.app`.
- `release/`: local release artifacts only. DMG files are ignored and should be uploaded to GitHub Releases, not committed.

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

## Coding Style & Naming Conventions

Use Swift 5 language mode with 4-space indentation. Keep AppKit-specific code in `Sources/HealthReminder/` and testable business rules in `Sources/HealthReminderCore/`. Prefer clear type names such as `ReminderEngine`, `ReminderEngineState`, and `ReminderEngineTests`. Avoid adding dependencies unless they materially simplify the app.

## Testing Guidelines

Use XCTest. Test files should mirror the type under test, for example `ReminderEngineTests.swift`. Add tests for any change to reminder timing, idle detection rules, repeat reminders, per-reminder completion, or reset behavior. Run `swift test` before committing.

## Commit & Pull Request Guidelines

Current history uses concise, imperative commit messages, for example `Initial health reminder app`. Keep commits focused. Pull requests should include a short summary, test results, and user-facing behavior changes. Include screenshots only when menu bar UI or notification behavior changes visibly.

## Security & Configuration Tips

Do not commit build outputs, `.build/`, `.app`, or `.dmg` artifacts. The app writes a user `LaunchAgents` plist only when run from the packaged `.app`; avoid changing login-item behavior without documenting the user impact. When debugging user reports, confirm which app bundle is actually running because `/Applications/HealthReminder.app` may differ from the freshly built `build/HealthReminder.app`.
