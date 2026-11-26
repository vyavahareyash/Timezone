import AppKit
import XCTest

/// Drives the real app through the menu bar. The panel screenshot lands in the .xcresult bundle.
@MainActor
final class PanelSmokeTests: XCTestCase {
    func testPanelOpensShowsHomeZoneAndQuits() throws {
        let app = XCUIApplication()
        app.launchEnvironment["TZ"] = "Asia/Kolkata" // pins the system time zone for this launch
        app.launch()

        app.statusItems.firstMatch.click()
        XCTAssertTrue(app.staticTexts["Kolkata"].waitForExistence(timeout: 5))

        let panel = app.dialogs.firstMatch
        let homeTime = panel.staticTexts.matching(NSPredicate(format: "value MATCHES %@", "\\d{1,2}:\\d{2}.*")).firstMatch
        let atNow = homeTime.value as? String

        // Move the Cursor, close and reopen: the panel must reset to Now (onAppear/.task rerun).
        let handle = panel.otherElements["Cursor handle"]
        handle.click()
        XCTAssertTrue(panel.buttons["Back to Now"].waitForExistence(timeout: 5))
        let moved = homeTime.value as? String
        XCTAssertNotEqual(moved, atNow)
        app.statusItems.firstMatch.click() // close
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        app.statusItems.firstMatch.click() // reopen
        XCTAssertTrue(panel.staticTexts["Following Now"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(homeTime.value as? String, moved) // back at Now (not compared to atNow: the minute may have ticked)

        let screenshot = XCTAttachment(image: try XCTUnwrap(screenshot(of: panel)))
        screenshot.name = "panel"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        panel.menuButtons["More"].click()
        app.menuItems["Quit"].click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
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
