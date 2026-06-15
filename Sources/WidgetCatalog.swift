import Foundation
import SwiftUI

enum WidgetKind: String, CaseIterable, Codable, Identifiable {

    case mediaPlayer
    case mediaCompact
    case mediaArtwork
    case nowPlayingText
    case mediaProgress
    case mediaControls
    case visualizerBars

    case tray
    case clipboardList
    case airdropButton

    case batteryPill
    case clock
    case dateLabel
    case greeting
    case systemPulse
    case nextEvent

    case calendar
    case calendarWeek
    case calendarEvents

    case tabSwitcher
    case settingsButton

    case spacer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mediaPlayer: return "Media player"
        case .mediaCompact: return "Media (compact)"
        case .mediaArtwork: return "Album artwork"
        case .nowPlayingText: return "Track title + artist"
        case .mediaProgress: return "Progress bar"
        case .mediaControls: return "Playback controls"
        case .visualizerBars: return "Visualizer"
        case .tray: return "File tray"
        case .clipboardList: return "Clipboard history"
        case .airdropButton: return "AirDrop button"
        case .batteryPill: return "Battery"
        case .clock: return "Clock"
        case .dateLabel: return "Date"
        case .greeting: return "Greeting"
        case .systemPulse: return "System pulse"
        case .nextEvent: return "Next event"
        case .calendar: return "Calendar"
        case .calendarWeek: return "Calendar week strip"
        case .calendarEvents: return "Today's events"
        case .tabSwitcher: return "Tab switcher"
        case .settingsButton: return "Settings button"
        case .spacer: return "Spacer"
        }
    }

    var systemImage: String {
        switch self {
        case .mediaPlayer: return "play.rectangle"
        case .mediaCompact: return "play.square"
        case .mediaArtwork: return "music.note"
        case .nowPlayingText: return "text.alignleft"
        case .mediaProgress: return "minus"
        case .mediaControls: return "play.fill"
        case .visualizerBars: return "waveform.path"
        case .tray: return "tray.full"
        case .clipboardList: return "doc.on.clipboard"
        case .airdropButton: return "wifi"
        case .batteryPill: return "battery.100"
        case .clock: return "clock"
        case .dateLabel: return "calendar.badge.clock"
        case .greeting: return "hand.wave"
        case .systemPulse: return "cpu"
        case .nextEvent: return "calendar.badge.clock"
        case .calendar: return "calendar"
        case .calendarWeek: return "calendar.day.timeline.left"
        case .calendarEvents: return "list.bullet"
        case .tabSwitcher: return "square.grid.3x1.below.line.grid.1x2"
        case .settingsButton: return "gearshape"
        case .spacer: return "arrow.left.and.right"
        }
    }

    var fitsInPeek: Bool {
        switch self {
        case .mediaArtwork, .visualizerBars,
             .batteryPill, .clock, .dateLabel:
            return true
        default:
            return false
        }
    }

    var isUserFacing: Bool {
        switch self {
        case .nowPlayingText, .mediaProgress, .mediaControls,
             .calendarWeek, .calendarEvents, .spacer,
             .tabSwitcher, .settingsButton,
             .mediaCompact:
            return false
        default:
            return true
        }
    }

    var fitsInTab: Bool {
        switch self {
        case .spacer, .tabSwitcher, .settingsButton: return false
        default: return true
        }
    }

    var fitsInHeader: Bool {
        switch self {
        case .tabSwitcher, .settingsButton, .batteryPill, .clock, .dateLabel,
             .visualizerBars, .airdropButton, .spacer:
            return true
        default: return false
        }
    }

    var estimatedContentHeight: CGFloat {
        switch self {
        case .mediaPlayer: return 96
        case .mediaCompact: return 50
        case .mediaArtwork: return 72
        case .nowPlayingText: return 32
        case .mediaProgress: return 10
        case .mediaControls: return 28
        case .visualizerBars: return 40
        case .tray: return 110
        case .clipboardList: return 90
        case .airdropButton: return 30
        case .batteryPill: return 24
        case .clock: return 22
        case .dateLabel: return 22
        case .greeting: return 22
        case .systemPulse: return 28
        case .nextEvent: return 24
        case .calendar: return 130
        case .calendarWeek: return 48
        case .calendarEvents: return 90
        case .tabSwitcher: return 26
        case .settingsButton: return 26
        case .spacer: return 8
        }
    }

    var estimatedPeekWidth: CGFloat {
        switch self {
        case .mediaArtwork: return 30
        case .visualizerBars: return 36
        case .batteryPill: return 78
        case .clock: return 48
        case .dateLabel: return 64
        case .airdropButton: return 32
        case .tabSwitcher: return 80
        case .settingsButton: return 32
        case .spacer: return 16
        default: return 32
        }
    }

    var requiresMedia: Bool {
        switch self {
        case .mediaPlayer, .mediaCompact, .mediaArtwork,
             .nowPlayingText, .mediaProgress, .mediaControls,
             .visualizerBars:
            return true
        default:
            return false
        }
    }

    var requiresTrayItems: Bool { self == .airdropButton }
}

