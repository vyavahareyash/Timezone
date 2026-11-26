import Foundation
import Observation

/// One Zone as the panel shows it.
public struct ZoneRow {
    public let label: String
    public let timeZone: TimeZone
    public let time: Date
    /// The hour cells of its strip, spanning the Timeline.
    public let cells: [DateInterval]
}

/// Everything the panel shows; views only render it.
@Observable public final class PanelModel {
    private let clock: () -> Date
    private let systemTimeZone: () -> TimeZone

    private var homeZone: TimeZone
    public private(set) var now: Date
    /// The moment every Row shows.
    public private(set) var cursor: Date
    public private(set) var isFollowingNow = true

    public init(clock: @escaping () -> Date, systemTimeZone: @escaping () -> TimeZone) {
        self.clock = clock
        self.systemTimeZone = systemTimeZone
        homeZone = systemTimeZone()
        let now = clock()
        self.now = now
        cursor = now
    }

    /// The panel opened: the Cursor starts at Now, Following Now.
    public func open() {
        tick()
        cursor = now
        isFollowingNow = true
    }

    /// Time passed: advance Now (rolling the Timeline at Home midnight), and the Cursor with it while
    /// Following Now. Also picks up a system time zone change.
    public func tick() {
        homeZone = systemTimeZone()
        now = clock()
        if isFollowingNow { cursor = now }
    }

    /// Today in the Home zone, midnight to midnight: 23, 24 or 25 hours.
    public var timeline: DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = homeZone
        return calendar.dateInterval(of: .day, for: now)!
    }

    public var homeRow: ZoneRow {
        let zone = homeZone
        // "America/Argentina/Buenos_Aires" -> "Buenos Aires"
        let label = zone.identifier.split(separator: "/").last.map(String.init) ?? zone.identifier
        let timeline = timeline
        let cells = stride(from: timeline.start, to: timeline.end, by: 3600).map {
            DateInterval(start: $0, end: min($0 + 3600, timeline.end))
        }
        return ZoneRow(label: label.replacingOccurrences(of: "_", with: " "), timeZone: zone, time: cursor, cells: cells)
    }
}
