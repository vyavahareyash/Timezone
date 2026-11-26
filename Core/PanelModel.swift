import Foundation

/// One Zone as the panel shows it.
public struct ZoneRow {
    public let label: String
    public let timeZone: TimeZone
    public let time: Date
}

/// Everything the panel shows; views only render it.
public final class PanelModel {
    private let clock: () -> Date
    private let systemTimeZone: () -> TimeZone

    public init(clock: @escaping () -> Date, systemTimeZone: @escaping () -> TimeZone) {
        self.clock = clock
        self.systemTimeZone = systemTimeZone
    }

    public var homeRow: ZoneRow {
        let zone = systemTimeZone()
        // "America/Argentina/Buenos_Aires" -> "Buenos Aires"
        let label = zone.identifier.split(separator: "/").last.map(String.init) ?? zone.identifier
        return ZoneRow(label: label.replacingOccurrences(of: "_", with: " "), timeZone: zone, time: clock())
    }
}