enum WidgetSizeUnit: String, Codable, CaseIterable, Identifiable {
    case points, percent
    var id: String { rawValue }
    var label: String { self == .points ? "pt" : "%" }
}

struct WidgetInstance: Codable, Identifiable, Hashable {
    let id: UUID
    var kind: WidgetKind

    var customWidth: Double? = nil
    var customHeight: Double? = nil
    var widthUnit: WidgetSizeUnit = .points
    var heightUnit: WidgetSizeUnit = .points

    var options: [String: Double] = [:]

    init(id: UUID = UUID(),
         kind: WidgetKind,
         customWidth: Double? = nil,
         customHeight: Double? = nil,
         widthUnit: WidgetSizeUnit = .points,
         heightUnit: WidgetSizeUnit = .points,
         options: [String: Double] = [:]) {
        self.id = id
        self.kind = kind
        self.customWidth = customWidth
        self.customHeight = customHeight
        self.widthUnit = widthUnit
        self.heightUnit = heightUnit
        self.options = options
    }
}

struct TabConfig: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var root: LayoutNode

    init(id: UUID = UUID(),
         name: String,
         icon: String,
         root: LayoutNode = .stack(StackNode(axis: .vertical))) {
        self.id = id
        self.name = name
        self.icon = icon
        self.root = root
    }

    init(id: UUID = UUID(), name: String, icon: String, widgets: [WidgetInstance]) {
        self.id = id
        self.name = name
        self.icon = icon
        let nodes = widgets.map { LayoutNode.widget($0) }
        self.root = .stack(StackNode(axis: .vertical, children: nodes))
    }
}

enum LayoutNode: Codable, Identifiable, Hashable {
    case widget(WidgetInstance)
    case stack(StackNode)

    var intrinsicPointsWidth: CGFloat {
        switch self {
        case .widget(let w):
            if w.widthUnit == .points, let cw = w.customWidth { return CGFloat(cw) }
            return 0
        case .stack(let s):
            let childWidths = s.children.map { $0.intrinsicPointsWidth }
            switch s.axis {
            case .horizontal:
                let sum = childWidths.reduce(0, +)
                let gaps = CGFloat(max(0, s.children.count - 1)) * CGFloat(s.spacing)
                return sum + gaps
            case .vertical:
                return childWidths.max() ?? 0
            }
        }
    }

    var id: UUID {
        switch self {
        case .widget(let w): return w.id
        case .stack(let s): return s.id
        }
    }
}

enum StackAxis: String, Codable, CaseIterable, Identifiable {
    case horizontal, vertical
    var id: String { rawValue }
    var label: String { self == .horizontal ? "Horizontal stack" : "Vertical stack" }
    var systemImage: String { self == .horizontal ? "rectangle.split.3x1" : "rectangle.split.1x2" }
}

enum StackAlignment: String, Codable, CaseIterable, Identifiable {
    case start, center, end
    var id: String { rawValue }
    var label: String {
        switch self {
        case .start: return "Start"
        case .center: return "Center"
        case .end: return "End"
        }
    }
}

struct StackNode: Codable, Identifiable, Hashable {
    let id: UUID
    var axis: StackAxis
    var alignment: StackAlignment
    var spacing: Double
    var children: [LayoutNode]

    init(id: UUID = UUID(),
         axis: StackAxis,
         alignment: StackAlignment = .start,
         spacing: Double = 8,
         children: [LayoutNode] = []) {
        self.id = id
        self.axis = axis
        self.alignment = alignment
        self.spacing = spacing
        self.children = children
    }
}

struct LayoutConfig: Codable, Equatable {
    var tabs: [TabConfig]

    var peekLeftSlots: [HeaderSlot] = []
    var peekRightSlots: [HeaderSlot] = []

    var peekLeft: WidgetKind? = nil
    var peekRight: WidgetKind? = nil

    var expandedHeaderLeft: [HeaderSlot] = []
    var expandedHeaderRight: [HeaderSlot] = []
    var expandedHeaderLeftExtras: [WidgetKind] = []
    var expandedHeaderRightExtras: [WidgetKind] = []

