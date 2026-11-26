import SwiftUI
import TimezoneCore

@main
struct TimezoneApp: App {
    private let model = PanelModel(clock: { Date() }, systemTimeZone: { .autoupdatingCurrent })

    var body: some Scene {
        MenuBarExtra("Timezone", systemImage: "globe") {
            PanelView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct PanelView: View {
    let model: PanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Menu {
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("More")
            }
            TimelineView(.everyMinute) { _ in
                let row = model.homeRow
                HStack {
                    Text(row.label)
                    Spacer()
                    // Text formats with the environment's time zone and locale (12/24-hour), not the style's own.
                    Text(row.time, format: Date.FormatStyle(date: .omitted, time: .shortened))
                        .environment(\.timeZone, row.timeZone)
                        .font(.title2.monospacedDigit())
                }
            }
        }
        .padding()
        .frame(width: 300)
    }
}
