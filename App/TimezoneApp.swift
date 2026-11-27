import SwiftUI
import TimezoneCore

@main
struct TimezoneApp: App {
    private let model = PanelModel(
        clock: { Date() }, systemTimeZone: { .autoupdatingCurrent }, cities: .bundled(),
        loadZones: { UserDefaults.standard.data(forKey: "zones") },
        saveZones: { UserDefaults.standard.set($0, forKey: "zones") })

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
    let opensAtNow: Bool
    @State private var isAdding: Bool
    @State private var query: String

    /// Snapshots of the open search pass `query`.
    init(model: PanelModel, opensAtNow: Bool = true, query: String? = nil) {
        self.model = model
        self.opensAtNow = opensAtNow
        _isAdding = State(initialValue: query != nil)
        _query = State(initialValue: query ?? "")
    }

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
                    Link("City data: GeoNames (CC BY 4.0)", destination: URL(string: "https://www.geonames.org")!)
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("More")
            }
            ForEach(Array(model.rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label)
                        Spacer()
                        if row.dayOffset != 0 {
                            Text(row.dayOffset, format: .number.sign(strategy: .always()))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text(row.abbreviation).font(.caption).foregroundStyle(.secondary)
                        // Text formats with the environment's time zone and locale (12/24-hour), not the style's own.
                        Text(row.time, format: Date.FormatStyle(date: .omitted, time: .shortened))
                            .environment(\.timeZone, row.timeZone)
                            .font(.title2.monospacedDigit())
                    }
                    HourStrip(timeline: model.timeline, cells: row.cells, now: model.now, cursor: model.cursor,
                              isFollowingNow: model.isFollowingNow, showsNowLabel: row.isHome,
                              onMove: model.moveCursor(to:), onNudge: model.nudgeCursor(steps:))
                }
                .padding(.horizontal, 6)
                .background(row.isHome ? Color.accentColor.opacity(0.1) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6))
            }
            if model.zones.isEmpty && !isAdding {
                Text("Add a zone with the + button").foregroundStyle(.secondary)
            }
            if isAdding {
                TextField("Search for a city", text: $query)
                ForEach(Array(model.search(query).enumerated()), id: \.offset) { _, city in
                    Button {
                        model.addZone(city)
                        isAdding = false
                        query = ""
                    } label: {
                        let country = Locale.current.localizedString(forRegionCode: city.countryCode) ?? city.countryCode
                        Text("\(city.name), \(country)")
                    }
                    .buttonStyle(.plain)
                }
            }
            Button { isAdding.toggle() } label: { Image(systemName: "plus") }
                .accessibilityLabel("Add zone")
        }
        .padding()
        .frame(width: 300)
        .onAppear { if opensAtNow { model.open() } }
        .task {
            while (try? await Task.sleep(for: .seconds(1))) != nil { model.tick() }
        }
    }
}

/// A Row's hour cells laid out against the Timeline, with Now as a red line through every strip and the Cursor through it.
struct HourStrip: View {
    let timeline: DateInterval
    let cells: [HourCell]
    let now: Date
    let cursor: Date
    let isFollowingNow: Bool
    /// Only the Home row labels Now, so the strips' labels don't repeat.
    let showsNowLabel: Bool
    let onMove: (Date) -> Void
    let onNudge: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let x = { (date: Date) in geometry.size.width * date.timeIntervalSince(timeline.start) / timeline.duration }
            ZStack(alignment: .topLeading) {
                ForEach(cells, id: \.interval.start) { cell in
                    hourCell(cell, cursorIsIn: cell.interval.start <= cursor && cursor < cell.interval.end)
                        .frame(width: max(x(cell.interval.end) - x(cell.interval.start) - 1, 0), height: 20)
                        .offset(x: x(cell.interval.start))
                }
                Rectangle()
                    .fill(.red)
                    .frame(width: 1, height: 20)
                    .offset(x: x(now))
                    .allowsHitTesting(false)
                if showsNowLabel {
                    Text("Now").font(.caption2).foregroundStyle(.red)
                        .offset(x: x(now) + 2, y: -22)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                Rectangle()
                    .fill(.tint)
                    .frame(width: 2, height: 20)
                    .offset(x: x(cursor) - 1)
                // The Cursor handle: dragging it is the strip's own drag below, which it sits inside.
                Circle()
                    .fill(isFollowingNow ? AnyShapeStyle(.red) : AnyShapeStyle(.tint)) // red: it sits on the Now line
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
        .padding(.top, showsNowLabel ? 26 : 8)
    }

    /// A whole hour is numbered every 3 local hours and under the Cursor; a stub at either end never is.
    private func hourCell(_ cell: HourCell, cursorIsIn: Bool) -> some View {
        let number = cell.isWhole && (cell.hour % 3 == 0 || cursorIsIn) ? "\(cell.hour)" : nil
        return ZStack {
            RoundedRectangle(cornerRadius: 2).fill(.quaternary)
            if cursorIsIn {
                RoundedRectangle(cornerRadius: 2).stroke(.tint, lineWidth: 1.5)
            }
            if let number {
                Text(number)
                    .font(.system(size: 8, weight: cursorIsIn ? .bold : .regular).monospacedDigit())
                    .fixedSize() // a cell is narrower than two digits: don't let them wrap
            }
        }
        // Decoration: elements overlapping the Cursor handle make the UI test's click on it miss.
        .accessibilityHidden(true)
    }
}
