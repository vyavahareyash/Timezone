## Agent skills

### Issue tracker

Issues live in GitHub Issues for vyavahareyash/Timezone (via the `gh` CLI). Read `docs/agents/issue-tracker.md` before any `gh` call: plain `gh issue view` prints nothing, use `--json`.

### Triage labels

Default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Build and test

One-time: `brew install xcodegen` and `git config core.hooksPath .githooks` (pre-push runs the fast tests). The `.xcodeproj` is generated and git-ignored; `scripts/dev` regenerates it every run.

`scripts/dev test` is the fast loop (core + snapshots), `scripts/dev test-all` adds the UI smoke test (takes over the mouse ~10 s) and exports its screenshots to `build/screenshots/`, `scripts/dev run` builds and opens the app, `scripts/dev dmg` builds the release DMG into `build/` (needs `brew install create-dmg`). Pushing a `v*` tag runs `.github/workflows/release.yml`: GitHub release plus the Homebrew cask in `vyavahareyash/homebrew-tap`. README art: `python3 scripts/hero.py` regenerates `.github/hero.svg`; the other `.github/*.svg` are hand-written. Output is filtered to results and real errors; rerun with `VERBOSE=1` if it looks wrong.

Layout: `Core/` is the pure `TimezoneCore` framework (Foundation only), `App/` the SwiftUI menu bar app; tests in `CoreTests/` (behaviour), `AppTests/` (panel snapshots), `UITests/` (real-app smoke test).

**Shell blocks**: the shell blocks inline interpreters (`python3 - <<EOF`) and `mktemp`. Change files with the Edit tool; when a command you need is blocked, give the user its exact text to run.

**Testing**: before writing or fixing a test, or when a snapshot goes red, read `docs/agents/testing.md`.
