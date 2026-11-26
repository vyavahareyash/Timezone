import Foundation
import Testing
import TimezoneCore

struct PanelModelTests {
    @Test func homeZoneRowShowsSystemCityAndTheClockTime() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let model = PanelModel(clock: { now }, systemTimeZone: { TimeZone(identifier: "America/Los_Angeles")! })

        let home = model.homeRow
        #expect(home.label == "Los Angeles")
        #expect(home.timeZone.identifier == "America/Los_Angeles")
        #expect(home.time == now)
    }
}
