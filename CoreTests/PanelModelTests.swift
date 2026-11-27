import Foundation
import Testing
import TimezoneCore

private func utc(_ iso: String) -> Date { try! Date(iso, strategy: .iso8601) }
private let berlin = TimeZone(identifier: "Europe/Berlin")!

struct PanelModelTests {
    @Test func homeZoneRowShowsSystemCityAndTheClockTime() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let model = PanelModel(clock: { now }, systemTimeZone: { TimeZone(identifier: "America/Los_Angeles")! })

        let home = model.homeRow
        #expect(home.label == "Los Angeles")
        #expect(home.timeZone.identifier == "America/Los_Angeles")
        #expect(home.time == now)
    }

    @Test(arguments: [
        // now, Berlin midnight, next Berlin midnight, hours
        ("2026-09-21T14:13:20Z", "2026-09-20T22:00:00Z", "2026-09-21T22:00:00Z", 24),
        ("2026-03-29T12:00:00Z", "2026-03-28T23:00:00Z", "2026-03-29T22:00:00Z", 23), // spring forward
        ("2026-10-25T12:00:00Z", "2026-10-24T22:00:00Z", "2026-10-25T23:00:00Z", 25), // fall back
    ])
    func timelineIsTodayInTheHomeZoneWithOneCellPerHour(now: String, start: String, end: String, hours: Int) {
        let model = PanelModel(clock: { utc(now) }, systemTimeZone: { berlin })

        #expect(model.timeline == DateInterval(start: utc(start), end: utc(end)))
        let cells = model.homeRow.cells
        #expect(cells.count == hours)
        #expect(cells.first?.interval.start == utc(start))
        #expect(cells.last?.interval.end == utc(end))
        #expect(cells.allSatisfy { $0.interval.duration == 3600 })
    }

    @Test func openingPlacesTheCursorAtNowFollowingNow() {
        var clock = utc("2026-09-21T14:13:20Z")
        let model = PanelModel(clock: { clock }, systemTimeZone: { berlin })

        clock = utc("2026-09-21T17:00:00Z")
        model.open()

        #expect(model.now == utc("2026-09-21T17:00:00Z"))
        #expect(model.cursor == utc("2026-09-21T17:00:00Z"))
        #expect(model.isFollowingNow)
    }

    @Test func tickAdvancesNowAndTheCursorWhileFollowingNow() {
        var clock = utc("2026-09-21T14:13:20Z")
        let model = PanelModel(clock: { clock }, systemTimeZone: { berlin })
        model.open()

        clock = utc("2026-09-21T14:14:20Z")
        #expect(model.now == utc("2026-09-21T14:13:20Z")) // only actions read the clock
        model.tick()

        #expect(model.now == utc("2026-09-21T14:14:20Z"))
        #expect(model.cursor == utc("2026-09-21T14:14:20Z"))
        #expect(model.homeRow.time == utc("2026-09-21T14:14:20Z"))
    }

    @Test func tickingPastHomeMidnightRollsTheTimelineToTheNewDay() {
        var clock = utc("2026-09-21T21:59:59Z") // 23:59:59 in Berlin
        let model = PanelModel(clock: { clock }, systemTimeZone: { berlin })
        model.open()

        clock = utc("2026-09-21T22:00:01Z")
        model.tick()

        #expect(model.timeline == DateInterval(start: utc("2026-09-21T22:00:00Z"), end: utc("2026-09-22T22:00:00Z")))
        #expect(model.cursor == utc("2026-09-21T22:00:01Z"))
    }

    @Test func movingTheCursorSnapsToQuarterHoursAndEndsFollowingNow() {
        let model = PanelModel(clock: { utc("2026-09-21T14:13:20Z") }, systemTimeZone: { berlin })
        model.open()

        model.moveCursor(to: utc("2026-09-21T15:08:00Z"))
        #expect(model.cursor == utc("2026-09-21T15:15:00Z"))
        #expect(!model.isFollowingNow)
        #expect(model.homeRow.time == utc("2026-09-21T15:15:00Z"))
    }

    @Test func movingTheCursorStaysWithinTheTimeline() {
        let model = PanelModel(clock: { utc("2026-09-21T14:13:20Z") }, systemTimeZone: { berlin })

        model.moveCursor(to: utc("2026-09-25T00:00:00Z"))
        #expect(model.cursor == utc("2026-09-21T22:00:00Z"))
        model.moveCursor(to: utc("2026-09-01T00:00:00Z"))
        #expect(model.cursor == utc("2026-09-20T22:00:00Z"))
    }

    @Test func nudgingMovesByQuarterHoursAndStopsAtTheEdges() {
        let model = PanelModel(clock: { utc("2026-09-21T14:00:00Z") }, systemTimeZone: { berlin })

        model.nudgeCursor(steps: 1)
        #expect(model.cursor == utc("2026-09-21T14:15:00Z"))
        model.nudgeCursor(steps: -2)
        #expect(model.cursor == utc("2026-09-21T13:45:00Z"))
        model.nudgeCursor(steps: -1000)
        #expect(model.cursor == utc("2026-09-20T22:00:00Z"))
    }

    @Test func ticksDoNotMoveAMovedCursorAndBackToNowResumesFollowing() {
        var clock = utc("2026-09-21T14:00:00Z")
        let model = PanelModel(clock: { clock }, systemTimeZone: { berlin })
        model.moveCursor(to: utc("2026-09-21T09:00:00Z"))

        clock = utc("2026-09-21T14:05:00Z")
        model.tick()
        #expect(model.cursor == utc("2026-09-21T09:00:00Z"))

        model.backToNow()
        #expect(model.cursor == utc("2026-09-21T14:05:00Z"))
        #expect(model.isFollowingNow)
        clock = utc("2026-09-21T14:06:00Z")
        model.tick()
        #expect(model.cursor == utc("2026-09-21T14:06:00Z"))
    }

    @Test func homeZoneAndTimelineFollowASystemTimeZoneChange() {
        var zone = berlin
        let model = PanelModel(clock: { utc("2026-09-21T14:13:20Z") }, systemTimeZone: { zone })
        model.open()

        zone = TimeZone(identifier: "Asia/Kolkata")!
        #expect(model.homeRow.label == "Berlin") // only actions read the system time zone
        model.tick()

        #expect(model.homeRow.label == "Kolkata")
        #expect(model.timeline == DateInterval(start: utc("2026-09-20T18:30:00Z"), end: utc("2026-09-21T18:30:00Z")))
    }
}

