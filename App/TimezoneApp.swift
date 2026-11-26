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
    /// Snapshots of a moved Cursor turn this off: `ImageRenderer` does run `onAppear`, which would reset it.
    var opensAtNow = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if model.isFollowingNow {
                    Text("Following Now").foregroundStyle(.secondary)
                } else {
                    Button("Back to Now") { model.backToNow() }
                }
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
            let row = model.homeRow
            HStack {
                Text(row.label)
                Spacer()
                // Text formats with the environment's time zone and locale (12/24-hour), not the style's own.
                Text(row.time, format: Date.FormatStyle(date: .omitted, time: .shortened))
                    .environment(\.timeZone, row.timeZone)
                    .font(.title2.monospacedDigit())
            }
            HourStrip(timeline: model.timeline, cells: row.cells, now: model.now, cursor: model.cursor,
                      onMove: model.moveCursor(to:), onNudge: model.nudgeCursor(steps:))
        }
        .padding()
        .frame(width: 300)
        .onAppear { if opensAtNow { model.open() } }
        .task {
            while (try? await Task.sleep(for: .seconds(1))) != nil { model.tick() }
        }
    }
}

/// A Row's hour cells laid out against the Timeline, with Now marked below and the Cursor through it.
struct HourStrip: View {
    let timeline: DateInterval
    let cells: [DateInterval]
    let now: Date
    let cursor: Date
    let onMove: (Date) -> Void
    let onNudge: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let x = { (date: Date) in geometry.size.width * date.timeIntervalSince(timeline.start) / timeline.duration }
            ZStack(alignment: .topLeading) {
                ForEach(cells, id: \.start) { cell in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                        .frame(width: max(x(cell.end) - x(cell.start) - 1, 0), height: 20)
                        .offset(x: x(cell.start))
                }
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                    .offset(x: x(now) - 3, y: 22)
                Rectangle()
                    .fill(.tint)
                    .frame(width: 2, height: 20)
                    .offset(x: x(cursor) - 1)
                // The Cursor handle: dragging it is the strip's own drag below, which it sits inside.
                Circle()
                    .fill(.tint)
                    .frame(width: 10, height: 10)
                    .padding(3)
                    .contentShape(Rectangle())
                    .offset(x: x(cursor) - 8, y: -9)
                    .focusable()
                    .onKeyPress(.leftArrow) { onNudge(-1); return .handled }
                    .onKeyPress(.rightArrow) { onNudge(1); return .handled }
                    .accessibilityElement()
                    .accessibilityLabel("Cursor handle")
                    .accessibilityAdjustableAction { direction in onNudge(direction == .increment ? 1 : -1) }
            }
            .contentShape(Rectangle())
            // Pressing anywhere jumps the Cursor there; holding and dragging scrubs.
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                onMove(timeline.start + value.location.x / geometry.size.width * timeline.duration)
            })
        }
        .frame(height: 28)
        .padding(.top, 8)
    }
}
