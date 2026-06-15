import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, peek, header, notch, media, shortcuts, wallpaper, debug, about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return "General"
        case .peek: return "Peek slots"
        case .header: return "Expanded header"
        case .notch: return "Notch shape"
        case .media: return "Media"
        case .shortcuts: return "Shortcuts"
        case .wallpaper: return "Wallpaper Mask"
        case .debug: return "Debug"
        case .about: return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .peek: return "rectangle.lefthalf.inset.filled"
        case .header: return "rectangle.topthird.inset.filled"
        case .notch: return "rectangle.compress.vertical"
        case .media: return "play.rectangle"
        case .shortcuts: return "command"
        case .wallpaper: return "rectangle.dashed"
        case .debug: return "ladybug"
        case .about: return "info.circle"
        }
    }
}

enum SettingsSelection: Hashable {
    case pane(SettingsPane)
    case tab(UUID)
}

final class SettingsController: ObservableObject {
    @Published var selection: SettingsSelection = .pane(.general)
}

struct SettingsRoot: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var overlay: OverlayManager
    @ObservedObject var controller: SettingsController
    let notch: NotchController
    @State private var tabsExpanded = true

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 720, minHeight: 560)

        .onAppear { applyPinning(for: controller.selection) }
        .onChange(of: controller.selection) { _, new in
            applyPinning(for: new)
        }
    }

    private func applyPinning(for selection: SettingsSelection) {
        switch selection {
        case .tab(let id):
            notch.currentTabID = id
            notch.forceExpandForSettings()
        case .pane(.header):
            notch.forceExpandForSettings()
        case .pane:
            notch.pinnedFromSettings = false
            notch.setExpanded(false, animated: true)
        }
    }

    private var sidebar: some View {
        List(selection: $controller.selection) {
            row(.general)
            row(.peek)
            row(.header)
            tabsDisclosure
            row(.notch)
            row(.media)
            row(.shortcuts)
            row(.wallpaper)
            row(.debug)
            row(.about)
        }
    }

    private func row(_ pane: SettingsPane) -> some View {
        Label(pane.label, systemImage: pane.systemImage)
            .tag(SettingsSelection.pane(pane))
    }

    private var tabsDisclosure: some View {
        DisclosureGroup(isExpanded: $tabsExpanded) {
            ForEach(settings.layout.tabs) { tab in
                Label(tab.name, systemImage: tab.icon)
                    .tag(SettingsSelection.tab(tab.id))
            }
        } label: {
            HStack(spacing: 6) {
                Label("Tabs", systemImage: "rectangle.3.group")
                Spacer()
                Button {
                    let new = TabConfig(name: "New tab", icon: "square.grid.2x2")
                    settings.layout.tabs.append(new)
                    tabsExpanded = true
                    controller.selection = .tab(new.id)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Add tab")
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch controller.selection {
        case .pane(let p):
            PaneContainer(title: p.label) {
                paneContent(p)
            }
        case .tab(let id):
            let tabName = settings.layout.tabs.first(where: { $0.id == id })?.name ?? "Tab"
            PaneContainer(title: tabName) {
                TabEditor(tabID: id, settings: settings, notch: notch, onDeleted: {
                    controller.selection = .pane(.general)
                })
            }
        }
    }

    @ViewBuilder
    private func paneContent(_ p: SettingsPane) -> some View {
        switch p {
        case .general:       GeneralPane(settings: settings)
        case .peek:          PeekPane(settings: settings)
        case .header:        HeaderPane(settings: settings, notch: notch)
        case .notch:         NotchPane(settings: settings)
        case .media:         MediaPane(settings: settings)
        case .shortcuts:     ShortcutsPane(settings: settings)
        case .wallpaper:     WallpaperPane(settings: settings, manager: overlay)
        case .debug:         DebugPane(settings: settings, notch: notch)
        case .about:         AboutPane()
        }
    }
}

private struct PaneContainer<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SettingsForm<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                content()
            }
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            )
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SwitchRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct PickerRow<T: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: T
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: $selection) { content() }
                .labelsHidden()
                .frame(maxWidth: 200)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var step: Double = 1
    var suffix: String = ""

    var body: some View {
        HStack {
            Text(title)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 8)
            Slider(value: $value, in: range)
                .frame(maxWidth: 200)
            Text(label)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var label: String {
        if step < 1 {
            return String(format: "%.1f%@", value, suffix)
        }
        return "\(Int(value))\(suffix)"
    }
}

struct MillisRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Slider(value: $value, in: range).frame(width: 200)
            Text("\(Int(value * 1000))ms")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct FractionRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Slider(value: $value, in: range).frame(width: 200)
            Text("\(Int(value * 100))%")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct GeneralPane: View {
    @ObservedObject var settings: AppSettings
    @State private var confirmResetLayout = false

    var body: some View {
        SettingsForm {
            SettingsSection(title: "Startup") {
                SwitchRow(title: "Launch at login", isOn: Binding(
                    get: { settings.startAtLogin },
                    set: { newValue in
                        settings.startAtLogin = newValue
                        Self.setLoginItem(enabled: newValue)
                    }
                ))
            }
            SettingsSection(title: "Notch overlay") {
                SwitchRow(
                    title: "Enable notch overlay",
                    subtitle: "Shows widgets, media controls, and the tray under the notch.",
                    isOn: $settings.notchEnabled
                )
                Divider().padding(.horizontal, 12)
                SwitchRow(
                    title: "Open on hover",
                    subtitle: "Expand the notch when the cursor enters it.",
                    isOn: $settings.notchHoverToOpen
                )
                Divider().padding(.horizontal, 12)
                SwitchRow(
                    title: "Two-finger swipe cycles tabs",
                    subtitle: "Trackpad scroll across the expanded notch advances tabs left/right.",
                    isOn: $settings.swipeGesturesEnabled
                )
                if settings.swipeGesturesEnabled {
                    Divider().padding(.horizontal, 12)
                    SliderRow(
                        title: "Swipe distance per tab",
                        value: $settings.swipeDistancePerTab,
                        range: 30...260,
                        suffix: "pt"
                    )
                }
            }

            SettingsSection(
                title: "Reset",
                footer: "Wipes every tab, widget arrangement, header/peek slot back to the factory layout. Other settings (notch shape, animations, hotkeys) are untouched."
            ) {
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        confirmResetLayout = true
                    } label: {
                        Label("Reset all layout to default", systemImage: "arrow.counterclockwise")
                    }
                    .foregroundStyle(.red)
                    .tint(.red)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
            }
        }
        .confirmationDialog(
            "Reset entire layout?",
            isPresented: $confirmResetLayout,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                settings.layout = .default
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All tabs and widget arrangements will revert to defaults. Other settings stay as they are. This can't be undone.")
        }
    }

    private static func setLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {}
        }
    }
}

struct PeekPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsForm {
            SettingsSection(
                title: "Left side",
                footer: "Widgets always visible to the LEFT of the physical notch when peeking. Stack as many as you want."
            ) {
                PeekSlotList(slots: $settings.layout.peekLeftSlots, settings: settings, commitSlots: { newSlots in
                    settings.layout.peekLeftSlots = newSlots
                })
            }
            SettingsSection(
                title: "Right side",
                footer: "Widgets always visible to the RIGHT of the physical notch when peeking."
            ) {
                PeekSlotList(slots: $settings.layout.peekRightSlots, settings: settings, commitSlots: { newSlots in
                    settings.layout.peekRightSlots = newSlots
                })
            }
        }
    }
}

private struct PeekSlotList: View {
    @Binding var slots: [HeaderSlot]
    @ObservedObject var settings: AppSettings

