import AppKit
import XCTest

private let defaultsDomain = "com.vyavahareyash.Timezone"
private let defaultsBackup = FileManager.default.temporaryDirectory.appendingPathComponent("PanelSmokeTests-defaults.plist")

/// Runs `/usr/bin/defaults` with `arguments` and returns its exit status, or -1 if it could not start.
private func runDefaults(_ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    process.arguments = arguments
    do { try process.run() } catch { return -1 }
    process.waitUntilExit()
    return process.terminationStatus
}

/// Drives the real app through the menu bar. The panel screenshot lands in the .xcresult bundle.
@MainActor
final class PanelSmokeTests: XCTestCase {
    // setUp/tearDown are nonisolated on the Xcode 26 SDK, so the flag can't be main-actor state (Swift 6 error there).
    private nonisolated(unsafe) var hadDefaults = false

    override func setUp() {
        super.setUp()
        // The run's writes go to the app's real saved Zones: keep a copy and restore it in tearDown.
        hadDefaults = runDefaults(["export", defaultsDomain, defaultsBackup.path]) == 0
    }

    override func tearDown() {
        if hadDefaults { _ = runDefaults(["import", defaultsDomain, defaultsBackup.path]) }
        try? FileManager.default.removeItem(at: defaultsBackup)
        super.tearDown()
    }

