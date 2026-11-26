# Testing

Three test targets, all run by the `Timezone` scheme (commands in `AGENTS.md`).

## `CoreTests/`: behaviour

Swift Testing tests of `PanelModel`, the main seam: drive it through its actions with a fixed clock and time zone, assert on the state it exposes (instants and components, never formatted strings). Behaviour tests go here.

## `AppTests/`: panel snapshots

Render `PanelView` with a fixed clock, time zone, locale and color scheme to `AppTests/__Snapshots__/<name>.png`, compared byte for byte.

- A new or changed image is written in place and the test fails. Show the human the image diff: committing accepts it, `git checkout` rejects it. The pre-push hook blocks pushes while a snapshot is red.
- Every change to what the panel shows needs a snapshot of the new state (`CODING_STANDARDS.md`).
- `ImageRenderer` can't draw AppKit-backed controls: the ⋯ menu renders as a yellow 🚫 placeholder. Expected.
- The target is hosted in `Timezone.app` (it uses `@testable import Timezone`).

## `UITests/`: real-app smoke test

One XCUITest launches the built app with `TZ` pinned, clicks the status item, attaches a `panel` screenshot, and quits via ⋯. It takes over the mouse for ~10 s, so the fast loop and the pre-push hook skip it.

- The panel appears as a `Dialog` in the accessibility tree, not a window.
- `XCUIElement.screenshot()` fails for a panel on a non-main display, so the test crops it from its whole screen.
- Export screenshots after a run: `xcrun xcresulttool export attachments --path build/Tests.xcresult --output-path build/screenshots` (the panel is `panel_*.png`; `manifest.json` maps names).

## Build location

Build products go to `~/Library/Developer/Xcode/DerivedData/Timezone-cli`, outside `~/Documents`: test apps are ad-hoc signed, so their identity changes every build and macOS would re-ask for Documents access each run, blocking the UI test.