    let commitSlots: ([HeaderSlot]) -> Void
    @State private var editingSlotID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if slots.isEmpty {
                Text("No widgets — this side of the peek will be empty.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 4)
            } else {
                ForEach(Array(slots.enumerated()), id: \.element.id) { idx, slot in
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Image(systemName: slot.kind.systemImage)
                            .foregroundStyle(.secondary).frame(width: 18)
                        Text(slot.kind.label)
                        if slot.customWidth != nil || slot.customHeight != nil {
                            Text(sizeLabel(slot))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { editingSlotID = slot.id } label: {
                            Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        Button {
                            if idx > 0 { var a = slots; a.swapAt(idx, idx - 1); commitSlots(a) }
                        } label: { Image(systemName: "chevron.up").foregroundStyle(.secondary) }
                        .buttonStyle(.plain).disabled(idx == 0)
                        Button {
                            if idx < slots.count - 1 { var a = slots; a.swapAt(idx, idx + 1); commitSlots(a) }
                        } label: { Image(systemName: "chevron.down").foregroundStyle(.secondary) }
                        .buttonStyle(.plain).disabled(idx == slots.count - 1)
                        Button {
                            var a = slots; a.remove(at: idx); commitSlots(a)
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    if idx < slots.count - 1 { Divider().padding(.horizontal, 12) }
                }
            }
            Divider().padding(.horizontal, 12)
            Menu {
                ForEach(WidgetKind.allCases.filter { $0.fitsInPeek }) { kind in
                    Button {
                        var a = slots; a.append(HeaderSlot(kind: kind)); commitSlots(a)
                    } label: { Label(kind.label, systemImage: kind.systemImage) }
                }
            } label: {
                HStack(spacing: 10) {
                    Color.clear.frame(width: 18, height: 1)
                    Image(systemName: "plus.circle.fill").frame(width: 18)
                    Text("Add widget")
                    Spacer()
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
        }
        .sheet(item: Binding(
            get: { editingSlotID.flatMap { id in slots.first(where: { $0.id == id }) } },
            set: { _ in editingSlotID = nil }
        )) { editing in
            HeaderSlotEditor(
                initial: editing,
                onCommit: { updated in
                    var newArr = slots
                    if let idx = newArr.firstIndex(where: { $0.id == updated.id }) {
                        newArr[idx] = updated
                        commitSlots(newArr)
                    }
                },
                onDismiss: { editingSlotID = nil }
            )
        }
    }

    private func sizeLabel(_ slot: HeaderSlot) -> String {
        let w = slot.customWidth.map { "\(Int($0))\(slot.widthUnit.label)" } ?? "auto"
        let h = slot.customHeight.map { "\(Int($0))\(slot.heightUnit.label)" } ?? "auto"
        return "\(w) × \(h)"
    }
}

struct HeaderPane: View {
    @ObservedObject var settings: AppSettings
    let notch: NotchController

    var body: some View {
        SettingsForm {
            SettingsSection(
                title: "Left band",
                footer: "Widgets that appear between the leading edge and the physical notch when the panel is expanded."
            ) {
                HeaderSlotList(slots: $settings.layout.expandedHeaderLeft, settings: settings, commitSlots: { newSlots in
                    settings.layout.expandedHeaderLeft = newSlots
                })
            }
            SettingsSection(
                title: "Right band",
                footer: "Widgets that appear between the physical notch and the trailing edge. The settings gear and tab switcher live here by default — remove either if you want a cleaner header."
            ) {
                HeaderSlotList(slots: $settings.layout.expandedHeaderRight, settings: settings, commitSlots: { newSlots in
                    settings.layout.expandedHeaderRight = newSlots
                })
            }
        }
    }
}

struct TabEditor: View {
    let tabID: UUID
    @ObservedObject var settings: AppSettings
    let notch: NotchController
    let onDeleted: () -> Void
    @State private var confirmDeleteTab = false

    var body: some View {
        ScrollView {
            if let idx = settings.layout.tabs.firstIndex(where: { $0.id == tabID }) {
                SettingsForm {
                    SettingsSection(title: "Tab") {
                        TabHeaderEditor(tab: Binding(
                            get: { settings.layout.tabs[idx] },
                            set: { settings.layout.tabs[idx] = $0 }
                        ))
                    }

                    SettingsSection(
                        title: "Canvas",
                        footer: "Each stack is a row group. Tap + to add a widget or a nested stack. Drag the grab handle to reorder. Tap the slider icon on any widget for its options."
                    ) {
                        CanvasView(root: Binding(
                            get: { settings.layout.tabs[idx].root },
                            set: { settings.layout.tabs[idx].root = $0 }
                        ), settings: settings, calendar: notch.calendar)
                    }

                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            confirmDeleteTab = true
                        } label: {
                            Label("Delete tab", systemImage: "trash")
                        }
                        .foregroundStyle(.red)
                        .tint(.red)
                    }
                    .padding(.horizontal, 4)
                }
                .confirmationDialog(
                    "Delete this tab?",
                    isPresented: $confirmDeleteTab,
                    titleVisibility: .visible
                ) {
                    Button("Delete tab", role: .destructive) {
                        settings.layout.tabs.removeAll { $0.id == tabID }
                        onDeleted()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("\"\(settings.layout.tabs[idx].name)\" and every widget it contains will be removed. This can't be undone.")
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Tab removed").font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            }
        }
    }
}

private struct CalendarProperties: View {
    @ObservedObject var calendar: CalendarController

    var body: some View {
        SettingsSection(
            title: "Calendar access",
            footer: "StupidNotch only asks for calendar access when you tap below — it never prompts on launch."
        ) {
            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle).font(.system(size: 13, weight: .semibold))
                    Text(statusSubtitle).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                actionButton
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
    }

    private var statusIcon: String {
        switch calendar.authState {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.octagon.fill"
        case .notDetermined: return "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch calendar.authState {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        }
    }

    private var statusTitle: String {
        switch calendar.authState {
        case .granted: return "Access granted"
        case .denied: return "Access denied"
        case .notDetermined: return "Access not granted yet"
        }
    }

    private var statusSubtitle: String {
        switch calendar.authState {
        case .granted: return "Real events show in calendar widgets."
        case .denied: return "Re-enable StupidNotch in System Settings → Privacy → Calendars."
        case .notDetermined: return "Tap to allow this app to read your events."
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch calendar.authState {
        case .granted:
            EmptyView()
        case .notDetermined:
            Button("Allow access") { calendar.requestAccessFromUser() }
                .buttonStyle(.borderedProminent)
        case .denied:
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct MediaPlayerInstanceProperties: View {
    @Binding var widget: WidgetInstance

    var body: some View {
        SettingsSection(
            title: "Media player content",
            footer: "Toggle each sub-element of the card. Hide everything but artwork+title to mimic the old compact widget."
        ) {
            optionSwitch(title: "Artwork", key: "showArtwork", default: 1)
            optionSlider(title: "Artwork size", key: "artworkSize", default: 72,
                         range: 32...140, suffix: "pt")
            optionSwitch(title: "Title", key: "showTitle", default: 1)
            optionSwitch(title: "Artist", key: "showArtist", default: 1)
            optionSwitch(title: "Progress bar", key: "showProgress", default: 1)
            optionSwitch(title: "Elapsed / remaining time", key: "showTimes", default: 1)
            optionSwitch(title: "Playback controls", key: "showControls", default: 1)
            optionSwitch(title: "Inline visualizer", key: "showVisualizer", default: 0)
        }
    }

    @ViewBuilder
    private func optionSwitch(title: String, key: String, default def: Double) -> some View {
        SwitchRow(title: title, isOn: Binding(
            get: { (widget.options[key] ?? def) > 0.5 },
            set: { on in var w = widget; w.options[key] = on ? 1 : 0; widget = w }
        ))
    }

    @ViewBuilder
    private func optionSlider(title: String, key: String, default def: Double,
                              range: ClosedRange<Double>, suffix: String) -> some View {
        SliderRow(
            title: title,
            value: Binding(
                get: { widget.options[key] ?? def },
                set: { v in var w = widget; w.options[key] = v; widget = w }
            ),
            range: range,
            suffix: suffix
        )
    }
}

private struct CalendarInstanceProperties: View {
    @Binding var widget: WidgetInstance
    var body: some View {
        SettingsSection(title: "Calendar layout",
                        footer: "Compact hides the horizontal date strip and only shows today's card + events.") {
            SwitchRow(title: "Compact mode", isOn: Binding(
                get: { (widget.options["compact"] ?? 0) > 0.5 },
                set: { on in var w = widget; w.options["compact"] = on ? 1 : 0; widget = w }
            ))
            SwitchRow(title: "Show date strip", isOn: Binding(
                get: { (widget.options["showWeek"] ?? 1) > 0.5 },
                set: { on in var w = widget; w.options["showWeek"] = on ? 1 : 0; widget = w }
            ))
            SwitchRow(title: "Show events", isOn: Binding(
                get: { (widget.options["showEvents"] ?? 1) > 0.5 },
                set: { on in var w = widget; w.options["showEvents"] = on ? 1 : 0; widget = w }
            ))
            SliderRow(title: "Event limit",
                value: Binding(
                    get: { widget.options["eventLimit"] ?? 4 },
                    set: { v in var w = widget; w.options["eventLimit"] = v.rounded(); widget = w }
                ),
                range: 1...10,
                suffix: ""
            )
            SliderRow(title: "Font scale",
                value: Binding(
                    get: { widget.options["fontScale"] ?? 1 },
                    set: { v in var w = widget; w.options["fontScale"] = v; widget = w }
                ),
                range: 0.7...1.6,
                step: 0.1,
                suffix: "x"
            )
        }
    }
}

private struct GreetingInstanceProperties: View {
    @Binding var widget: WidgetInstance
    var body: some View {
        SettingsSection(title: "Greeting", footer: "Time-of-day phrase + your username.") {
            SliderRow(title: "Font size",
                value: Binding(
                    get: { widget.options["fontSize"] ?? 13 },
                    set: { v in var w = widget; w.options["fontSize"] = v; widget = w }
                ),
                range: 9...28,
                suffix: "pt"
            )
        }
    }
}

private struct SystemPulseInstanceProperties: View {
    @Binding var widget: WidgetInstance
    enum PulseStyle: Int, CaseIterable, Identifiable {
        case bars = 0, donut = 1, gauge = 2
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .bars: return "Bars"
            case .donut: return "Donut"
            case .gauge: return "Half gauge"
            }
        }
    }
    var body: some View {
        let style = PulseStyle(rawValue: Int(widget.options["style"] ?? 0)) ?? .bars
        SettingsSection(title: "System pulse",
                        footer: "Live CPU + RAM usage. Style changes the shape — bars, donut, or a fuel-style half gauge.") {
            PickerRow(title: "Style", selection: Binding(
                get: { style },
                set: { v in var w = widget; w.options["style"] = Double(v.rawValue); widget = w }
            )) {
                ForEach(PulseStyle.allCases) { Text($0.label).tag($0) }
            }
            Divider().padding(.horizontal, 12)
            SliderRow(title: "Label / value font",
                value: Binding(
                    get: { widget.options["fontSize"] ?? 9 },
                    set: { v in var w = widget; w.options["fontSize"] = v; widget = w }
                ),
                range: 8...18,
                suffix: "pt"
            )
            switch style {
            case .bars:
                SliderRow(title: "Bar thickness",
                    value: Binding(
                        get: { widget.options["barHeight"] ?? 4 },
                        set: { v in var w = widget; w.options["barHeight"] = v; widget = w }
                    ),
                    range: 2...14,
                    suffix: "pt"
                )
            case .donut:
                SliderRow(title: "Ring size",
                    value: Binding(
                        get: { widget.options["ringSize"] ?? 36 },
                        set: { v in var w = widget; w.options["ringSize"] = v; widget = w }
                    ),
                    range: 22...96,
                    suffix: "pt"
                )
            case .gauge:
                SliderRow(title: "Gauge size",
                    value: Binding(
                        get: { widget.options["gaugeSize"] ?? 56 },
                        set: { v in var w = widget; w.options["gaugeSize"] = v; widget = w }
                    ),
                    range: 34...140,
                    suffix: "pt"
                )
            }
        }
    }
}

private struct NextEventInstanceProperties: View {
    @Binding var widget: WidgetInstance
    var body: some View {
        SettingsSection(title: "Next event",
                        footer: "Shows the next upcoming entry from today's calendar.") {
            SliderRow(title: "Font size",
                value: Binding(
                    get: { widget.options["fontSize"] ?? 11 },
                    set: { v in var w = widget; w.options["fontSize"] = v; widget = w }
                ),
                range: 9...22,
                suffix: "pt"
            )
        }
    }
}

private struct MediaPlayerProperties: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsSection(
            title: "Media player",
            footer: "The full-card media widget has an inline visualizer to the right of the controls. Hide it if you want a plain card."
        ) {
            SwitchRow(
                title: "Show visualizer",
                subtitle: "Animated bars next to the playback controls.",
                isOn: $settings.mediaPlayerShowVisualizer
            )
        }
    }
}

private struct VisualizerProperties: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsSection(
            title: "Bars",
            footer: "Bars always render vertically. Alignment chooses whether they grow symmetrically from the centre or anchor to the bottom edge."
        ) {
            PickerRow(title: "Alignment", selection: Binding(
                get: { VisualizerAlignment(rawValue: settings.visualizerAlignment) ?? .centered },
                set: { settings.visualizerAlignment = $0.rawValue }
            )) {
                ForEach(VisualizerAlignment.allCases) { Text($0.label).tag($0) }
            }
            Divider().padding(.horizontal, 12)
            SliderRow(
                title: "Bar count",
                value: Binding(
                    get: { Double(settings.visualizerBarCount) },
                    set: { settings.visualizerBarCount = Int($0) }
                ),
                range: 2...10, step: 1
            )
            Divider().padding(.horizontal, 12)
            SliderRow(
                title: "Bar width",
                value: $settings.visualizerBarWidth,
                range: 1.5...12, step: 0.5, suffix: "pt"
            )
            Divider().padding(.horizontal, 12)
            SliderRow(
                title: "Spacing",
                value: $settings.visualizerBarSpacing,
                range: 0...10, step: 0.5, suffix: "pt"
            )
        }
    }
}

private struct HeaderSlotList: View {
    @Binding var slots: [HeaderSlot]
    @ObservedObject var settings: AppSettings
    let commitSlots: ([HeaderSlot]) -> Void
    @State private var editingSlotID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if slots.isEmpty {
                Text("No widgets — this side of the header will be empty.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 4)
            } else {
                ForEach(Array(slots.enumerated()), id: \.element.id) { idx, slot in
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Image(systemName: slot.kind.systemImage)
                            .foregroundStyle(.secondary).frame(width: 18)
                        Text(slot.kind.label)
                        if slot.customWidth != nil || slot.customHeight != nil {
                            Text(headerSlotSizeLabel(slot))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            editingSlotID = slot.id
                        } label: { Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary) }
                        .buttonStyle(.plain)
                        Button {
                            if idx > 0 { var a = slots; a.swapAt(idx, idx - 1); commitSlots(a) }
                        } label: { Image(systemName: "chevron.up").foregroundStyle(.secondary) }
                        .buttonStyle(.plain)
                        .disabled(idx == 0)
                        Button {
                            if idx < slots.count - 1 { var a = slots; a.swapAt(idx, idx + 1); commitSlots(a) }
                        } label: { Image(systemName: "chevron.down").foregroundStyle(.secondary) }
                        .buttonStyle(.plain)
                        .disabled(idx == slots.count - 1)
                        Button {
                            var a = slots; a.remove(at: idx); commitSlots(a)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .contentShape(Rectangle())
                    if idx < slots.count - 1 {
                        Divider().padding(.horizontal, 12)
                    }
                }
            }
            Divider().padding(.horizontal, 12)
            Menu {
                ForEach(WidgetKind.allCases.filter { $0.fitsInHeader }) { kind in
                    Button {
                        var a = slots; a.append(HeaderSlot(kind: kind)); commitSlots(a)
                    } label: { Label(kind.label, systemImage: kind.systemImage) }
                }
            } label: {

                HStack(spacing: 10) {
                    Color.clear.frame(width: 18, height: 1)
                    Image(systemName: "plus.circle.fill").frame(width: 18)
                    Text("Add widget")
                    Spacer()
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
        }
        .sheet(item: Binding(
            get: { editingSlotID.flatMap { id in slots.first(where: { $0.id == id }) } },
            set: { _ in editingSlotID = nil }
        )) { editingSlot in
            HeaderSlotEditor(
                initial: editingSlot,
                onCommit: { updated in
                    var newArr = slots
                    if let idx = newArr.firstIndex(where: { $0.id == updated.id }) {
                        newArr[idx] = updated
                        commitSlots(newArr)
                    }
                },
                onDismiss: { editingSlotID = nil }
            )
        }
    }

    private func headerSlotSizeLabel(_ slot: HeaderSlot) -> String {
        let wPart = slot.customWidth.map { "\(Int($0))\(slot.widthUnit.label)" } ?? "auto"
        let hPart = slot.customHeight.map { "\(Int($0))\(slot.heightUnit.label)" } ?? "auto"
        return "\(wPart) × \(hPart)"
    }
}

private struct HeaderSlotEditor: View {
    @State private var slot: HeaderSlot
    let onCommit: (HeaderSlot) -> Void
    var onDismiss: () -> Void

    init(initial: HeaderSlot, onCommit: @escaping (HeaderSlot) -> Void, onDismiss: @escaping () -> Void) {
        _slot = State(initialValue: initial)
        self.onCommit = onCommit
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: slot.kind.systemImage).foregroundStyle(.secondary)
                Text(slot.kind.label).font(.system(size: 13, weight: .semibold))
                Spacer()

                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }

            Text("SIZE").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)

            slotAxisRow(
                label: "Width",
                value: Binding(
                    get: { slot.customWidth },
                    set: { v in var s = slot; s.customWidth = v; slot = s; onCommit(s) }
                ),
                unit: Binding(
                    get: { slot.widthUnit },
                    set: { v in var s = slot; s.widthUnit = v; slot = s; onCommit(s) }
                ),
                pointsDefault: 36,
                maxPoints: 220
            )
            slotAxisRow(
                label: "Height",
                value: Binding(
                    get: { slot.customHeight },
                    set: { v in var s = slot; s.customHeight = v; slot = s; onCommit(s) }
                ),
                unit: Binding(
                    get: { slot.heightUnit },
                    set: { v in var s = slot; s.heightUnit = v; slot = s; onCommit(s) }
                ),
                pointsDefault: 26,
                maxPoints: 60
            )

            if slot.kind == .visualizerBars {
                Divider()
                Text("VISUALIZER").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                SliderRow(title: "Bar count", value: optionBinding(key: "barCount", default: 4),
                          range: 1...12)
                SliderRow(title: "Bar width", value: optionBinding(key: "barWidth", default: 4),
                          range: 1...20, suffix: "pt")
                SliderRow(title: "Bar spacing", value: optionBinding(key: "barSpacing", default: 3),
                          range: 0...20, suffix: "pt")
                SliderRow(title: "Height", value: optionBinding(key: "heightScale", default: 1),
                          range: 0.3...2.5, step: 0.1, suffix: "×")
            }

            if slot.kind == .airdropButton {
                Divider()
                Text("AIRDROP").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                SliderRow(title: "Icon size", value: optionBinding(key: "iconSize", default: 14),
                          range: 8...32, suffix: "pt")
            }

            if slot.kind == .tabSwitcher {
                Divider()
                Text("TAB SWITCHER").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                SliderRow(title: "Icon size", value: optionBinding(key: "iconSize", default: 13),
                          range: 8...28, suffix: "pt")
                SliderRow(title: "Tab spacing", value: optionBinding(key: "spacing", default: 4),
                          range: 0...20, suffix: "pt")
            }

            if slot.kind == .settingsButton {
                Divider()
                Text("SETTINGS BUTTON").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                SliderRow(title: "Icon size", value: optionBinding(key: "iconSize", default: 13),
                          range: 8...28, suffix: "pt")
            }

            if slot.kind == .spacer {
                Divider()
                Text("SPACER").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                Text("Use Width above to set a fixed gap, or leave Auto to push siblings to the edges.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }

            if slot.kind == .batteryPill {
                Divider()
                Text("BATTERY").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                SliderRow(title: "Icon size", value: optionBinding(key: "iconSize", default: 11),
                          range: 8...32, suffix: "pt")
                Toggle("Show percentage", isOn: optionToggleBinding(key: "showPercent", default: 1))
                    .toggleStyle(.switch).controlSize(.small)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                Picker("Color mode", selection: optionEnumBinding(key: "colorMode", default: 0)) {
                    Text("Dynamic (charge-based)").tag(0)
                    Text("White").tag(1)
                    Text("Accent color").tag(2)
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
            }

            if slot.kind == .clock {
                Divider()
                Text("CLOCK").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                Toggle("Analog face", isOn: optionToggleBinding(key: "analog", default: 0))
                    .toggleStyle(.switch).controlSize(.small)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                let analog = (slot.options["analog"] ?? 0) > 0.5
                SliderRow(title: analog ? "Face size" : "Font size",
                          value: optionBinding(key: "fontSize", default: 13),
                          range: 9...28, suffix: "pt")
                if !analog {
                    Toggle("Show seconds", isOn: optionToggleBinding(key: "showSeconds", default: 0))
                        .toggleStyle(.switch).controlSize(.small)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                    Toggle("24-hour format", isOn: optionToggleBinding(key: "use24h", default: 1))
                        .toggleStyle(.switch).controlSize(.small)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                }
            }

            if slot.kind == .dateLabel {
                Divider()
                Text("DATE").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                SliderRow(title: "Font size", value: optionBinding(key: "fontSize", default: 12),
                          range: 9...22, suffix: "pt")
                Picker("Format", selection: optionEnumBinding(key: "format", default: 0)) {
                    Text("Short — Thu, 28").tag(0)
                    Text("Medium — May 28").tag(1)
                    Text("Long — Thu, May 28").tag(2)
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func optionBinding(key: String, default def: Double) -> Binding<Double> {
        Binding(
            get: { slot.options[key] ?? def },
            set: { v in
                var s = slot; s.options[key] = v; slot = s; onCommit(s)
            }
        )
    }

    private func optionToggleBinding(key: String, default def: Double) -> Binding<Bool> {
        Binding(
            get: { (slot.options[key] ?? def) > 0.5 },
            set: { on in
                var s = slot; s.options[key] = on ? 1 : 0; slot = s; onCommit(s)
            }
        )
    }

    private func optionEnumBinding(key: String, default def: Double) -> Binding<Int> {
        Binding(
            get: { Int(slot.options[key] ?? def) },
            set: { v in
                var s = slot; s.options[key] = Double(v); slot = s; onCommit(s)
            }
        )
    }

    @ViewBuilder
    private func slotAxisRow(label: String,
                             value: Binding<Double?>,
                             unit: Binding<WidgetSizeUnit>,
                             pointsDefault: Double,
                             maxPoints: Double) -> some View {
        let isAuto = value.wrappedValue == nil
        let range: ClosedRange<Double> = unit.wrappedValue == .percent ? 0...100 : 8...maxPoints
        HStack(spacing: 12) {
            Text(label).font(.system(size: 12, weight: .medium)).frame(width: 60, alignment: .leading)
            HStack(spacing: 0) {
                ForEach(WidgetSizeUnit.allCases) { u in
                    let selected = unit.wrappedValue == u
                    Text(u.label)
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 30, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selected ? Color.primary.opacity(0.18) : Color.clear)
                        )
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isAuto, unit.wrappedValue != u else { return }
                            let newValue: Double = u == .percent ? 50 : pointsDefault
                            unit.wrappedValue = u
                            value.wrappedValue = newValue
                        }
                }
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
            .opacity(isAuto ? 0.4 : 1)
            .allowsHitTesting(!isAuto)
            Toggle("Auto", isOn: Binding(
                get: { isAuto },
                set: { auto in value.wrappedValue = auto ? nil : pointsDefault }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.horizontal, 12)
        if let v = value.wrappedValue {
            HStack {
                Slider(value: Binding(get: { v }, set: { value.wrappedValue = $0 }), in: range)
                Text("\(Int(v))\(unit.wrappedValue.label)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.horizontal, 12)
        }
    }
}

private struct HeaderSlotDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var slots: [HeaderSlot]

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        provider.loadObject(ofClass: NSString.self) { obj, _ in
            guard let s = obj as? String,
                  s.hasPrefix("headerslot:"),
                  let from = Int(s.dropFirst("headerslot:".count)) else { return }
            DispatchQueue.main.async {
                guard from != targetIndex,
                      from >= 0, from < slots.count,
                      targetIndex >= 0, targetIndex < slots.count else { return }
                let moved = slots.remove(at: from)
                let insertIdx = from < targetIndex ? targetIndex : targetIndex
                slots.insert(moved, at: min(insertIdx, slots.count))
            }
        }
        return true
    }
}

struct CanvasDragPayload: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .canvasDragPayload)
    }
}

extension UTType {
    static let canvasDragPayload = UTType(exportedAs: "io.kubilay.stupidnotch.canvas-drag")
}

private struct CanvasView: View {
    @Binding var root: LayoutNode
    @ObservedObject var settings: AppSettings
    let calendar: CalendarController

    var body: some View {
        if case .stack(let s) = root {
            CanvasStackNode(stack: Binding(
                get: { s },
                set: { root = .stack($0) }
            ), indent: 0, settings: settings, calendar: calendar)
        } else {
            Text("Invalid root layout").foregroundStyle(.red)
        }
    }
}

private struct CanvasStackNode: View {
    @Binding var stack: StackNode
    var indent: Int = 0
    @ObservedObject var settings: AppSettings
    let calendar: CalendarController
    @State private var draggingID: UUID?
    @State private var dropTargetID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            stackHeader

            List {
                ForEach(Array(stack.children.enumerated()), id: \.element.id) { idx, _ in
                    CanvasChildRow(
                        node: Binding(
                            get: { stack.children[idx] },
                            set: { stack.children[idx] = $0 }
                        ),
                        indent: indent,
                        settings: settings,
                        calendar: calendar,
                        onDelete: { stack.children.remove(at: idx) }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: leftPadding, bottom: 0, trailing: 0))
                    .listRowSeparator(.visible)
                    .listRowBackground(Color.clear)
                }
                .onMove { from, to in
                    stack.children.move(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)

            .frame(height: CGFloat(stack.children.count) * 33 + 2)
            Divider().padding(.leading, leftPadding)
            addMenu
        }
    }

    private var leftPadding: CGFloat { 12 + CGFloat(indent) * 16 }

    private var stackHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: stack.axis.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Picker("", selection: $stack.axis) {
                ForEach(StackAxis.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .frame(width: 130)
            Spacer(minLength: 12)
            Picker("", selection: $stack.alignment) {
                ForEach(StackAlignment.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .frame(width: 100)
        }
        .padding(.leading, leftPadding)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
    }

    private var addMenu: some View {
        Menu {
            Section("Widgets") {
                ForEach(WidgetKind.allCases.filter { $0.isUserFacing && $0.fitsInTab }) { kind in
                    Button {
                        stack.children.append(.widget(WidgetInstance(kind: kind)))
                    } label: { Label(kind.label, systemImage: kind.systemImage) }
                }
            }
            Section("Containers") {
                ForEach(StackAxis.allCases) { axis in
                    Button {
                        stack.children.append(.stack(StackNode(axis: axis)))
                    } label: { Label(axis.label, systemImage: axis.systemImage) }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill").frame(width: 18)
                Text(stack.children.isEmpty ? "Add widget" : "Add another")
                Spacer()
            }
            .foregroundStyle(Color.accentColor)
            .padding(.leading, leftPadding)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
    }
}

private struct CanvasChildRow: View {
    @Binding var node: LayoutNode
    var indent: Int = 0
    @ObservedObject var settings: AppSettings
    let calendar: CalendarController
    let onDelete: () -> Void
    @State private var hovering = false
    @State private var showingStyle = false

    private var leftPadding: CGFloat { 12 + CGFloat(indent) * 16 }

    var body: some View {
        switch node {
        case .widget(let w):
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Image(systemName: w.kind.systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(w.kind.label).font(.system(size: 13))
                if w.customWidth != nil || w.customHeight != nil {
                    Text(dimensionsBadge(w))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showingStyle = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .opacity(hovering ? 1 : 0.7)
                .sheet(isPresented: $showingStyle) {
                    WidgetStylePopover(
                        initial: {
                            if case .widget(let inst) = node { return inst }
                            return w
                        }(),
                        onCommit: { updated in
                            node = .widget(updated)
                        },
                        settings: settings,
                        calendar: calendar,
                        onDismiss: { showingStyle = false }
                    )
                }
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red.opacity(0.85))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .opacity(hovering ? 1 : 0.7)
            }
            .padding(.leading, leftPadding)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(hovering ? Color.primary.opacity(0.04) : Color.clear)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }

        case .stack:

            VStack(spacing: 0) {
                CanvasStackNode(stack: Binding(
                    get: {
                        if case .stack(let s) = node { return s }
                        return StackNode(axis: .vertical)
                    },
                    set: { node = .stack($0) }
                ), indent: indent + 1, settings: settings, calendar: calendar)
                HStack {
                    Spacer()
                    Button(action: onDelete) {
                        Label("Remove stack", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(.trailing, 12)
                    .padding(.bottom, 6)
                }
            }
        }
    }

    private func dimensionsBadge(_ w: WidgetInstance) -> String {
        let wPart = w.customWidth.map { "\(Int($0))\(w.widthUnit.label)" } ?? "auto"
        let hPart = w.customHeight.map { "\(Int($0))\(w.heightUnit.label)" } ?? "auto"
        return "\(wPart)×\(hPart)"
    }
}

private struct WidgetStylePopover: View {

    @State private var widget: WidgetInstance
    let onCommit: (WidgetInstance) -> Void
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendar: CalendarController
    var onDismiss: () -> Void = {}

    init(initial: WidgetInstance, onCommit: @escaping (WidgetInstance) -> Void, settings: AppSettings, calendar: CalendarController, onDismiss: @escaping () -> Void = {}) {
        _widget = State(initialValue: initial)
        self.onCommit = onCommit
        self.settings = settings
        self.calendar = calendar
        self.onDismiss = onDismiss
    }

    private var widgetBinding: Binding<WidgetInstance> {
        Binding(
            get: { widget },
            set: { newValue in
                widget = newValue
                onCommit(newValue)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: widget.kind.systemImage).foregroundStyle(.secondary)
                Text(widget.kind.label).font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("SIZE").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                axisRow(label: "Width",
                        valueBinding: Binding(
                            get: { widget.customWidth },
                            set: { v in
                                var w = widget; w.customWidth = v; widget = w; onCommit(w)
                            }
                        ),
                        unitBinding: Binding(
                            get: { widget.widthUnit },
                            set: { v in
                                var w = widget; w.widthUnit = v; widget = w; onCommit(w)
                            }
                        ),
                        pointsDefault: 120,
                        maxPoints: 1200,
                        panelDefaultMark: settings.expandedPanelWidth)
                axisRow(label: "Height",
                        valueBinding: Binding(
                            get: { widget.customHeight },
                            set: { v in
                                var w = widget; w.customHeight = v; widget = w; onCommit(w)
                            }
                        ),
                        unitBinding: Binding(
                            get: { widget.heightUnit },
                            set: { v in
                                var w = widget; w.heightUnit = v; widget = w; onCommit(w)
                            }
                        ),
                        pointsDefault: 80,
                        maxPoints: 600)
            }

            kindSpecific
        }
        .padding(16)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var kindSpecific: some View {
        switch widget.kind {
        case .visualizerBars:
            VisualizerProperties(settings: settings)
        case .calendar:
            CalendarInstanceProperties(widget: widgetBinding)
            CalendarProperties(calendar: calendar)
        case .calendarWeek, .calendarEvents:
            CalendarProperties(calendar: calendar)
        case .mediaPlayer:
            MediaPlayerInstanceProperties(
                widget: Binding(
                    get: { widget },
                    set: { newValue in widget = newValue; onCommit(newValue) }
                )
            )
        case .greeting:
            GreetingInstanceProperties(widget: widgetBinding)
        case .systemPulse:
            SystemPulseInstanceProperties(widget: widgetBinding)
        case .nextEvent:
            NextEventInstanceProperties(widget: widgetBinding)
        default:
            EmptyView()
        }
    }

    private var kindSpecificHasContent: Bool {
        switch widget.kind {
        case .visualizerBars, .calendar, .calendarWeek, .calendarEvents, .mediaPlayer,
             .greeting, .systemPulse, .nextEvent:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private func axisRow(label: String,
                         valueBinding: Binding<Double?>,
                         unitBinding: Binding<WidgetSizeUnit>,
                         pointsDefault: Double,
                         maxPoints: Double = 1200,
                         panelDefaultMark: Double? = nil) -> some View {
        let isAuto = valueBinding.wrappedValue == nil
        let range: ClosedRange<Double> = unitBinding.wrappedValue == .percent ? 0...100 : 20...maxPoints
        let initial: Double = unitBinding.wrappedValue == .percent ? 50 : pointsDefault

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 12, weight: .medium))
                Spacer()

                HStack(spacing: 0) {
                    ForEach(WidgetSizeUnit.allCases) { unit in
                        let selected = unitBinding.wrappedValue == unit
                        Text(unit.label)
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 38, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(selected ? Color.primary.opacity(0.18) : Color.clear)
                            )
                            .foregroundStyle(selected ? Color.primary : Color.secondary)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard !isAuto, unitBinding.wrappedValue != unit else {
                                    return
                                }

                                let newValue: Double = unit == .percent ? 50 : pointsDefault
                                unitBinding.wrappedValue = unit
                                valueBinding.wrappedValue = newValue
                            }
                    }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                )
                .opacity(isAuto ? 0.4 : 1)
                .allowsHitTesting(!isAuto)
                Toggle("Auto", isOn: Binding(
                    get: { isAuto },
                    set: { auto in
                        valueBinding.wrappedValue = auto ? nil : initial
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            if let value = valueBinding.wrappedValue {
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { value },
                        set: { valueBinding.wrappedValue = $0 }
                    ), in: range)
                    .overlay(alignment: .leading) {

                        if let mark = panelDefaultMark,
                           unitBinding.wrappedValue == .points,
                           mark >= range.lowerBound && mark <= range.upperBound {
                            GeometryReader { proxy in
                                let fraction = (mark - range.lowerBound) / (range.upperBound - range.lowerBound)
                                let x = max(0, min(proxy.size.width, proxy.size.width * fraction))
                                Rectangle()
                                    .fill(Color.accentColor.opacity(0.55))
                                    .frame(width: 2, height: 14)
                                    .offset(x: x - 1, y: -7)
                                    .allowsHitTesting(false)
                            }
                            .frame(height: 1)
                        }
                    }
                    Text("\(Int(value))\(unitBinding.wrappedValue.label)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
                if let mark = panelDefaultMark, unitBinding.wrappedValue == .points {
                    Text("Panel grows past \(Int(mark))pt — that's the configured expanded width.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct TabHeaderEditor: View {
    @Binding var tab: TabConfig

    var body: some View {
        HStack(spacing: 10) {
            SymbolPickerButton(selection: $tab.icon)

            TextField("Tab name", text: $tab.name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct SymbolPickerButton: View {
    @Binding var selection: String
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            Image(systemName: selection)
                .font(.system(size: 16))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showing) {
            SymbolPickerSheet(selection: $selection, dismiss: { showing = false })
        }
    }
}

private struct SymbolPickerSheet: View {
    @Binding var selection: String
    let dismiss: () -> Void
    @State private var query: String = ""

    private static let symbols: [(name: String, keywords: String)] = [

        ("house", "home house"), ("house.fill", "home filled"),
        ("square.grid.2x2", "grid apps"), ("rectangle.3.group", "tabs sections"),
        ("rectangle.grid.2x2", "grid"), ("square.stack.3d.up", "layers stack"),
        ("sidebar.left", "sidebar"), ("rectangle.split.3x1", "row"),
        ("ellipsis.circle", "more menu"), ("magnifyingglass", "search find"),
        ("gearshape", "settings preferences"), ("gearshape.fill", "settings"),
        ("slider.horizontal.3", "controls sliders"),

        ("tray.full", "tray inbox files"), ("tray", "inbox"),
        ("folder", "folder directory"), ("folder.fill", "folder"),
        ("doc", "document"), ("doc.text", "document text"),
        ("doc.on.clipboard", "clipboard paste"), ("doc.on.doc", "duplicate copy"),
        ("archivebox", "archive"), ("paperclip", "attachment"),
        ("link", "link url"), ("paperplane", "send"),

        ("music.note", "music audio"), ("music.note.list", "playlist"),
        ("play.rectangle", "video play"), ("play.circle", "play"),
        ("speaker.wave.2", "volume sound"), ("waveform", "audio wave"),
        ("waveform.path", "visualizer"), ("mic", "microphone record"),
        ("headphones", "headphones audio"), ("hifispeaker", "speaker"),
        ("tv", "tv display"), ("airpodsmax", "headphones"),

        ("message", "messages chat"), ("bubble.left", "comment"),
        ("envelope", "mail email"), ("phone", "phone call"),
        ("bell", "notifications alert"), ("bell.badge", "notification"),

        ("person.crop.circle", "user profile account"),
        ("person.2", "people group team"),
        ("person.3", "team group"),

        ("calendar", "calendar date"), ("calendar.badge.clock", "schedule"),
        ("clock", "time"), ("clock.fill", "time"),
        ("alarm", "alarm timer"), ("timer", "timer countdown"),
        ("hourglass", "wait time"),

        ("battery.100", "battery full"), ("battery.50", "battery"),
        ("wifi", "wifi wireless"), ("antenna.radiowaves.left.and.right", "signal"),
        ("bolt", "lightning power"), ("bolt.fill", "power"),
        ("sun.max", "brightness sun"), ("moon", "dark moon night"),
        ("cloud", "cloud weather"), ("thermometer", "temperature"),
        ("flame", "fire hot trending"),

        ("photo", "image picture"), ("photo.on.rectangle", "photos"),
        ("camera", "camera photo"), ("video", "video"),

        ("star", "star favorite"), ("star.fill", "favorite"),
        ("heart", "like heart"), ("heart.fill", "favorite"),
        ("flag", "flag mark"), ("tag", "tag label"),
        ("bookmark", "bookmark save"),
        ("checkmark.seal", "verified check"), ("xmark.octagon", "stop block"),
        ("hand.raised", "stop wave"), ("hand.thumbsup", "like good"),

        ("note.text", "note"), ("list.bullet", "list"),
        ("checklist", "todo tasks"), ("square.and.pencil", "edit compose"),
        ("pencil", "edit"), ("trash", "delete"),

        ("dollarsign.circle", "money usd"), ("creditcard", "card payment"),
        ("cart", "cart shopping"), ("bag", "shop bag"),

        ("gamecontroller", "games gaming"), ("die.face.5", "dice game"),
        ("paintpalette", "design colors"), ("paintbrush", "design"),
        ("hammer", "build tools"), ("wrench.adjustable", "tools"),
        ("bolt.heart", "fitness"), ("figure.run", "running fitness"),
        ("airplane", "travel flight"), ("car", "car drive"),
        ("map", "map navigation"), ("location", "location"),
        ("globe", "world web"), ("network", "network"),
        ("key", "key access"), ("lock", "lock secure"),
        ("eye", "view show"), ("eye.slash", "hide"),
        ("rocket", "launch"), ("hare", "fast"), ("tortoise", "slow"),
    ]

    private static let availableSymbols: [(name: String, keywords: String)] = {
        symbols.filter { NSImage(systemSymbolName: $0.name, accessibilityDescription: nil) != nil }
    }()

    private var filtered: [(name: String, keywords: String)] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return Self.availableSymbols }
        let q = query.lowercased()
        return Self.availableSymbols.filter { $0.name.contains(q) || $0.keywords.contains(q) }
    }

    private let columns = Array(repeating: GridItem(.fixed(56), spacing: 8), count: 8)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search icons", text: $query)
                    .textFieldStyle(.plain)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(filtered, id: \.name) { sym in
                        symbolButton(sym.name)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 540, height: 480)
    }

    private func symbolButton(_ name: String) -> some View {
        let selected = selection == name
        return Button {
            selection = name
            dismiss()
        } label: {
            Image(systemName: name)
                .font(.system(size: 22))
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .help(name)
    }
}

struct NotchPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsForm {
            SettingsSection(
                title: "Dimensions",
                footer: "When auto-detection is on, the notch width and height come from `NSScreen.auxiliaryTopLeftArea` and `safeAreaInsets`. Turn it off to enter your own values — useful when the auto-detected values don't visually match the hardware notch."
            ) {
                SwitchRow(
                    title: "Auto-detect from system",
                    isOn: $settings.useSystemNotchDimensions
                )
                Divider().padding(.horizontal, 12)
                SliderRow(title: "Notch width",
                          value: $settings.customNotchWidth,
                          range: 150...320, suffix: "pt")
                    .disabled(settings.useSystemNotchDimensions)
                    .opacity(settings.useSystemNotchDimensions ? 0.5 : 1)
                Divider().padding(.horizontal, 12)
                SliderRow(title: "Notch height",
                          value: $settings.customNotchHeight,
                          range: 24...60, suffix: "pt")
                    .disabled(settings.useSystemNotchDimensions)
                    .opacity(settings.useSystemNotchDimensions ? 0.5 : 1)
            }

            SettingsSection(
                title: "Peek",
                footer: "Extra width added to the collapsed notch when a peek widget shows (now-playing pill, battery, etc.)."
            ) {
                SliderRow(title: "Peek extra width",
                          value: $settings.peekExtraWidth,
                          range: 40...260, suffix: "pt")
            }

            SettingsSection(
                title: "Expanded size",
                footer: "Total width of the expanded panel. If a widget in the active tab declares a larger custom width, the panel grows to fit it instead — width animates between tabs."
            ) {
                SliderRow(title: "Expanded width",
                          value: $settings.expandedPanelWidth,
                          range: 350...1200, suffix: "pt")
            }

            SettingsSection(title: "Shape & hover area") {
                SliderRow(title: "Bottom corner radius",
                          value: $settings.notchCornerRadius,
                          range: 0...28, suffix: "pt")
                Divider().padding(.horizontal, 12)
                SliderRow(title: "Hover margin (horizontal)",
                          value: $settings.hoverMarginHorizontal,
                          range: 0...80, suffix: "pt")
                Divider().padding(.horizontal, 12)
                SliderRow(title: "Hover margin (vertical)",
                          value: $settings.hoverMarginVertical,
                          range: 0...40, suffix: "pt")
            }

            SettingsSection(
                title: "Animations",
                footer: "Overshoot adds a small Dynamic-Island bounce on expand. Asymmetric hover delays let the cursor drift outside the boundary without slamming the notch shut."
            ) {
                MillisRow(title: "Expand duration",
                          value: $settings.expandDuration, range: 0.15...0.9)
                Divider().padding(.horizontal, 12)
                MillisRow(title: "Collapse duration",
                          value: $settings.collapseDuration, range: 0.12...0.7)
                Divider().padding(.horizontal, 12)
                FractionRow(title: "Expand overshoot",
                            value: $settings.expandOvershoot, range: 0...1)
                Divider().padding(.horizontal, 12)
                MillisRow(title: "Hover open delay",
                          value: $settings.hoverEnterDelay, range: 0...0.5)
                Divider().padding(.horizontal, 12)
                MillisRow(title: "Hover close delay",
                          value: $settings.hoverExitDelay, range: 0...0.8)
            }

            Button("Reset all dimensions & animations") {
                settings.useSystemNotchDimensions = true
                settings.customNotchWidth = 209
                settings.customNotchHeight = 38
                settings.peekExtraWidth = 100
                settings.expandedPanelWidth = 600
                settings.notchCornerRadius = 10
                settings.hoverMarginHorizontal = 28
                settings.hoverMarginVertical = 10
                settings.expandDuration = 0.42
                settings.collapseDuration = 0.32
                settings.expandOvershoot = 0.35
                settings.hoverEnterDelay = 0.05
                settings.hoverExitDelay = 0.18
            }
            .padding(.horizontal, 4)
        }
    }
}

struct MediaPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsForm {
            SettingsSection(
                title: "Now playing",
                footer: "Reads track info from the bundled mediaremote-adapter — works for Apple Music, Spotify, Podcasts, YouTube in Safari/Chrome, VLC, and any other source that publishes NowPlaying."
            ) {
                SwitchRow(
                    title: "Click icon opens the source app",
                    subtitle: "Tapping the artwork in the peek brings the player app (Spotify/Music/Chrome) to the front.",
                    isOn: $settings.clickIconOpensApp
                )
            }

            SettingsSection(title: "Sneak peek on track change") {
                SwitchRow(title: "Enabled", isOn: $settings.sneakPeekEnabled)
                Divider().padding(.horizontal, 12)
                MillisRow(title: "Duration before auto-dismiss",
                          value: $settings.sneakPeekDuration, range: 1.0...6.0)
            }
        }
    }
}

struct ShortcutsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsForm {
            SettingsSection(
                title: "Global hotkeys",
                footer: "Click a hotkey to record. Press Esc to cancel, Backspace to clear."
            ) {
                HotkeyRow(title: "Toggle notch open", binding: $settings.hotkeyToggleNotch)
                Divider().padding(.horizontal, 12)
                HotkeyRow(title: "Show clipboard", binding: $settings.hotkeyClipboard)
                Divider().padding(.horizontal, 12)
                HotkeyRow(title: "Trigger sneak peek", binding: $settings.hotkeySneakPeek)
            }
        }
    }
}

struct WallpaperPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var manager: OverlayManager

    var body: some View {
        SettingsForm {
            SettingsSection(
                title: "Wallpaper corner mask",
                footer: "Legacy feature: rounds the bottom corners of the menu bar by painting a tweaked wallpaper. Independent of the notch overlay above."
            ) {
                PickerRow(title: "Radius", selection: $manager.cornerRadius) {
                    Text("None").tag(0.0)
                    Text("Small").tag(14.0)
                    Text("Medium").tag(22.0)
                    Text("Large").tag(32.0)
                    Text("Huge").tag(48.0)
                }
                Divider().padding(.horizontal, 12)
                PickerRow(title: "Style", selection: $manager.cornerStyle) {
                    ForEach(CornerStyle.allCases, id: \.self) { style in
                        Text(style.label).tag(style)
                    }
                }
            }
            HStack(spacing: 8) {
                if manager.isApplied {
                    Button { manager.remove() } label: {
                        Label("Remove notch mask", systemImage: "rectangle.dashed")
                    }
                    .controlSize(.large)
                } else {
                    Button { manager.apply() } label: {
                        Label("Apply notch mask", systemImage: "rectangle.topthird.inset.filled")
                    }
                    .controlSize(.large)
                    .disabled(!manager.hasNotch || manager.isProcessing)
                }
                if manager.isProcessing { ProgressView().controlSize(.small) }
            }
            if manager.unsupportedWallpaper {
                Label("Dynamic / video wallpaper isn't supported. Switch to a still image first.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if !manager.hasNotch {
                Label("No notched display detected.",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct DebugPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var notch: NotchController

    var body: some View {
        SettingsForm {
            SettingsSection(
                title: "Force notch state",
                footer: "When set, the notch holds that state — hover, music, and sneak peeks are ignored."
            ) {
                PickerRow(title: "State", selection: Binding(
                    get: { DebugForceState(rawValue: settings.debugForceState) ?? .off },
                    set: { settings.debugForceState = $0.rawValue }
                )) {
                    ForEach(DebugForceState.allCases) { Text($0.label).tag($0) }
                }
            }

            SettingsSection(
                title: "Position offset",
                footer: "Pushes the overlay down by N points so it's visible BELOW the hardware notch."
            ) {
                SliderRow(
                    title: "Drop notch below screen top",
                    value: Binding(
                        get: { Double(settings.debugOffsetFromTop) },
                        set: { settings.debugOffsetFromTop = Int($0) }
                    ),
                    range: 0...300, step: 4, suffix: "pt"
                )
            }

            SettingsSection(title: "Diagnostics") {
                SwitchRow(
                    title: "Disable all animations",
                    subtitle: "Window resize and SwiftUI transitions become instant.",
                    isOn: $settings.debugDisableAnimations
                )
                Divider().padding(.horizontal, 12)
                SwitchRow(
                    title: "Show size HUD on notch",
                    subtitle: "Tiny live overlay at the bottom of the expanded panel — measured content height vs. window frame.",
                    isOn: $settings.debugSizeHUD
                )
            }
        }
    }
}

struct AboutPane: View {
    @State private var showingLicense: ThirdPartyLicense?
    @State private var update: UpdateStatus = .idle

    private static let repoURL = URL(string: "https://github.com/kubilaysalih/stupidnotch")!

    var body: some View {
        SettingsForm {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon).resizable().frame(width: 64, height: 64)
                    }
                    VStack(alignment: .leading) {
                        Text("StupidNotch").font(.title2).fontWeight(.semibold)
                        Text(versionString).foregroundStyle(.secondary)
                    }
                }
                Text("A notch utility that turns the MacBook notch into a useful surface — media, files, clipboard, calendar, and battery, with system-wide NowPlaying via mediaremote-adapter.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsSection(title: "Project") {
                HStack {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .foregroundStyle(.secondary)
                    Link("github.com/kubilaysalih/stupidnotch", destination: Self.repoURL)
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                Divider().padding(.horizontal, 12)
                HStack(spacing: 10) {
                    updateStatusView
                    Spacer()
                    if case .available(_, let url) = update {
                        Button("Download") { NSWorkspace.shared.open(url) }
                            .controlSize(.small)
                    }
                    Button("Check") { Task { await checkForUpdates() } }
                        .controlSize(.small)
                        .disabled(update == .checking)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }

            SettingsSection(
                title: "Third-party software",
                footer: "StupidNotch bundles the software listed above under their respective licenses."
            ) {
                ForEach(ThirdPartyLicense.bundled) { lic in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lic.name).font(.system(size: 13, weight: .semibold))
                            Text("\(lic.spdx) · \(lic.copyright)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("View license") { showingLicense = lic }
                            .controlSize(.small)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                }
            }
        }
        .sheet(item: $showingLicense) { lic in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(lic.name).font(.headline)
                    Spacer()
                    Button("Done") { showingLicense = nil }
                        .keyboardShortcut(.cancelAction)
                }
                ScrollView {
                    Text(lic.text)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .frame(width: 560, height: 420)
        }
        .task { await checkForUpdates() }
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch update {
        case .idle:
            Text("Checking for updates…").foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            }
        case .upToDate:
            Label("Up to date", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .available(let tag, _):
            Label("Update available — \(tag)", systemImage: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
        case .failed:
            Label("Couldn't check for updates", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Version \(v) (build \(b))"
    }

    @MainActor
    private func checkForUpdates() async {
        update = .checking
        guard let url = URL(string: "https://api.github.com/repos/kubilaysalih/stupidnotch/releases/latest") else {
            update = .failed; return
        }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 10
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                update = .failed; return
            }
            let releaseURL = (json["html_url"] as? String).flatMap(URL.init) ?? Self.repoURL
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            if Self.isNewer(latest, than: currentVersion) {
                update = .available(tag, releaseURL)
            } else {
                update = .upToDate(currentVersion)
            }
        } catch {
            update = .failed
        }
    }

    /// Numeric dot-separated comparison: returns true when `latest` > `current`.
    static func isNewer(_ latest: String, than current: String) -> Bool {
        let a = latest.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0
            let c = i < b.count ? b[i] : 0
            if l != c { return l > c }
        }
        return false
    }
}

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate(String)
    case available(String, URL)
    case failed
}

struct ThirdPartyLicense: Identifiable {
    let id = UUID()
    let name: String
    let spdx: String
    let copyright: String
    let resource: String

    var text: String {
        if let url = Bundle.main.url(forResource: resource, withExtension: "txt", subdirectory: "Licenses"),
           let s = try? String(contentsOf: url, encoding: .utf8) {
            return s
        }
        return "License file not found in bundle."
    }

    static let bundled: [ThirdPartyLicense] = [
        ThirdPartyLicense(
            name: "MediaRemoteAdapter",
            spdx: "BSD-3-Clause",
            copyright: "© 2025 Jonas van den Berg and contributors",
            resource: "MediaRemoteAdapter-LICENSE"
        )
    ]
}

struct HotkeyRow: View {
    let title: String
    @Binding var binding: HotkeyValue?
    @State private var recording = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                recording.toggle()
            } label: {
                Text(displayText)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(recording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .background(HotkeyRecorder(recording: $recording, binding: $binding))
            if binding != nil {
                Button {
                    binding = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var displayText: String {
        guard let binding else { return recording ? "Press keys…" : "Not set" }
        return HotkeyFormatter.display(binding)
    }
}

private struct HotkeyRecorder: NSViewRepresentable {
    @Binding var recording: Bool
    @Binding var binding: HotkeyValue?

    func makeNSView(context: Context) -> RecorderView {
        let v = RecorderView()
        v.onCapture = { value in
            binding = value
            recording = false
        }
        return v
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.isRecording = recording
        if recording {
            DispatchQueue.main.async { nsView.window?.makeFirstResponder(nsView) }
        }
    }

    final class RecorderView: NSView {
        var isRecording = false
        var onCapture: ((HotkeyValue?) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            guard isRecording else { super.keyDown(with: event); return }
            if event.keyCode == 53 { onCapture?(nil); return }
            if event.keyCode == 51 { onCapture?(nil); return }
            let mods = UInt32(event.modifierFlags.intersection([.command, .option, .control, .shift]).rawValue)
            onCapture?(HotkeyValue(keyCode: UInt32(event.keyCode), modifiers: mods))
        }
    }
}

enum HotkeyFormatter {
    static func display(_ v: HotkeyValue) -> String {
        var s = ""
        let mods = NSEvent.ModifierFlags(rawValue: UInt(v.modifiers))
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option)  { s += "⌥" }
        if mods.contains(.shift)   { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        s += keyName(for: v.keyCode)
        return s
    }

    private static func keyName(for code: UInt32) -> String {
        let map: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=",
            25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "⇥", 49: "Space", 50: "`", 53: "Esc",
            122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        return map[code] ?? "k\(code)"
    }
}
