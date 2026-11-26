## Agent skills

### Issue tracker

Issues live in GitHub Issues for vyavahareyash/Timezone (via the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Build and test

One-time: `brew install xcodegen`. The `.xcodeproj` is generated and git-ignored; run `xcodegen` after changing `project.yml` or adding/removing files.

Build products go to a fixed DerivedData path outside `~/Documents`: test apps there are ad-hoc signed, so macOS would re-ask for Documents access on every build.

```sh
DD=~/Library/Developer/Xcode/DerivedData/Timezone-cli
xcodegen
xcodebuild build -scheme Timezone -destination 'platform=macOS' -derivedDataPath $DD
open $DD/Build/Products/Debug/Timezone.app

# All tests; then export UI-test screenshots to build/screenshots/
rm -rf build && xcodebuild test -scheme Timezone -destination 'platform=macOS' -derivedDataPath $DD -resultBundlePath build/Tests.xcresult
xcrun xcresulttool export attachments --path build/Tests.xcresult --output-path build/screenshots
```

Add `-only-testing:TimezoneCoreTests -only-testing:TimezoneTests` for a fast loop that skips the UI test (it takes over the mouse for ~10 s).

Layout:
- `Core/`: the pure `TimezoneCore` framework (Foundation only, no SwiftUI/AppKit).
- `App/`: the SwiftUI menu bar app.
- `CoreTests/`: Swift Testing tests of `PanelModel`, the main seam. Put behaviour tests here.
- `AppTests/`: snapshot tests that render `PanelView` with a fixed clock, time zone and locale to `AppTests/__Snapshots__/*.png`. A new or changed image is written in place and the test fails. Show the human the image diff: committing accepts it, `git checkout` rejects it. Add a snapshot for each new panel state.
- `UITests/`: one XCUITest smoke test. It launches the app, opens the panel, attaches a `panel` screenshot and quits via ⋯.