    func testPanelOpensShowsHomeZoneAndQuits() throws {
        let app = XCUIApplication()
        app.launchEnvironment["TZ"] = "Asia/Kolkata" // pins the system time zone for this launch
        // A String here overrides the saved "zones" Data, so the app reads no saved Zones and starts clean.
        app.launchArguments = ["-zones", "none", "-homeLabels", "none"]
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        XCTAssertTrue(statusItem.isHittable, "The status item is not reachable: free menu bar space or move it to the main display.")
        statusItem.click()
        XCTAssertTrue(app.staticTexts["Kolkata"].waitForExistence(timeout: 5))

        let panel = app.dialogs.firstMatch
        let homeTime = panel.staticTexts.matching(NSPredicate(format: "value MATCHES %@", "\\d{1,2}:\\d{2}.*")).firstMatch
        let atNow = homeTime.value as? String

        // Move the Cursor, close and reopen: the panel must reset to Now (onAppear/.task rerun).
        stripPoint(panel).click()
        XCTAssertTrue(panel.buttons["Back to Now"].waitForExistence(timeout: 5))
        let moved = homeTime.value as? String
        XCTAssertNotEqual(moved, atNow)
        app.statusItems.firstMatch.click() // close
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        app.statusItems.firstMatch.click() // reopen
        XCTAssertTrue(panel.staticTexts["Following Now"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(homeTime.value as? String, moved) // back at Now (not compared to atNow: the minute may have ticked)

        // Add a Zone through the + button, the search field and a result.
        panel.buttons["Add zone"].click()
        let search = panel.textFields["Search for a city"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click()
        search.typeText("Paris")
        let result = panel.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Paris,")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.click()
        XCTAssertTrue(panel.staticTexts["Paris"].waitForExistence(timeout: 5))

        let screenshot = XCTAttachment(image: try XCTUnwrap(screenshot(of: panel)))
        screenshot.name = "panel"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Rename is in the Zone row's right-click menu.
        panel.staticTexts["Paris"].rightClick()
        app.menuItems["Rename"].click()
        XCTAssertTrue(panel.textFields["Label"].waitForExistence(timeout: 5))

        panel.menuButtons["More"].click()
        app.menuItems["Quit"].click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    }

    /// Launches with no saved Zones and opens the panel from the status item.
    private func launchAndOpenPanel() throws -> (app: XCUIApplication, panel: XCUIElement) {
        let app = XCUIApplication()
        app.launchEnvironment["TZ"] = "Asia/Kolkata"
        app.launchArguments = ["-zones", "none", "-homeLabels", "none"]
        app.launch()
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        XCTAssertTrue(statusItem.isHittable, "The status item is not reachable: free menu bar space or move it to the main display.")
        statusItem.click()
        let panel = app.dialogs.firstMatch
        XCTAssertTrue(panel.staticTexts["Following Now"].waitForExistence(timeout: 5))
        return (app, panel)
    }

    /// A point on the Home strip 80 points from the Cursor handle, toward the panel's middle so it stays on the strip.
    /// A click on the handle itself would snap the Cursor to its own quarter hour and might not change the time.
    private func stripPoint(_ panel: XCUIElement) -> XCUICoordinate {
        let handle = panel.otherElements["Cursor handle"]
        let dx: CGFloat = handle.frame.midX < panel.frame.midX ? 80 : -80
        return handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: dx, dy: 0))
    }

    /// A click on a strip moves the Cursor there, so the strip takes the press.
    func testClickingAStripMovesTheCursor() throws {
        let (app, panel) = try launchAndOpenPanel()
        stripPoint(panel).click()
        XCTAssertTrue(panel.buttons["Back to Now"].waitForExistence(timeout: 5))
        app.terminate()
    }

    /// Hovering a strip shows the left-right pointer, since dragging there moves the Cursor sideways.
    func testHoveringAStripShowsTheLeftRightPointer() throws {
        let (app, panel) = try launchAndOpenPanel()
        stripPoint(panel).hover()
        // The system pointer belongs to whichever app set it; the arrow's hot spot is its tip, the resize pointer's its middle.
        let deadline = Date() + 2
        while NSCursor.currentSystem?.hotSpot == NSCursor.arrow.hotSpot && Date() < deadline { RunLoop.current.run(until: Date() + 0.1) }
        XCTAssertNotEqual(NSCursor.currentSystem?.hotSpot, NSCursor.arrow.hotSpot, "The pointer over a strip is still the arrow")
        app.terminate()
    }

    /// Typing into a clock moves the Cursor to that time; Home can be renamed from its right-click menu.
    func testTypingAClockTimeMovesTheCursorAndHomeCanBeRenamed() throws {
        let (app, panel) = try launchAndOpenPanel()
        let homeTime = panel.staticTexts.matching(NSPredicate(format: "value MATCHES %@", "\\d{1,2}:\\d{2}.*")).firstMatch
        homeTime.click()
        let field = panel.textFields["Time"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("9:30\n")
        XCTAssertTrue(panel.buttons["Back to Now"].waitForExistence(timeout: 5))
        XCTAssertTrue((homeTime.value as? String)?.contains("9:30") == true, "Home shows \(homeTime.value ?? "nothing")")

        panel.staticTexts["Kolkata"].rightClick()
        app.menuItems["Rename"].click()
        XCTAssertTrue(panel.textFields["Label"].waitForExistence(timeout: 5))
        app.terminate()
    }

    /// `XCUIElement.screenshot()` fails for a panel on a non-main display, so crop it out of its whole screen.
    private func screenshot(of element: XCUIElement) -> NSImage? {
        let frame = element.frame // top-left origin at the main screen's top-left
        let mainHeight = NSScreen.screens[0].frame.height
        for (index, screen) in NSScreen.screens.enumerated() where index < XCUIScreen.screens.count {
            let f = screen.frame // bottom-left origin
            let screenRect = CGRect(x: f.minX, y: mainHeight - f.maxY, width: f.width, height: f.height)
            guard screenRect.contains(frame) else { continue }
            // shortcut: assumes XCUIScreen.screens and NSScreen.screens list displays in the same order; checked on 2 displays.
            let image = XCUIScreen.screens[index].screenshot().image
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
            let scale = CGFloat(cgImage.width) / screenRect.width
            let crop = frame.offsetBy(dx: -screenRect.minX, dy: -screenRect.minY)
                .applying(CGAffineTransform(scaleX: scale, y: scale))
            return cgImage.cropping(to: crop).map { NSImage(cgImage: $0, size: frame.size) }
        }
        return nil
    }
}
