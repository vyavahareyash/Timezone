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

    /// Snapshots of the open search pass `query`, and of an inline rename of the Zone at index `renaming`.
    init(model: PanelModel, opensAtNow: Bool = true, query: String? = nil, renaming: Int? = nil) {
        self.model = model
        self.opensAtNow = opensAtNow
        _isAdding = State(initialValue: query != nil)
        _query = State(initialValue: query ?? "")
        _renaming = State(initialValue: renaming)
        _renameText = State(initialValue: renaming.map { model.zones[$0].label } ?? "")
    }

    /// The added Zone being renamed inline, by its index in `model.zones`.
    @State private var renaming: Int?
    @State private var renameText = ""
    @FocusState private var renameFocused: Bool
    private static let rowSpacing: CGFloat = 8
    /// Home and eight Zones; the list scrolls beyond that, within `maxRowsHeight` (nine rows, measured in zones-eight).
    private static let visibleRows = 9
    private static let maxRowsHeight: CGFloat = 568

    private func commitRename(_ index: Int) {
        renaming = nil
        model.renameZone(at: index, to: renameText)
    }

    /// The Zone being dragged, how far it has moved, and one row's height with its spacing (measured on layout).
    @State private var dragged: Int?
    @State private var dragDistance: CGFloat = 0
    @State private var rowStep: CGFloat = 1

    /// Drop the Zone where the drag ends, `rowStep` per row moved; the Home zone stays first.
    private func reorder(_ index: Int) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                dragged = index
                dragDistance = value.translation.height
            }
            .onEnded { value in
                let moved = Int((value.translation.height / rowStep).rounded())
                model.moveZone(from: index, to: index + moved) // the model clamps to the list
                dragged = nil
                dragDistance = 0
            }
    }

    @ViewBuilder
    private func zoneRow(_ row: ZoneRow, zoneIndex: Int?) -> some View {
        let content = VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                if let zoneIndex, renaming == zoneIndex {
                    TextField("Label", text: $renameText)
                        .focused($renameFocused)
                        .onAppear { renameFocused = true }
                        .onSubmit { commitRename(zoneIndex) }
                        // Clicking away keeps the edit; only the field still open for this Zone commits.
                        .onChange(of: renameFocused) { _, focused in
                            if !focused && renaming == zoneIndex { commitRename(zoneIndex) }
                        }
                } else {
                    Text(row.label)
                }
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
            HourStrip(model: model, row: row)
        }
        .padding(.horizontal, 6)
        .background(row.isHome ? Color.accentColor.opacity(0.1) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6))

        if let zoneIndex {
            content
                .contextMenu {
                    Button("Rename") {
                        if let renaming { commitRename(renaming) } // another Zone's open edit keeps its text
                        renameText = row.label
                        renaming = zoneIndex
                    }
                    Button("Remove") { renaming = nil; model.removeZone(at: zoneIndex) }
                }
                .offset(y: dragged == zoneIndex ? dragDistance : 0)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowStep = $0 + Self.rowSpacing }
                // A drag on the row reorders it; the strip's own drag (a child gesture) still moves the Cursor.
                .gesture(reorder(zoneIndex), including: renaming == zoneIndex ? .none : .all)
        } else {
            content // Home stays first and can't be renamed, removed or moved
        }
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
            let rowList = VStack(alignment: .leading, spacing: Self.rowSpacing) {
                ForEach(Array(model.rows.enumerated()), id: \.offset) { _, row in
                    zoneRow(row, zoneIndex: row.zoneIndex)
                }
            }
            // Scroll only past Home and eight Zones: ImageRenderer draws nothing inside a ScrollView.
            if model.rows.count > Self.visibleRows {
                ScrollView { rowList }.frame(maxHeight: Self.maxRowsHeight)
            } else {
                rowList
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
    let model: PanelModel
    let row: ZoneRow
    @Environment(\.colorScheme) private var colorScheme

    private static let cellHeight: CGFloat = 26 // the mock-up's cell height

    private var timeline: DateInterval { model.timeline }
    private var cursor: Date { model.cursor }
    private var now: Date { model.now }
    private var isFollowingNow: Bool { model.isFollowingNow }
    private func onNudge(_ steps: Int) { model.nudgeCursor(steps: steps) }

    var body: some View {
        GeometryReader { geometry in
            let x = { (date: Date) in geometry.size.width * date.timeIntervalSince(timeline.start) / timeline.duration }
            ZStack(alignment: .topLeading) {
                ForEach(row.cells, id: \.interval.start) { cell in
                    hourCell(cell)
                        .frame(width: max(x(cell.interval.end) - x(cell.interval.start) - 1, 0), height: Self.cellHeight)
                        .offset(x: x(cell.interval.start))
                }
                Rectangle()
                    .fill(.red)
                    .frame(width: 1, height: Self.cellHeight)
                    .offset(x: x(now))
                    .allowsHitTesting(false)
                Rectangle()
                    .fill(.tint)
                    .frame(width: 2, height: Self.cellHeight)
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
                model.moveCursor(to: timeline.start + value.location.x / geometry.size.width * timeline.duration)
            })
        }
        .frame(height: 28)
        .padding(.top, 8) // room for the Cursor handle
    }

    /// The mock-up's band colours, cell fill and hour number, for each appearance.
    private func bandColors(_ band: HourCell.Band) -> (fill: Color, text: Color) {
        let dark = colorScheme == .dark
        switch band {
        case .working: return dark ? (Color(hex: 0xD3AE55), Color(hex: 0x241B04)) : (Color(hex: 0xF8DB96), Color(hex: 0x4A3A10))
        case .evening: return dark ? (Color(hex: 0x4E5566), Color(hex: 0xE2E5EC)) : (Color(hex: 0xD3D8E1), Color(hex: 0x2B3140))
        case .night: return dark ? (Color(hex: 0x33384A), Color(hex: 0xB4BAC8)) : (Color(hex: 0xA9B0BF), Color(hex: 0x1F2430))
        }
    }

    private func hourCell(_ cell: HourCell) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2).fill(bandColors(cell.band).fill)
            if cell.containsCursor {
                RoundedRectangle(cornerRadius: 2).stroke(.tint, lineWidth: 1.5)
            }
            if cell.showsHour {
                Text("\(cell.hour)")
                    .font(.system(size: 10, weight: cell.containsCursor ? .heavy : .medium).monospacedDigit())
                    .foregroundStyle(bandColors(cell.band).text)
                    .fixedSize() // a cell is narrower than two digits: don't let them wrap
            }
        }
        // Decoration: elements overlapping the Cursor handle make the UI test's click on it miss.
        .accessibilityHidden(true)
    }
}

private extension Color {
    /// A colour from a 0xRRGGBB value, as written in the mock-up.
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
