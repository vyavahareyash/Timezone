# Testing

Three test targets, all run by the `Timezone` scheme via `scripts/dev` (modes in `AGENTS.md`). Run one suite or test with `scripts/dev test-one TimezoneCoreTests/ZoneEditingTests`, or `TimezoneTests/PanelSnapshotTests/<test>` for a snapshot.

## `CoreTests/`: behaviour

Swift Testing tests of `PanelModel`, the main seam: drive it through its actions with a fixed clock and time zone, assert on the state it exposes (instants and components, never formatted strings). Behaviour tests go here.

## `AppTests/`: panel snapshots

Render `PanelView` with a fixed clock, time zone, locale and color scheme to `AppTests/__Snapshots__/<name>.png`, compared byte for byte.

- A new or changed image is written in place and the test fails. Show the human the image diff: committing accepts it, `git checkout` rejects it. The pre-push hook blocks pushes while a snapshot is red.
- Every change to what the panel shows needs a snapshot of the new state (`CODING_STANDARDS.md`).
- `ImageRenderer` can't draw AppKit-backed controls: the ⋯ menu, a `TextField`, and `draggable`/`dropDestination` render as a yellow 🚫 placeholder that hides what is under them. Expected. Where a snapshot must show a row, use a SwiftUI gesture for drag instead.
- `ImageRenderer` draws nothing inside a `ScrollView`: the content renders blank. Keep the scrolling branch out of snapshots and verify it by reading the code.
- `ImageRenderer` does run `onAppear`, which calls `model.open()` and resets the Cursor to Now. Snapshot a moved Cursor with `PanelView(model:opensAtNow: false)`.
- To see a test's output, `print("DEBUG: ...")`; `scripts/dev` keeps those lines. `VERBOSE=1` dumps multi-KB compiler command lines.
- A red `scripts/dev test` rewrites snapshots in place, so `git stash` or a branch switch around it leaves modified PNGs that block `git stash pop`. To compare against a clean tree, use a `git worktree`. Experiments with a view change rewrite the committed PNGs as well: restore them with `git checkout -- AppTests/__Snapshots__/` before the next run.
- The target is hosted in `Timezone.app` (it uses `@testable import Timezone`).

## `UITests/`: real-app smoke test

One XCUITest launches the built app with `TZ` pinned, clicks the status item, adds a Zone (Paris) through + and the search field, attaches a `panel` screenshot, and quits via ⋯. It takes over the mouse for ~10 s, so the fast loop and the pre-push hook skip it.

The run launches with `-zones none`, so the app ignores your saved Zones and starts empty (`defaults delete` is not needed and was unreliable from the test runner). The run still writes its Zone to the app's `com.vyavahareyash.Timezone` defaults, so it backs them up before the run and restores the backup in tearDown. If a run is killed mid-way, the backup is in the temporary directory as `PanelSmokeTests-defaults.plist`.

- On a laptop display the status item can be hidden in the menu bar overflow (notch or crowded bar). It is not hittable (the test sees it at an odd frame) and the overflow control isn't in the accessibility tree, so the smoke test skips instead of failing. Make room in the menu bar (quit other menu bar apps) and rerun; a skip is not a code failure.
- The panel appears as a `Dialog` in the accessibility tree, not a window.
- `XCUIElement.screenshot()` fails for a panel on a non-main display, so the test crops it from its whole screen.
- Static texts expose `value`, not `label`. Don't compare the time against Now (the minute can tick between reads); compare it with the moved time.
- Any accessibility element overlapping the Cursor handle (a label, a per-cell view) makes the click on it miss, and the failed `XCTAssert` is soft, so the test fails later at "Back to Now". Mark decoration `.accessibilityHidden(true)`.
- `click()` on a focusable element in the panel works, and `typeText` on a clicked TextField works (the add-Zone search, #11). `press(forDuration:thenDragTo:)` does not move the Cursor, and `typeKey` or a click at an offset from the element closes the panel.
- Clearing saved defaults from the test runner (`defaults delete` via `Process`) did not reliably change what the app reads. Override the value with a launch argument instead, as the add-Zone test does with `app.launchArguments = ["-zones", "none"]`.
- `scripts/dev test-all` exports screenshots to `build/screenshots/` (the panel is `panel_*.png`; `manifest.json` maps names).
- `scripts/dev test-all` prints a `Test Case … passed|failed` line per XCTest case, UI tests included, so the summary no longer hides them. For the full per-test tree, read the bundle: `xcrun xcresulttool get test-results tests --path build/Tests.xcresult | grep -E '"(name|result)"'`.

## Build location

Build products go to `~/Library/Developer/Xcode/DerivedData/Timezone-cli`, outside `~/Documents`: test apps are ad-hoc signed, so their identity changes every build and macOS would re-ask for Documents access each run, blocking the UI test.

To reproduce a clean build, delete that directory first: `rm -rf ~/Library/Developer/Xcode/DerivedData/Timezone-cli`.