    static var `default`: LayoutConfig {

        let dashboardRoot: LayoutNode = .stack(StackNode(
            axis: .vertical,
            alignment: .start,
            spacing: 8,
            children: [
                .widget(WidgetInstance(kind: .greeting, options: ["fontSize": 13])),
                .stack(StackNode(
                    axis: .horizontal,
                    alignment: .start,
                    spacing: 14,
                    children: [
                        .widget(WidgetInstance(kind: .mediaPlayer, options: [
                            "showArtwork": 1, "showTitle": 1, "showArtist": 1,
                            "showProgress": 0, "showTimes": 0,
                            "showControls": 1, "showVisualizer": 0,
                            "artworkSize": 44
                        ])),
                        .widget(WidgetInstance(kind: .calendar, options: [
                            "compact": 1, "showWeek": 1, "showEvents": 1,
                            "eventLimit": 3, "fontScale": 1
                        ]))
                    ]
                ))
            ]
        ))
        return LayoutConfig(
            tabs: [
                TabConfig(name: "Dashboard", icon: "rectangle.grid.2x2", root: dashboardRoot),
                TabConfig(name: "Tray", icon: "tray.full", widgets: [WidgetInstance(kind: .tray)]),
                TabConfig(name: "Clipboard", icon: "doc.on.clipboard", widgets: [WidgetInstance(kind: .clipboardList)]),
                TabConfig(name: "Calendar", icon: "calendar", widgets: [WidgetInstance(kind: .calendar)])
            ],
            peekLeftSlots: [HeaderSlot(kind: .mediaArtwork)],
            peekRightSlots: [HeaderSlot(kind: .visualizerBars)],
            expandedHeaderLeft: [HeaderSlot(kind: .tabSwitcher)],
            expandedHeaderRight: [HeaderSlot(kind: .settingsButton)]
        )
    }

    mutating func migrateLegacyHeaderArrays() {
        if expandedHeaderLeft.isEmpty && !expandedHeaderLeftExtras.isEmpty {
            expandedHeaderLeft = expandedHeaderLeftExtras.map { HeaderSlot(kind: $0) }
        }
        if expandedHeaderRight.isEmpty && !expandedHeaderRightExtras.isEmpty {
            expandedHeaderRight = expandedHeaderRightExtras.map { HeaderSlot(kind: $0) }
        }
        expandedHeaderLeftExtras = []
        expandedHeaderRightExtras = []

        if peekLeftSlots.isEmpty, let k = peekLeft {
            peekLeftSlots = [HeaderSlot(kind: k)]
        }
        if peekRightSlots.isEmpty, let k = peekRight {
            peekRightSlots = [HeaderSlot(kind: k)]
        }
        peekLeft = nil
        peekRight = nil
    }
}

struct HeaderSlot: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    var kind: WidgetKind
    var customWidth: Double? = nil
    var customHeight: Double? = nil
    var widthUnit: WidgetSizeUnit = .points
    var heightUnit: WidgetSizeUnit = .points

    var options: [String: Double] = [:]

    init(id: UUID = UUID(), kind: WidgetKind,
         customWidth: Double? = nil, customHeight: Double? = nil,
         widthUnit: WidgetSizeUnit = .points,
         heightUnit: WidgetSizeUnit = .points,
         options: [String: Double] = [:]) {
        self.id = id
        self.kind = kind
        self.customWidth = customWidth
        self.customHeight = customHeight
        self.widthUnit = widthUnit
        self.heightUnit = heightUnit
        self.options = options
    }
}

struct SlotSize: Codable, Equatable, Hashable {
    var width: Double?
    var height: Double?
}

extension LayoutNode {

    var children: [LayoutNode] {
        if case .stack(let s) = self { return s.children }
        return []
    }

    func contains(kind: WidgetKind) -> Bool {
        switch self {
        case .widget(let w): return w.kind == kind
        case .stack(let s):  return s.children.contains { $0.contains(kind: kind) }
        }
    }
}

extension TabConfig {

    func contains(kind: WidgetKind) -> Bool { root.contains(kind: kind) }
}

extension LayoutConfig {

    func usesAny(of kinds: Set<WidgetKind>) -> Bool {
        if peekLeftSlots.contains(where: { kinds.contains($0.kind) }) { return true }
        if peekRightSlots.contains(where: { kinds.contains($0.kind) }) { return true }
        if let l = peekLeft, kinds.contains(l) { return true }
        if let r = peekRight, kinds.contains(r) { return true }
        if expandedHeaderLeft.contains(where: { kinds.contains($0.kind) }) { return true }
        if expandedHeaderRight.contains(where: { kinds.contains($0.kind) }) { return true }
        if expandedHeaderLeftExtras.contains(where: kinds.contains) { return true }
        if expandedHeaderRightExtras.contains(where: kinds.contains) { return true }
        return tabs.contains { tab in kinds.contains { tab.contains(kind: $0) } }
    }
}
