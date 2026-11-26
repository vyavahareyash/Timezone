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
        #expect(cells.first?.start == utc(start))
        #expect(cells.last?.end == utc(end))
        #expect(cells.allSatisfy { $0.duration == 3600 })
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
