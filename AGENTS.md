## Agent skills

### Issue tracker

Issues live in GitHub Issues for vyavahareyash/Timezone (via the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Build and test

One-time: `brew install xcodegen` and `git config core.hooksPath .githooks` (pre-push runs the fast tests). The `.xcodeproj` is generated and git-ignored; run `xcodegen` after changing `project.yml` or adding/removing files.

```sh
DD=~/Library/Developer/Xcode/DerivedData/Timezone-cli
# Keeps results and real errors; drops simulator/linkd log spam. Rerun unfiltered if output looks wrong.
F='[0-9]: error:|^error:|✘|↳ (Recorded|Snapshot|Expectation)|✔ Test run|\*\* (TEST|BUILD)'
xcodegen
xcodebuild build -scheme Timezone -destination 'platform=macOS' -derivedDataPath $DD 2>&1 | grep -E "$F"
open $DD/Build/Products/Debug/Timezone.app

# All tests; then export UI-test screenshots to build/screenshots/
rm -rf build && xcodebuild test -scheme Timezone -destination 'platform=macOS' -derivedDataPath $DD -resultBundlePath build/Tests.xcresult 2>&1 | grep -E "$F"
xcrun xcresulttool export attachments --path build/Tests.xcresult --output-path build/screenshots
```

Add `-only-testing:TimezoneCoreTests -only-testing:TimezoneTests` for a fast loop that skips the UI test (it takes over the mouse for ~10 s).

Layout: `Core/` is the pure `TimezoneCore` framework (Foundation only), `App/` the SwiftUI menu bar app; tests in `CoreTests/` (behaviour), `AppTests/` (panel snapshots), `UITests/` (real-app smoke test).

**Testing**: before writing or fixing a test, or when a snapshot goes red, read `docs/agents/testing.md`.
