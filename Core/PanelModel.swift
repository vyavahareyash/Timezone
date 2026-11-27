import Foundation
import Observation

/// One Zone as the panel shows it.
public struct ZoneRow {
    public let label: String
    public let timeZone: TimeZone
    public let time: Date
    /// The hour cells of its strip, spanning the Timeline.
    public let cells: [HourCell]
    public let isHome: Bool
    /// The Zone's date at the Cursor minus the Home zone's: -1, 0 or +1.
    public let dayOffset: Int
    /// The Zone's abbreviation at the Cursor, e.g. CET or IST.
    public let abbreviation: String
    /// The Zone's index in `PanelModel.zones`; nil for the Home zone.
    public let zoneIndex: Int?
}

/// The part of a Zone's strip within one of its local hours.
public struct HourCell {
    public let interval: DateInterval
    /// The Zone's local hour at the cell's start.
    public let hour: Int
    /// False for a stub at either end of the Timeline, where the Zone's hours don't line up with Home's.
    public let isWhole: Bool
    /// The Cursor falls within this cell.
    public let containsCursor: Bool
    /// Whether the strip prints `hour` here: every 3 local hours and under the Cursor, never on a stub.
    public var showsHour: Bool { isWhole && (hour % 3 == 0 || containsCursor) }

    /// The part of the day this cell's local hour falls in; the strip shades by it.
    public enum Band { case working, evening, night }

    /// Working 09:00–18:00, evening 18:00–22:00, night the rest, by the Zone's own local hour.
    public var band: Band {
        switch hour {
        case 9..<18: .working
        case 18..<22: .evening
        default: .night
        }
    }
}

/// Everything the panel shows; views only render it.
@Observable public final class PanelModel {
    private let clock: () -> Date
    private let systemTimeZone: () -> TimeZone
    private let cities: CityIndex
    private let locale: Locale
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
        cities: CityIndex = CityIndex(tsv: ""), locale: Locale = .current,
        loadZones: () -> Data? = { nil }, saveZones: @escaping (Data) -> Void = { _ in }
    ) {
        self.clock = clock
        self.systemTimeZone = systemTimeZone
        self.cities = cities
        self.locale = locale
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
        calendar(in: homeZone).dateInterval(of: .day, for: now)!
    }

    public var homeRow: ZoneRow {
        let zone = homeZone
        // "America/Argentina/Buenos_Aires" -> "Buenos Aires"
        let label = zone.identifier.split(separator: "/").last.map(String.init) ?? zone.identifier
        return row(label: label.replacingOccurrences(of: "_", with: " "), timeZone: zone, isHome: true, zoneIndex: nil)
    }

    /// The Home zone first, then the added Zones in the order they were added. A saved Zone whose time zone
    /// this system doesn't know is kept in `zones` but has no row.
    public var rows: [ZoneRow] {
        [homeRow] + zones.indices.compactMap { index in
            let zone = zones[index]
            return TimeZone(identifier: zone.timeZoneIdentifier).map {
                row(label: zone.label, timeZone: $0, isHome: false, zoneIndex: index)
            }
        }
    }

    private func row(label: String, timeZone: TimeZone, isHome: Bool, zoneIndex: Int?) -> ZoneRow {
        ZoneRow(label: label, timeZone: timeZone, time: cursor, cells: cells(in: timeZone), isHome: isHome,
                dayOffset: dayNumber(cursor, in: timeZone) - dayNumber(cursor, in: homeZone),
                abbreviation: abbreviation(of: timeZone, at: cursor), zoneIndex: zoneIndex)
    }

    private func calendar(in zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    /// The Timeline cut on `zone`'s own local hours.
    private func cells(in zone: TimeZone) -> [HourCell] {
        let timeline = timeline
        let local = calendar(in: zone)
        var cells: [HourCell] = []
        var start = timeline.start
        while start < timeline.end {
            let hour = local.dateInterval(of: .hour, for: start)!
            let end = min(hour.end, timeline.end)
            cells.append(HourCell(interval: DateInterval(start: start, end: end),
                                  hour: local.component(.hour, from: start),
                                  isWhole: start == hour.start && end == hour.end,
                                  containsCursor: start <= cursor && cursor < end))
            start = end
        }
        return cells
    }

    /// The short name in `locale` (CET, IST), falling back to Foundation's GMT offset where the locale has none.
    private func abbreviation(of timeZone: TimeZone, at date: Date) -> String {
        let style: NSTimeZone.NameStyle = timeZone.isDaylightSavingTime(for: date) ? .shortDaylightSaving : .shortStandard
        return timeZone.localizedName(for: style, locale: locale) ?? timeZone.abbreviation(for: date) ?? ""
    }

    /// The local calendar day of `date` in `zone`, counted in days since 1970 (as a UTC day).
    private func dayNumber(_ date: Date, in zone: TimeZone) -> Int {
        let components = calendar(in: zone).dateComponents([.year, .month, .day], from: date)
        let day = calendar(in: TimeZone(identifier: "UTC")!).date(from: components)!
        return Int(day.timeIntervalSince1970 / 86_400)
    }

    /// Cities matching `query`, for choosing a Zone to add.
    public func search(_ query: String) -> [City] { cities.search(query) }

    /// Add a Zone labelled with the city; adding the same city twice does nothing.
    public func addZone(_ city: City) {
        let zone = AddedZone(label: city.name, timeZoneIdentifier: city.timeZoneIdentifier)
        guard TimeZone(identifier: zone.timeZoneIdentifier) != nil, !zones.contains(zone) else { return }
        zones.append(zone)
        save()
    }

    /// Relabel the added Zone at `index`; a blank label, or one that would duplicate another Zone, is ignored.
    public func renameZone(at index: Int, to label: String) {
        guard zones.indices.contains(index) else { return }
        let label = label.trimmingCharacters(in: .whitespaces)
        let renamed = AddedZone(label: label, timeZoneIdentifier: zones[index].timeZoneIdentifier)
        guard !label.isEmpty, !zones.contains(renamed) else { return }
        zones[index] = renamed
        save()
    }

    /// Remove the added Zone at `index`; the Home zone is never removed.
    public func removeZone(at index: Int) {
        guard zones.indices.contains(index) else { return }
        zones.remove(at: index)
        save()
    }

    /// Move the added Zone at `from` to position `to`, clamped to the list; the Home zone stays first.
    public func moveZone(from: Int, to: Int) {
        guard zones.indices.contains(from) else { return }
        zones.insert(zones.remove(at: from), at: min(max(to, 0), zones.count))
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(zones) { saveZones(data) } // never overwrite saved Zones with nothing
    }
}