struct ZoneStripTests {
    /// A model whose saved Zones are `zones` (label, IANA identifier), Home being Berlin.
    private func makeModel(now: String, zones: [(String, String)] = []) -> PanelModel {
        let json = try! JSONEncoder().encode(zones.map { ["label": $0.0, "timeZoneIdentifier": $0.1] })
        return PanelModel(clock: { utc(now) }, systemTimeZone: { berlin }, locale: Locale(identifier: "en_GB"),
                          loadZones: { json })
    }

    @Test func homeCellsAreWholeHoursFromMidnightAndHomeIsMarked() {
        let model = makeModel(now: "2026-09-21T14:13:20Z", zones: [("Pune", "Asia/Kolkata")])

        #expect(model.rows.map(\.isHome) == [true, false])
        #expect(model.rows[0].cells.map(\.hour) == Array(0..<24))
        #expect(model.rows[0].cells.allSatisfy { $0.isWhole })
    }

    @Test func halfHourZoneCutsItsCellsOnItsOwnHoursWithPartialEnds() {
        let model = makeModel(now: "2026-09-21T14:13:20Z", zones: [("Pune", "Asia/Kolkata")])
        let cells = model.rows[1].cells

        // Pune's hours start on the half hour of Home's: a half-hour stub, then whole hours.
        #expect(cells.first?.interval == DateInterval(start: utc("2026-09-20T22:00:00Z"), end: utc("2026-09-20T22:30:00Z")))
        #expect(cells.first?.isWhole == false)
        #expect(cells[1].interval == DateInterval(start: utc("2026-09-20T22:30:00Z"), end: utc("2026-09-20T23:30:00Z")))
        #expect(cells[1].hour == 4)
        #expect(cells[1].isWhole)
        #expect(cells.last?.interval.end == utc("2026-09-21T22:00:00Z"))
        #expect(cells.last?.isWhole == false)
    }

