import ServiceManagement
import SwiftUI
import TimezoneCore

@main
struct TimezoneApp: App {
    private let model = PanelModel(
        clock: { Date() }, systemTimeZone: { .autoupdatingCurrent }, cities: .bundled(),
        loadZones: { UserDefaults.standard.data(forKey: "zones") },
        saveZones: { UserDefaults.standard.set($0, forKey: "zones") },
        loadHomeLabels: { UserDefaults.standard.data(forKey: "homeLabels") },
        saveHomeLabels: { UserDefaults.standard.set($0, forKey: "homeLabels") })

    var body: some Scene {
        MenuBarExtra("Timezone", systemImage: "globe") {
            PanelView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The Row being renamed inline: the Home zone, or an added Zone by its index in `model.zones`.
enum RenameTarget: Equatable { case home, zone(Int) }

struct PanelView: View {
    let model: PanelModel
    /// Snapshots of a moved Cursor turn this off: `ImageRenderer` does run `onAppear`, which would reset it.
    let opensAtNow: Bool
    @State private var isAdding: Bool
    @State private var query: String

    /// Snapshots of the open search pass `query`, of an inline rename `renaming`, of a time being typed into the Row at
    /// position `editingTime`, and of a drag of the Zone at index `dragging` by `dragOffset` points.
    init(model: PanelModel, opensAtNow: Bool = true, query: String? = nil, renaming: RenameTarget? = nil,
         editingTime: Int? = nil, dragging: Int? = nil, dragOffset: CGFloat = 0) {
        self.model = model
        self.opensAtNow = opensAtNow
        _isAdding = State(initialValue: query != nil)
        _query = State(initialValue: query ?? "")
        _renaming = State(initialValue: renaming)
        let renameText = switch renaming {
            case .home: model.homeRow.label
            case .zone(let index): model.zones[index].label
            case nil: ""
        }
        _renameText = State(initialValue: renameText)
        _editingTime = State(initialValue: editingTime)
        _dragged = State(initialValue: dragging)
        _dragDistance = State(initialValue: dragOffset)
    }

    @State private var renaming: RenameTarget?
    @State private var renameText = ""
    @FocusState private var renameFocused: Bool
    /// The Row whose clock is being typed into, by its position in `model.rows`.
    @State private var editingTime: Int?
    @State private var timeText = ""
    @FocusState private var timeFocused: Bool
    private static let rowSpacing: CGFloat = 8
    /// Home and eight Zones; the list scrolls beyond that, within `maxRowsHeight` (nine rows, measured in zones-eight).
    private static let visibleRows = 9
    private static let maxRowsHeight: CGFloat = 501

    private func startRename(_ target: RenameTarget, label: String) {
        if let renaming { commitRename(renaming) } // another Row's open edit keeps its text
        renameText = label
        renaming = target
    }

    private func commitRename(_ target: RenameTarget) {
        renaming = nil
        switch target {
        case .home: model.renameHome(to: renameText)
        case .zone(let index): model.renameZone(at: index, to: renameText)
        }
    }

    /// The Zone being dragged, how far it has moved, and one row's height with its spacing (measured on layout).
    @State private var dragged: Int?
    @State private var dragDistance: CGFloat = 0
    @State private var rowStep: CGFloat = 1

    /// Drop the Zone where the drag ends, `rowStep` per row moved; the Home zone stays first.
    /// The drag is clamped to the list, so the row stops at the top and bottom instead of leaving the panel.
    private func reorder(_ index: Int) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                dragged = index
                let top = -CGFloat(index) * rowStep
                let bottom = CGFloat(model.zones.count - 1 - index) * rowStep
                dragDistance = min(max(value.translation.height, top), bottom)
            }
            .onEnded { _ in
                let moved = Int((dragDistance / rowStep).rounded())
                model.moveZone(from: index, to: index + moved)
                dragged = nil
                dragDistance = 0
            }
    }

    /// How far a Zone not being dragged sits from its place: one row toward the gap the dragged Zone would leave.
    private func shift(_ index: Int) -> CGFloat {
        guard let dragged, dragged != index else { return 0 }
        let drop = dragged + Int((dragDistance / rowStep).rounded())
        if drop > dragged && (dragged + 1...drop).contains(index) { return -rowStep }
        if drop < dragged && (drop..<dragged).contains(index) { return rowStep }
        return 0
    }

    /// The Row's clock; click it to type a time, which moves the Cursor there (Return applies, Esc or clicking away cancels).
    @ViewBuilder
    private func clock(_ row: ZoneRow, position: Int) -> some View {
        if editingTime == position {
            // The prompt shows the clock as it was, so the field opens empty, ready for a new time.
            TextField("Time", text: $timeText, prompt: Text(row.time, format: Date.FormatStyle(date: .omitted, time: .shortened)))
                .environment(\.timeZone, row.timeZone)
                .focused($timeFocused)
                .onAppear { timeFocused = true }
                .onSubmit {
                    model.moveCursor(toLocalTime: timeText, in: row.timeZone)
                    editingTime = nil
                }
                .onExitCommand { editingTime = nil }
                .onChange(of: timeFocused) { _, focused in
                    if !focused && editingTime == position { editingTime = nil }
                }
                .multilineTextAlignment(.trailing)
                .frame(width: 96)
        } else {
            // Text formats with the environment's time zone and locale (12/24-hour), not the style's own.
            Text(row.time, format: Date.FormatStyle(date: .omitted, time: .shortened))
                .environment(\.timeZone, row.timeZone)
                .onTapGesture {
                    timeText = ""
                    editingTime = position
                }
                .accessibilityAction(named: "Type a time") { timeText = ""; editingTime = position }
        }
    }

    @ViewBuilder
    private func zoneRow(_ row: ZoneRow, position: Int) -> some View {
        let target = row.zoneIndex.map(RenameTarget.zone) ?? .home
        let content = VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                if renaming == target {
                    TextField("Label", text: $renameText)
                        .focused($renameFocused)
                        .onAppear { renameFocused = true }
                        .onSubmit { commitRename(target) }
                        // Clicking away keeps the edit; only the field still open for this Row commits.
                        .onChange(of: renameFocused) { _, focused in
                            if !focused && renaming == target { commitRename(target) }
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
                clock(row, position: position).font(.title2.monospacedDigit())
            }
            HourStrip(model: model, row: row)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(row.isHome ? Color.accentColor.opacity(0.1) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .contextMenu {
            Button("Rename") { startRename(target, label: row.label) }
            if let zoneIndex = row.zoneIndex {
                Button("Remove") { renaming = nil; model.removeZone(at: zoneIndex) }
            }
        }

        if let zoneIndex = row.zoneIndex {
            content
                .offset(y: dragged == zoneIndex ? dragDistance : shift(zoneIndex))
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowStep = $0 + Self.rowSpacing }
                // A drag on the row reorders it; the strip's own drag (a child gesture) still moves the Cursor.
                .gesture(reorder(zoneIndex),
                         including: renaming == target || editingTime == position ? .none : .all)
        } else {
            content // Home stays first and can't be removed or moved
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if model.isFollowingNow {
                    Text("Following Now").foregroundStyle(.secondary)
                } else {
                    Button("Back to Now") { model.backToNow() }
                        .buttonStyle(.glass)
                }
                Spacer()
                Menu {
                    // Read live: the menu re-renders on each model tick, so it shows the registration as it is now.
                    Toggle("Launch at login", isOn: Binding(
                        get: { SMAppService.mainApp.status == .enabled },
                        set: { on in
                            // Awaiting the user's approval in System Settings: register() would do nothing, so open the pane.
                            if on && SMAppService.mainApp.status == .requiresApproval {
                                SMAppService.openSystemSettingsLoginItems()
                                return
                            }
                            do { try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
                            catch { NSLog("Launch at login: %@", error.localizedDescription) }
                        }))
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
                ForEach(Array(model.rows.enumerated()), id: \.offset) { position, row in
                    zoneRow(row, position: position)
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
                // The city list is GeoNames data (CC BY 4.0, ADR-0003): its credit belongs beside the results.
                Link("City data: GeoNames (CC BY 4.0)", destination: URL(string: "https://www.geonames.org")!)
                    .font(.caption)
            }
            Button { isAdding.toggle() } label: { Image(systemName: "plus") }
                .buttonStyle(.glass)
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

/// A Row's day against the Timeline, coloured like the sky at the Zone's local hour, with Now as a red line and the
/// Cursor as a line through it.
struct HourStrip: View {
    let model: PanelModel
    let row: ZoneRow
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let height: CGFloat = 14

    private var timeline: DateInterval { model.timeline }
    private func onNudge(_ steps: Int) { model.nudgeCursor(steps: steps) }

    var body: some View {
        GeometryReader { geometry in
            let fraction = { (date: Date) in date.timeIntervalSince(timeline.start) / timeline.duration }
            let x = { (date: Date) in geometry.size.width * fraction(date) }
            ZStack(alignment: .topLeading) {
                LinearGradient(stops: skyStops(fraction), startPoint: .leading, endPoint: .trailing)
                    .frame(height: Self.height)
                    .clipShape(Capsule())
                Capsule()
                    .fill(.red)
                    .frame(width: 2, height: Self.height)
                    // Now breathes, slowly fading and returning, so it reads as live; Reduce Motion holds it still.
                    .phaseAnimator(reduceMotion ? [1.0] : [1.0, 0.3]) { line, opacity in
                        line.opacity(opacity)
                    } animation: { _ in .easeInOut(duration: 1.2) }
                    .offset(x: x(model.now) - 1)
                // The Cursor handle, a bead sitting in the strip: white with a shadow and a dark centre line, readable on
                // any sky. Dragging it is the strip's own drag below, which it sits inside.
                Capsule()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.35), radius: 1.5)
                    .overlay(Capsule().fill(.black.opacity(0.55)).frame(width: 2.5, height: Self.height - 6))
                    .frame(width: 8, height: Self.height)
                    .padding(.horizontal, 3)
                    .contentShape(Rectangle())
                    .offset(x: x(model.cursor) - 7)
                    .focusable()
                    // The system ring stayed where the handle was last focused, not on it: hide it, keep the arrow keys.
                    .focusEffectDisabled()
                    .onKeyPress(.leftArrow) { onNudge(-1); return .handled }
                    .onKeyPress(.rightArrow) { onNudge(1); return .handled }
                    .accessibilityElement()
                    .accessibilityLabel("Cursor handle")
                    .accessibilityAdjustableAction { direction in onNudge(direction == .increment ? 1 : -1) }
            }
            // The children are fixed-size, so without this the ZStack shrinks to the handle and only it takes presses.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .pointerStyle(.columnResize) // left-right arrows: the strip drags the Cursor sideways
            // Pressing anywhere jumps the Cursor there; holding and dragging scrubs.
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                model.moveCursor(to: timeline.start + value.location.x / geometry.size.width * timeline.duration)
            })
        }
        .frame(height: Self.height)
    }

    /// The sky by local hour, from the mock-up: night, dawn, sunrise, day, sunset, dusk, night.
    /// shortcut: the same dawn and dusk hours for every Zone; use real sunrise once Cities carry coordinates.
    private static let skyLight: [(hour: Double, hex: UInt32)] = [
        (0, 0x28305A), (5, 0x28305A), (6.3, 0xB98AA6), (7.4, 0xF3C08B), (9.5, 0xA8D2F2),
        (16.5, 0xA8D2F2), (18.2, 0xF2B072), (19.4, 0x7A5D92), (21, 0x28305A), (24, 0x28305A)]
    private static let skyDark: [(hour: Double, hex: UInt32)] = [
        (0, 0x141936), (5, 0x141936), (6.3, 0x6D4D6E), (7.4, 0xB5845A), (9.5, 0x4C7FAE),
        (16.5, 0x4C7FAE), (18.2, 0xB07040), (19.4, 0x4A3863), (21, 0x141936), (24, 0x141936)]

    /// The sky at a local `hour` (0–24), interpolated between the keyframes.
    private func sky(_ hour: Double) -> Color {
        let keys = colorScheme == .dark ? Self.skyDark : Self.skyLight
        let upper = keys.firstIndex { $0.hour >= hour } ?? keys.count - 1
        let (a, b) = (keys[max(upper - 1, 0)], keys[upper])
        let t = b.hour > a.hour ? (hour - a.hour) / (b.hour - a.hour) : 0
        let channel = { (shift: UInt32) in
            let from = Double(a.hex >> shift & 0xFF), to = Double(b.hex >> shift & 0xFF)
            return (from + (to - from) * t) / 255
        }
        return Color(red: channel(16), green: channel(8), blue: channel(0))
    }

    /// A stop at each hour cell's start, coloured by its local time, and one at the Timeline's end.
    private func skyStops(_ fraction: (Date) -> Double) -> [Gradient.Stop] {
        let stops = row.cells.enumerated().map { index, cell in
            // A leading stub starts mid-hour (Pune at Berlin's midnight is 03:30): colour it at its true local time.
            let hour = Double(cell.hour) + (index == 0 && !cell.isWhole ? 1 - cell.interval.duration / 3600 : 0)
            return Gradient.Stop(color: sky(hour), location: fraction(cell.interval.start))
        }
        guard let last = row.cells.last else { return stops }
        return stops + [Gradient.Stop(color: sky(Double(last.hour) + last.interval.duration / 3600), location: 1)]
    }
}
