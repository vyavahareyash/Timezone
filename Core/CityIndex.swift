import Foundation

/// A searchable city from the bundled GeoNames extract (ADR-0003).
public struct City: Equatable, Sendable {
    public let name: String
    public let countryCode: String
    public let timeZoneIdentifier: String
}

/// Offline city search: case- and diacritic-insensitive prefix match on the name, most populous first.
public struct CityIndex: Sendable {
    private struct Entry: Sendable { let key: String; let city: City }
    private let entries: [Entry]

    /// `tsv` lines are "name<TAB>country code<TAB>IANA time zone", most populous first.
    public init(tsv: String) {
        entries = tsv.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 3 else { return nil }
            let name = String(fields[0])
            return Entry(key: Self.fold(name), city: City(name: name, countryCode: String(fields[1]), timeZoneIdentifier: String(fields[2])))
        }
    }

    /// The extract bundled with TimezoneCore.
    public static func bundled() -> CityIndex {
        final class Token {}
        let url = Bundle(for: Token.self).url(forResource: "cities", withExtension: "tsv")!
        return CityIndex(tsv: try! String(contentsOf: url, encoding: .utf8))
    }

    public func search(_ query: String, limit: Int = 8) -> [City] {
        let key = Self.fold(query.trimmingCharacters(in: .whitespaces))
        guard !key.isEmpty else { return [] }
        return entries.lazy.filter { $0.key.hasPrefix(key) }.prefix(limit).map(\.city)
    }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
