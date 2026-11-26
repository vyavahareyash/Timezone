# Native SwiftUI menu bar app, macOS only

The tool lives in the macOS menu bar and is built in Swift/SwiftUI (`MenuBarExtra`) rather than Tauri/Electron or a web page. It is a personal tool used only on a Mac, so cross-platform reach buys nothing, while native gives the lightest footprint, a menu bar that feels part of the OS, and Foundation's `TimeZone` for correct DST/offset handling without a third-party tz library. Distribution is build-from-source; no App Store or notarization for now.