    @Test func quarterHourZoneCellsAreShiftedByFortyFiveMinutes() {
        let model = makeModel(now: "2026-09-21T14:13:20Z", zones: [("Kathmandu", "Asia/Kathmandu")])
        let cells = model.rows[1].cells

        // Kathmandu's hours start at 04:00 local = 22:15 UTC: a quarter-hour stub, then whole hours.
        #expect(cells.first?.interval == DateInterval(start: utc("2026-09-20T22:00:00Z"), end: utc("2026-09-20T22:15:00Z")))
        #expect(cells.first?.isWhole == false)
        #expect(cells[1].interval.start == utc("2026-09-20T22:15:00Z"))
        #expect(cells[1].hour == 4)
        #expect(cells[2].hour == 5)
    }

    @Test func dayOffsetIsTheZonesDateAtTheCursorRelativeToHome() {
        let model = makeModel(now: "2026-09-21T14:13:20Z",
                              zones: [("Auckland", "Pacific/Auckland"), ("Los Angeles", "America/Los_Angeles")])

        model.moveCursor(to: utc("2026-09-21T16:00:00Z")) // Berlin 18:00, Auckland 04:00 the 22nd, LA 09:00 the 21st
        #expect(model.rows.map(\.dayOffset) == [0, 1, 0])

        model.moveCursor(to: utc("2026-09-21T06:00:00Z")) // Berlin 08:00, Auckland 18:00 the 21st, LA 23:00 the 20th
        #expect(model.rows.map(\.dayOffset) == [0, 0, -1])
    }

    @Test(arguments: [
        // typed, in, Cursor (Timeline: Berlin's 2026-09-21, 22:00Z the day before to 22:00Z)
        ("10:07", "Asia/Kolkata", "2026-09-21T04:37:00Z"), // to the exact minute, no snapping
        ("2:30 pm", "Europe/Berlin", "2026-09-21T12:30:00Z"),
        ("2:30\u{202F}PM", "Europe/Berlin", "2026-09-21T12:30:00Z"), // as en_US formats it
        ("9", "Europe/Berlin", "2026-09-21T07:00:00Z"),
        ("1430", "Europe/Berlin", "2026-09-21T12:30:00Z"),
        ("12 am", "Europe/Berlin", "2026-09-20T22:00:00Z"),
        ("8:00", "Pacific/Auckland", "2026-09-21T20:00:00Z"), // Auckland's next day: 08:00 on the 21st is before the Timeline
    ])
    func typingAZonesTimeMovesTheCursorThereAndEndsFollowingNow(typed: String, zone: String, cursor: String) {
        let model = makeModel(now: "2026-09-21T14:13:20Z")

        #expect(model.moveCursor(toLocalTime: typed, in: TimeZone(identifier: zone)!))
        #expect(model.cursor == utc(cursor))
        #expect(!model.isFollowingNow)
    }

    @Test(arguments: ["", "abc", "25:00", "9:60", "13 pm", "0 am", "9:3"])
    func textThatIsNotATimeLeavesTheCursor(typed: String) {
        let model = makeModel(now: "2026-09-21T14:13:20Z")

        #expect(!model.moveCursor(toLocalTime: typed, in: berlin))
        #expect(model.cursor == utc("2026-09-21T14:13:20Z"))
        #expect(model.isFollowingNow)
    }

    @Test func aTimeInADSTGapIsRefused() {
        let model = makeModel(now: "2026-03-29T12:00:00Z") // Berlin skips 02:00–03:00 that night

        #expect(!model.moveCursor(toLocalTime: "2:30", in: berlin))
        #expect(model.moveCursor(toLocalTime: "3:30", in: berlin))
        #expect(model.cursor == utc("2026-03-29T01:30:00Z"))
    }

    @Test func cellHoursFollowALocalDSTChange() {
        // Los Angeles falls back on 2026-11-01 while Home (Berlin) has a plain 24-hour day.
        let model = makeModel(now: "2026-11-01T12:00:00Z", zones: [("Los Angeles", "America/Los_Angeles")])
        let hours = model.rows[1].cells.map(\.hour)

        // Berlin midnight is 16:00 PDT the day before; LA's clock then repeats 01:00 (PDT, then PST).
        #expect(hours.first == 16)
        #expect(hours.filter { $0 == 1 }.count == 2)
        #expect(model.rows[1].cells.allSatisfy { $0.isWhole })
    }

