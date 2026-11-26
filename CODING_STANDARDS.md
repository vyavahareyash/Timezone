# Coding standards

Judgement calls for review. Mechanical rules live in tooling (warnings are errors; the pre-push hook runs the tests).

- **Every change to what the panel shows comes with a new or updated snapshot** in `AppTests/__Snapshots__/`, covering the new state (e.g. a Day offset, a 25-hour Timeline, working-hours shading). Reading view code can't prove what renders; the snapshot can.
- **`PanelModel` reads its injected clock and system time zone only inside actions** (`open`, `tick`, …) and stores the result; everything else it exposes derives from stored properties. SwiftUI re-renders an `@Observable` model only when a stored property changes, so a value read live in a computed property goes stale on screen.
