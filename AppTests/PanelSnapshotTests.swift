import AppKit
import SwiftUI
import Testing
import TimezoneCore
@testable import Timezone

/// Renders the panel to PNGs under __Snapshots__/. A changed or new image is written in place and
/// the test fails: review it in the git diff, commit to accept, `git checkout` to reject.
@MainActor
struct PanelSnapshotTests {
    static let now = Date(timeIntervalSince1970: 1_790_000_000) // 2026-09-21 14:13:20 UTC

    @Test func homeZone24Hour() throws {
        try assertSnapshot("home-24h", zone: "Europe/Berlin", locale: "en_GB")
    }

    @Test func homeZone12Hour() throws {
        try assertSnapshot("home-12h", zone: "America/Los_Angeles", locale: "en_US")
    }

    @Test func homeZoneDarkMode() throws {
        try assertSnapshot("home-dark", zone: "Asia/Kolkata", locale: "en_GB", colorScheme: .dark)
    }

    @Test func fallBackDayHas25HourTimeline() throws {
        let fallBackDay = Date(timeIntervalSince1970: 1_792_929_600) // 2026-10-25 12:00 UTC, Berlin falls back that night
        try assertSnapshot("home-25h", zone: "Europe/Berlin", locale: "en_GB", at: fallBackDay)
    }

    private func assertSnapshot(
        _ name: String, zone: String, locale: String, colorScheme: ColorScheme = .light, at instant: Date = now,
        filePath: String = #filePath
    ) throws {
        let model = PanelModel(clock: { instant }, systemTimeZone: { TimeZone(identifier: zone)! })
        let view = PanelView(model: model)
            .background(.background)
            .environment(\.locale, Locale(identifier: locale))
            .environment(\.colorScheme, colorScheme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))

        let url = URL(filePath: filePath).deletingLastPathComponent().appending(path: "__Snapshots__/\(name).png")
        let reference = try? Data(contentsOf: url)
        guard reference != png else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: url)
        Issue.record(reference == nil
            ? "Recorded new snapshot \(name).png: review and commit it"
            : "Snapshot \(name).png changed: review the git diff, commit to accept or git checkout to reject")
    }
}
