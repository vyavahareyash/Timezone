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
    private let cities: CityIndex
    private let saveZones: (Data) -> Void

    private var homeZone: TimeZone
    public private(set) var now: Date
    /// The moment every Row shows.
    public private(set) var cursor: Date
    public private(set) var isFollowingNow = true

    /// The user's added Zones (the Home zone is separate), persisted through `saveZones`.
    public private(set) var zones: [AddedZone] = []

    public struct AddedZone: Codable, Equatable {
        public let label: String
        public let timeZoneIdentifier: String
    }

    public init(
        clock: @escaping () -> Date, systemTimeZone: @escaping () -> TimeZone,
        cities: CityIndex = CityIndex(tsv: ""),
        loadZones: () -> Data? = { nil }, saveZones: @escaping (Data) -> Void = { _ in }
    ) {
        self.clock = clock
        self.systemTimeZone = systemTimeZone
        self.cities = cities
        self.saveZones = saveZones
        zones = loadZones().flatMap { try? JSONDecoder().decode([AddedZone].self, from: $0) } ?? []
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

    /// Move the Cursor to `date`, snapped to 15 minutes from the Timeline's start and kept within the
    /// Timeline. Ends Following Now.
    public func moveCursor(to date: Date) {
        let timeline = timeline
        let step = Self.cursorStep
        let snapped = timeline.start + (date.timeIntervalSince(timeline.start) / step).rounded() * step
        cursor = min(max(snapped, timeline.start), timeline.end)
        isFollowingNow = false
    }

    /// Move the Cursor by whole 15-minute steps (negative goes back).
    public func nudgeCursor(steps: Int) {
        moveCursor(to: cursor + Double(steps) * Self.cursorStep)
    }

    private static let cursorStep: TimeInterval = 15 * 60

    /// Return the Cursor to Now and resume Following Now.
    public func backToNow() { open() }

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
        return row(label: label.replacingOccurrences(of: "_", with: " "), timeZone: zone)
    }

    /// The Home zone first, then the added Zones in the order they were added.
    public var rows: [ZoneRow] {
        [homeRow] + zones.compactMap { zone in
            TimeZone(identifier: zone.timeZoneIdentifier).map { row(label: zone.label, timeZone: $0) }
        }
    }

    private func row(label: String, timeZone: TimeZone) -> ZoneRow {
        let timeline = timeline
        let cells = stride(from: timeline.start, to: timeline.end, by: 3600).map {
            DateInterval(start: $0, end: min($0 + 3600, timeline.end))
        }
        return ZoneRow(label: label, timeZone: timeZone, time: cursor, cells: cells)
    }

    /// Cities matching `query`, for choosing a Zone to add.
    public func search(_ query: String) -> [City] { cities.search(query) }

    /// Add a Zone labelled with the city; adding the same city twice does nothing.
    public func addZone(_ city: City) {
        let zone = AddedZone(label: city.name, timeZoneIdentifier: city.timeZoneIdentifier)
        guard TimeZone(identifier: zone.timeZoneIdentifier) != nil, !zones.contains(zone) else { return }
        zones.append(zone)
        if let data = try? JSONEncoder().encode(zones) { saveZones(data) } // never overwrite saved Zones with nothing
    }
}