    @Test func abbreviationIsTheZonesAtTheCursorAndFlipsAcrossADSTChange() {
        let model = makeModel(now: "2026-03-29T12:00:00Z", zones: [("Pune", "Asia/Kolkata")])
        // en_GB has no short name for Kolkata, so it falls back to the GMT offset.
        #expect(model.rows.map(\.abbreviation) == ["CEST", "GMT+5:30"])

        model.moveCursor(to: utc("2026-03-29T00:30:00Z")) // Berlin's spring-forward is at 01:00 UTC
        #expect(model.rows.map(\.abbreviation) == ["CET", "GMT+5:30"])
    }
}

struct ZoneSearchTests {
    private static let fixture = CityIndex(tsv: """
        Zürich\tCH\tEurope/Zurich
        Pune\tIN\tAsia/Kolkata
        San Francisco\tUS\tAmerica/Los_Angeles
        San Francisco\tAR\tAmerica/Argentina/Cordoba
        Sanaa\tYE\tAsia/Aden
        """)

    @Test(arguments: [("pune", "Pune"), ("ZURICH", "Zürich"), ("zür", "Zürich"), ("san fr", "San Francisco")])
    func searchIsCaseAndDiacriticInsensitivePrefix(query: String, name: String) {
        #expect(Self.fixture.search(query).first?.name == name)
    }

    @Test func resultsKeepPopulationOrderAndAreCapped() {
        #expect(Self.fixture.search("san").map(\.countryCode) == ["US", "AR", "YE"])
        #expect(Self.fixture.search("san", limit: 2).count == 2)
        #expect(Self.fixture.search("  ").isEmpty)
    }

    @Test func choosingACityAddsALabelledZoneAfterHomeThatSurvivesRelaunch() {
        var saved: Data?
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        func make() -> PanelModel {
            PanelModel(clock: { now }, systemTimeZone: { berlin }, cities: Self.fixture,
                       loadZones: { saved }, saveZones: { saved = $0 })
        }
        let model = make()
        #expect(model.rows.count == 1) // first launch: Home only

        model.addZone(model.search("pune")[0])
        model.addZone(model.search("pune")[0]) // duplicate ignored

        #expect(model.rows.map(\.label) == ["Berlin", "Pune"])
        #expect(model.rows[1].timeZone.identifier == "Asia/Kolkata")
        #expect(model.rows[1].time == model.cursor)
        #expect(make().rows.map(\.label) == ["Berlin", "Pune"])
    }

    @Test func bundledListFindsTheTicketsCities() {
        let index = CityIndex.bundled()
        #expect(index.search("pune").first?.timeZoneIdentifier == "Asia/Kolkata")
        #expect(index.search("san fr").first?.timeZoneIdentifier == "America/Los_Angeles")
        #expect(index.search("zurich").first?.name == "Zürich")
        #expect(index.search("a").count == 8)
    }
}

struct ZoneEditingTests {
    private static let fixture = CityIndex(tsv: """
        Pune\tIN\tAsia/Kolkata
        Mumbai\tIN\tAsia/Kolkata
        San Francisco\tUS\tAmerica/Los_Angeles
        Zürich\tCH\tEurope/Zurich
        """)
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    /// The saved Zones survive a relaunch: each launch reads what the last one wrote.
    private final class Store { var data: Data? }

    private func launch(_ store: Store) -> PanelModel {
        PanelModel(clock: { now }, systemTimeZone: { berlin }, cities: Self.fixture,
                   loadZones: { store.data }, saveZones: { store.data = $0 })
    }

    @Test func renamingAZoneChangesItsLabelAndSurvivesRelaunch() {
        let store = Store()
        let model = launch(store)
        model.addZone(model.search("pune")[0])

        model.renameZone(at: 0, to: "Office")

        #expect(model.rows.map(\.label) == ["Berlin", "Office"])
        #expect(launch(store).rows.map(\.label) == ["Berlin", "Office"])
    }

    @Test func renamingHomeIsKeptForItsTimeZoneAcrossTravelAndRelaunch() {
        var saved: Data?
        var system = berlin
        func launch() -> PanelModel {
            PanelModel(clock: { now }, systemTimeZone: { system },
                       loadHomeLabels: { saved }, saveHomeLabels: { saved = $0 })
        }
        let model = launch()

        model.renameHome(to: "  Home ")
        #expect(model.homeRow.label == "Home")
        #expect(launch().homeRow.label == "Home")

        system = TimeZone(identifier: "Asia/Tokyo")!
        model.tick()
        #expect(model.homeRow.label == "Tokyo") // travelling: the new zone's own name
        system = berlin
        model.tick()
        #expect(model.homeRow.label == "Home") // back home: the user's name again

        model.renameHome(to: " ")
        #expect(model.homeRow.label == "Berlin") // blank restores the system's name
        #expect(launch().homeRow.label == "Berlin")
    }

