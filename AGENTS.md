## Agent skills

### Issue tracker

Issues live in GitHub Issues for vyavahareyash/Timezone (via the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Build and test

One-time: `brew install xcodegen`. The `.xcodeproj` is generated and git-ignored; run `xcodegen` after changing `project.yml` or adding/removing files.

- Generate: `xcodegen`
- Build: `xcodebuild build -scheme Timezone -destination 'platform=macOS' -derivedDataPath build`
- Test (Swift Testing, core module): `xcodebuild test -scheme Timezone -destination 'platform=macOS' -derivedDataPath build`
- Run: `open build/Build/Products/Debug/Timezone.app`

Layout: `Core/` is the pure `TimezoneCore` framework (Foundation only, no SwiftUI/AppKit), `App/` is the SwiftUI menu bar app, `CoreTests/` tests `TimezoneCore`.