    @Test func removingAZoneDeletesItAndSurvivesRelaunch() {
        let store = Store()
        let model = launch(store)
        model.addZone(model.search("pune")[0])
        model.addZone(model.search("san fr")[0])

        model.removeZone(at: 0)

        #expect(model.rows.map(\.label) == ["Berlin", "San Francisco"])
        #expect(launch(store).rows.map(\.label) == ["Berlin", "San Francisco"])
    }

    @Test func draggingAZoneReordersItAndSurvivesRelaunch() {
        let store = Store()
        let model = launch(store)
        model.addZone(model.search("pune")[0])
        model.addZone(model.search("san fr")[0])
        model.addZone(model.search("zür")[0])

        model.moveZone(from: 2, to: 0)

        #expect(model.rows.map(\.label) == ["Berlin", "Zürich", "Pune", "San Francisco"])
        #expect(launch(store).rows.map(\.label) == ["Berlin", "Zürich", "Pune", "San Francisco"])
    }

    @Test func movesClampToTheListAndStaleIndexesAreIgnored() {
        let model = launch(Store())
        model.addZone(model.search("pune")[0])
        model.addZone(model.search("san fr")[0])

        model.moveZone(from: 0, to: 99)
        #expect(model.rows.map(\.label) == ["Berlin", "San Francisco", "Pune"])
        model.moveZone(from: 1, to: -5)
        #expect(model.rows.map(\.label) == ["Berlin", "Pune", "San Francisco"])

        model.renameZone(at: 5, to: "Nowhere")
        model.removeZone(at: 5)
        model.moveZone(from: 5, to: 0)
        #expect(model.rows.map(\.label) == ["Berlin", "Pune", "San Francisco"])
    }

    @Test func twoZonesCanShareATimeZoneUnderDifferentLabels() {
        let model = launch(Store())
        model.addZone(model.search("pune")[0])
        model.addZone(model.search("mumbai")[0])

        #expect(model.rows.map(\.label) == ["Berlin", "Pune", "Mumbai"])
        #expect(model.rows[1].timeZone == model.rows[2].timeZone)
    }

    @Test func renamingIgnoresBlankLabelsAndLabelsThatWouldDuplicateAZone() {
        let model = launch(Store())
        model.addZone(model.search("pune")[0])
        model.addZone(model.search("mumbai")[0])

        model.renameZone(at: 1, to: "   ")
        model.renameZone(at: 1, to: "Pune") // Mumbai's time zone under Pune's label: a duplicate
        #expect(model.rows.map(\.label) == ["Berlin", "Pune", "Mumbai"])

        model.renameZone(at: 1, to: "  Office  ")
        #expect(model.rows.map(\.label) == ["Berlin", "Pune", "Office"])
    }

    @Test func homeStaysFirstWhateverTheZonesDo() {
        let model = launch(Store())
        model.addZone(model.search("pune")[0])
        model.addZone(model.search("san fr")[0])

        model.moveZone(from: 1, to: 0)
        model.removeZone(at: 0)

        #expect(model.rows.map(\.label) == ["Berlin", "Pune"])
        #expect(model.rows.first?.isHome == true)
    }

    @Test func aSavedZoneWithAnUnknownTimeZoneIsHiddenButKeptThroughEdits() {
        let store = Store()
        store.data = try! JSONEncoder().encode([["label": "Nowhere", "timeZoneIdentifier": "Mars/Olympus"],
                                                ["label": "Pune", "timeZoneIdentifier": "Asia/Kolkata"]])
        let model = launch(store)

        #expect(model.rows.map(\.label) == ["Berlin", "Pune"])
        #expect(model.rows.map(\.zoneIndex) == [nil, 1]) // a row's index is its Zone's, even past a hidden one
        model.addZone(model.search("san fr")[0]) // any edit saves every stored Zone
        #expect(launch(store).zones.map(\.label) == ["Nowhere", "Pune", "San Francisco"])
    }
}
