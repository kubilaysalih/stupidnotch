import SwiftUI
import AppKit

struct LayoutNodeView: View {
    let node: LayoutNode
    let context: WidgetContext

    var body: some View {
        switch node {
        case .widget(let w):
            WidgetView(kind: w.kind, context: context, options: w.options)
                .modifier(WidgetFrameOverride(
                    width: w.customWidth, widthUnit: w.widthUnit,
                    height: w.customHeight, heightUnit: w.heightUnit
                ))
        case .stack(let s):
            stackView(s)
        }
    }

    @ViewBuilder
    private func stackView(_ s: StackNode) -> some View {
        let alignment = swiftAlignment(s.alignment, axis: s.axis)
        switch s.axis {
        case .vertical:

            VStack(alignment: alignment.h, spacing: CGFloat(s.spacing)) {
                ForEach(s.children) { child in
                    LayoutNodeView(node: child, context: context)
                }
            }
            .frame(maxWidth: .infinity, alignment: horizontalFrameAlignment(s.alignment))
        case .horizontal:
            HStack(alignment: alignment.v, spacing: CGFloat(s.spacing)) {
                ForEach(s.children) { child in
                    LayoutNodeView(node: child, context: context)
                }
            }
            .frame(maxWidth: .infinity, alignment: horizontalFrameAlignment(s.alignment))
        }
    }

    private func horizontalFrameAlignment(_ a: StackAlignment) -> Alignment {
        switch a {
        case .start: return .leading
        case .center: return .center
        case .end: return .trailing
        }
    }

    private struct WidgetFrameOverride: ViewModifier {
        let width: Double?
        let widthUnit: WidgetSizeUnit
        let height: Double?
        let heightUnit: WidgetSizeUnit

        func body(content: Content) -> some View {

            content
                .modifier(AxisOverride(axis: .horizontal, value: width, unit: widthUnit))
                .modifier(AxisOverride(axis: .vertical, value: height, unit: heightUnit))
        }
    }

    private struct AxisOverride: ViewModifier {
        let axis: Axis
        let value: Double?
        let unit: WidgetSizeUnit

        func body(content: Content) -> some View {
            guard let value else {

                if axis == .horizontal {
                    return AnyView(content.frame(maxWidth: .infinity))
                } else {
                    return AnyView(content)
                }
            }
            switch unit {
            case .points:
                if axis == .horizontal {
                    return AnyView(content.frame(width: value))
                } else {
                    return AnyView(content.frame(height: value))
                }
            case .percent:
                let fraction = max(0, min(1, value / 100))
                if axis == .horizontal {
                    return AnyView(content.containerRelativeFrame(.horizontal) { w, _ in w * fraction })
                } else {
                    return AnyView(content.containerRelativeFrame(.vertical) { h, _ in h * fraction })
                }
            }
        }
    }

    private func swiftAlignment(_ a: StackAlignment, axis: StackAxis) -> (h: HorizontalAlignment, v: VerticalAlignment) {
        switch a {
        case .start: return (.leading, .top)
        case .center: return (.center, .center)
        case .end: return (.trailing, .bottom)
        }
    }
}

struct WidgetView: View {
    let kind: WidgetKind
    let context: WidgetContext

    var options: [String: Double] = [:]

    var body: some View {
        switch kind {
        case .mediaPlayer:     MediaPlayerWidget(context: context, options: options)

        case .mediaCompact:    MediaCompactWidget(context: context)
        case .mediaArtwork:    MediaArtworkWidget(context: context)
        case .nowPlayingText:  NowPlayingTextWidget(context: context)
        case .mediaProgress:   MediaProgressWidget(context: context)
        case .mediaControls:   MediaControlsWidget(context: context)
        case .visualizerBars:  VisualizerBarsWidget(context: context, options: options)
        case .tray:            TrayWidget(context: context)
        case .clipboardList:   ClipboardWidget(context: context)
        case .airdropButton:   AirDropButtonWidget(context: context, options: options)
        case .batteryPill:     BatteryPillWidget(context: context, options: options)
        case .clock:           ClockWidget(options: options)
        case .dateLabel:       DateWidget(options: options)
        case .calendar:        CalendarFullWidget(context: context, options: options)
        case .calendarWeek:    CalendarWeekWidget(context: context)
        case .calendarEvents:  CalendarEventsWidget(context: context)
        case .tabSwitcher:     TabSwitcherWidget(context: context, options: options)
        case .settingsButton:  SettingsButtonWidget(options: options)
        case .greeting:        GreetingWidget(options: options)
        case .systemPulse:     SystemPulseWidget(options: options)
        case .nextEvent:       NextEventWidget(context: context, options: options)
        case .spacer:          Spacer(minLength: 0)
        }
    }
}

private struct TabSwitcherWidget: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var controller: NotchController
    let options: [String: Double]
    init(context: WidgetContext, options: [String: Double] = [:]) {
        self.settings = context.settings
        self.controller = context.controller
        self.options = options
    }
    var body: some View {
        let iconSize = CGFloat(options["iconSize"] ?? 13)
        let spacing = CGFloat(options["spacing"] ?? 4)
        HStack(spacing: spacing) {
            ForEach(settings.layout.tabs) { tab in
                NotchHeaderButton(
                    icon: tab.icon,
                    isSelected: controller.currentTabID == tab.id,
                    action: { controller.currentTabID = tab.id },
                    iconSize: iconSize
                )
            }
        }
    }
}

private struct SettingsButtonWidget: View {
    let options: [String: Double]
    init(options: [String: Double] = [:]) { self.options = options }
    var body: some View {
        let iconSize = CGFloat(options["iconSize"] ?? 13)
        NotchHeaderButton(
            icon: "gearshape",
            isSelected: false,
            action: { NSApp.sendAction(#selector(AppDelegate.openSettings(_:)), to: nil, from: nil) },
            iconSize: iconSize
        )
    }
}

struct WidgetContext {
    let controller: NotchController
    let media: MediaController
    let tray: TrayController
    let clipboard: ClipboardController
    let calendarCtrl: CalendarController
    let battery: BatteryController
    let settings: AppSettings
    let artworkNamespace: Namespace.ID?

    init(controller: NotchController, artworkNamespace: Namespace.ID? = nil) {
        self.controller = controller
        self.media = controller.media
        self.tray = controller.tray
        self.clipboard = controller.clipboard
        self.calendarCtrl = controller.calendar
        self.battery = controller.battery
        self.settings = controller.settings
        self.artworkNamespace = artworkNamespace
    }
}

private struct MediaPlayerWidget: View {
    let context: WidgetContext
    let options: [String: Double]
    init(context: WidgetContext, options: [String: Double] = [:]) {
        self.context = context
        self.options = options
    }
    var body: some View {
        if let ns = context.artworkNamespace {
            HomeTab(controller: context.controller, artworkNamespace: ns, options: options)
        } else {
            HomeTab(controller: context.controller, artworkNamespace: Namespace().wrappedValue, options: options)
        }
    }
}

private struct MediaArtworkWidget: View {
    let context: WidgetContext
    @ObservedObject var media: MediaController

    init(context: WidgetContext) {
        self.context = context
        self.media = context.media
    }

    var body: some View {
        let side: CGFloat = NotchGeometry.baseNotchHeight - 8
        Button {
            context.controller.openCurrentMediaApp()
        } label: {
            artwork
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

        }
        .buttonStyle(.plain)
        .disabled(!context.settings.clickIconOpensApp || media.nowPlaying?.bundleID == nil)
    }

    @ViewBuilder
    private var artwork: some View {
        if let img = media.nowPlaying?.artwork {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
        } else if let bundleID = media.nowPlaying?.bundleID,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable().aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                LinearGradient(colors: [.purple.opacity(0.55), .indigo.opacity(0.45)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

private struct ArtworkMatchedGeometryDeleted: ViewModifier {
    let namespace: Namespace.ID?
    func body(content: Content) -> some View {
        if let ns = namespace {
            content.matchedGeometryEffect(id: "media-artwork", in: ns)
        } else {
            content
        }
    }
}

private struct NowPlayingTextWidget: View {
    @ObservedObject var media: MediaController
    init(context: WidgetContext) { self.media = context.media }

    var body: some View {
        if let item = media.nowPlaying {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white).lineLimit(1)
                Text(item.artist).font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.65)).lineLimit(1)
            }
        }
    }
}

private struct MediaProgressWidget: View {
    @ObservedObject var media: MediaController
    init(context: WidgetContext) { self.media = context.media }

    var body: some View {
        if let item = media.nowPlaying {
            MediaProgress(elapsed: media.elapsed, duration: item.duration)
                .frame(height: 3)
        }
    }
}

private struct MediaControlsWidget: View {
    let media: MediaController
    init(context: WidgetContext) { self.media = context.media }

    var body: some View {
        HStack(spacing: 4) {
            Button { media.previous() } label: { Image(systemName: "backward.fill") }
            Button { media.togglePlay() } label: { Image(systemName: "playpause.fill") }
            Button { media.next() } label: { Image(systemName: "forward.fill") }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }
}

private struct VisualizerBarsWidget: View {
    @ObservedObject var media: MediaController
    @ObservedObject var settings: AppSettings
    let options: [String: Double]

    init(context: WidgetContext, options: [String: Double] = [:]) {
        self.media = context.media
        self.settings = context.settings
        self.options = options
    }

    var body: some View {
        let count = Int(options["barCount"] ?? Double(settings.visualizerBarCount))
        let barW  = options["barWidth"]   ?? settings.visualizerBarWidth
        let barS  = options["barSpacing"] ?? settings.visualizerBarSpacing

        let heightScale = CGFloat(options["heightScale"] ?? 1)
        let safeCount = max(1, count)
        let width = CGFloat(safeCount) * barW + CGFloat(safeCount - 1) * barS + 4
        let baseH = NotchGeometry.baseNotchHeight - 12
        VisualizerBars(
            active: media.isPlaying,
            alignment: VisualizerAlignment(rawValue: settings.visualizerAlignment) ?? .centered,
            barCount: safeCount,
            barWidth: barW,
            barSpacing: barS
        )
        .frame(width: max(22, width), height: max(6, baseH * heightScale))
    }
}

private struct TrayWidget: View {
    let context: WidgetContext
    var body: some View {
        TrayTab(controller: context.controller)
    }
}

private struct ClipboardWidget: View {
    let context: WidgetContext
    var body: some View {
        ClipboardTab(controller: context.controller)
    }
}

private struct AirDropButtonWidget: View {
    let context: WidgetContext
    let options: [String: Double]
    @State private var hovering = false

    init(context: WidgetContext, options: [String: Double] = [:]) {
        self.context = context
        self.options = options
    }

    var body: some View {

        let pinnedIcon: CGFloat? = options["iconSize"].map { CGFloat($0) }
        Button {
            context.tray.shareAllViaAirDrop()
        } label: {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let showLabel = geo.size.height >= 56 && geo.size.width >= 70
                let iconSize = pinnedIcon ?? max(11, min(showLabel ? side * 0.45 : side * 0.55, 32))
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(background)
                    VStack(spacing: 4) {
                        Image(systemName: "wifi")
                            .rotationEffect(.degrees(-45))
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(foreground)
                        if showLabel {
                            Text("AirDrop")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(foreground)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .frame(
                minWidth: pinnedIcon.map { $0 + 12 } ?? 30,
                minHeight: pinnedIcon.map { $0 + 8 } ?? 26
            )
        }
        .buttonStyle(.plain)
        .disabled(context.tray.items.isEmpty)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private var background: Color {
        hovering && !context.tray.items.isEmpty ? Color.white.opacity(0.12) : Color.white.opacity(0.04)
    }

    private var foreground: Color {

        let disabled = context.tray.items.isEmpty
        if disabled { return Color.white.opacity(0.75) }
        return Color.white.opacity(hovering ? 1 : 0.9)
    }
}

private struct BatteryPillWidget: View {
    @ObservedObject var battery: BatteryController
    let options: [String: Double]
    init(context: WidgetContext, options: [String: Double] = [:]) {
        self.battery = context.battery
        self.options = options
    }

    var body: some View {
        if let pct = battery.percent {
            let showPercent = (options["showPercent"] ?? 1) > 0.5
            let colorMode = Int(options["colorMode"] ?? 0)
            let iconSize = CGFloat(options["iconSize"] ?? 11)
            BatteryPill(
                percent: pct,
                icon: battery.iconName,
                charging: battery.isCharging,
                showPercent: showPercent,
                tint: batteryTint(mode: colorMode, percent: pct, charging: battery.isCharging),
                iconSize: iconSize
            )
        }
    }

    private func batteryTint(mode: Int, percent: Double, charging: Bool) -> Color {
        switch mode {
        case 1: return .white
        case 2: return .accentColor
        default:
            if charging { return .green }
            if percent <= 20 { return .red }
            if percent <= 40 { return .orange }
            return .white
        }
    }
}

private struct ClockWidget: View {
    let options: [String: Double]
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(options: [String: Double] = [:]) { self.options = options }

    var body: some View {
        let fontSize = options["fontSize"] ?? 11
        let analog   = (options["analog"] ?? 0) > 0.5
        let showSec  = (options["showSeconds"] ?? 0) > 0.5
        let use24    = (options["use24h"] ?? 1) > 0.5
        Group {
            if analog {
                AnalogClock(date: now, size: max(18, fontSize * 1.8))
            } else {
                Text(formatted(now, showSec: showSec, use24: use24))
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
        .onReceive(timer) { now = $0 }
    }

    private func formatted(_ d: Date, showSec: Bool, use24: Bool) -> String {
        let f = DateFormatter()
        if use24 {
            f.dateFormat = showSec ? "HH:mm:ss" : "HH:mm"
        } else {
            f.dateFormat = showSec ? "h:mm:ss a" : "h:mm a"
        }
        return f.string(from: d)
    }
}

private struct AnalogClock: View {
    let date: Date
    let size: CGFloat
    var body: some View {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second], from: date)
        let h = Double((comps.hour ?? 0) % 12) + Double(comps.minute ?? 0) / 60
        let m = Double(comps.minute ?? 0) + Double(comps.second ?? 0) / 60
        let s = Double(comps.second ?? 0)
        ZStack {
            Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
            ClockHand(angle: h / 12 * 360, length: size * 0.30, width: 1.6, color: .white)
            ClockHand(angle: m / 60 * 360, length: size * 0.40, width: 1.2, color: .white)
            ClockHand(angle: s / 60 * 360, length: size * 0.45, width: 0.8, color: .red)
            Circle().fill(Color.white).frame(width: 2, height: 2)
        }
        .frame(width: size, height: size)
    }
}

private struct ClockHand: View {
    let angle: Double
    let length: CGFloat
    let width: CGFloat
    let color: Color
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
    }
}

private struct DateWidget: View {
    let options: [String: Double]
    @State private var now = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init(options: [String: Double] = [:]) { self.options = options }

    var body: some View {
        let fontSize = options["fontSize"] ?? 11
        let format = Int(options["format"] ?? 0)
        Text(formatted(now, format: format))
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .onReceive(timer) { now = $0 }
    }

    private func formatted(_ d: Date, format: Int) -> String {
        let f = DateFormatter()
        switch format {
        case 1: f.dateFormat = "MMM d"
        case 2: f.dateFormat = "EEE, MMM d"
        default: f.dateFormat = "EEE, d"
        }
        return f.string(from: d)
    }
}

private struct GreetingWidget: View {
    let options: [String: Double]
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    init(options: [String: Double] = [:]) { self.options = options }
    var body: some View {
        let username = (NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName()).capitalized
        let hour = Calendar.current.component(.hour, from: now)
        let phrase: String = {
            switch hour {
            case 5..<12:  return "Good morning"
            case 12..<17: return "Good afternoon"
            case 17..<22: return "Good evening"
            default:      return "Good night"
            }
        }()
        let fontSize = options["fontSize"] ?? 13
        Text("\(phrase), \(username)")
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onReceive(timer) { now = $0 }
    }
}

private struct SystemPulseWidget: View {
    @ObservedObject var monitor = SystemMonitor.shared
    let options: [String: Double]
    init(options: [String: Double] = [:]) { self.options = options }
    var body: some View {

        let style = Int(options["style"] ?? 0)
        let labelSize = options["fontSize"] ?? 9
        switch style {
        case 1: donutLayout(labelSize: labelSize)
        case 2: gaugeLayout(labelSize: labelSize)
        default: barLayout(labelSize: labelSize)
        }
    }

    @ViewBuilder
    private func barLayout(labelSize: Double) -> some View {
        let barHeight = CGFloat(options["barHeight"] ?? 4)
        VStack(alignment: .leading, spacing: 6) {
            barRow(label: "CPU", value: monitor.cpuUsage, tint: tintForCPU(monitor.cpuUsage), labelSize: labelSize, barHeight: barHeight)
            barRow(label: "RAM", value: monitor.memUsage, tint: tintForRAM(monitor.memUsage), labelSize: labelSize, barHeight: barHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func barRow(label: String, value: Double, tint: Color, labelSize: Double, barHeight: CGFloat) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 22, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule().fill(tint)
                        .frame(width: max(2, proxy.size.width * value))
                }
            }
            .frame(height: barHeight)
            Text("\(Int(value * 100))%")
                .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 30, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func donutLayout(labelSize: Double) -> some View {
        let size = CGFloat(options["ringSize"] ?? 36)
        HStack(spacing: 18) {
            donut(label: "CPU", value: monitor.cpuUsage, tint: tintForCPU(monitor.cpuUsage), size: size, labelSize: labelSize)
            donut(label: "RAM", value: monitor.memUsage, tint: tintForRAM(monitor.memUsage), size: size, labelSize: labelSize)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func donut(label: String, value: Double, tint: Color, size: CGFloat, labelSize: Double) -> some View {
        let lineWidth = max(3, size / 8)
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: max(0.001, value))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value * 100))")
                    .font(.system(size: max(8, labelSize + 1), weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            Text(label)
                .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    @ViewBuilder
    private func gaugeLayout(labelSize: Double) -> some View {
        let size = CGFloat(options["gaugeSize"] ?? 56)
        HStack(spacing: 20) {
            gauge(label: "CPU", value: monitor.cpuUsage, tint: tintForCPU(monitor.cpuUsage), size: size, labelSize: labelSize)
            gauge(label: "RAM", value: monitor.memUsage, tint: tintForRAM(monitor.memUsage), size: size, labelSize: labelSize)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func gauge(label: String, value: Double, tint: Color, size: CGFloat, labelSize: Double) -> some View {
        let lineWidth = max(3, size / 9)
        VStack(spacing: 2) {
            ZStack(alignment: .bottom) {
                HalfArc(progress: 1).stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                HalfArc(progress: value).stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                Text("\(Int(value * 100))%")
                    .font(.system(size: max(9, labelSize + 1), weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 2)
            }
            .frame(width: size, height: size / 2 + lineWidth)
            Text(label)
                .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func tintForCPU(_ v: Double) -> Color {
        v < 0.5 ? .green : (v < 0.8 ? .yellow : .red)
    }
    private func tintForRAM(_ v: Double) -> Color {
        v < 0.6 ? .cyan : (v < 0.85 ? .orange : .red)
    }
}

private struct HalfArc: Shape {
    var progress: Double
    var animatableData: Double {
        get { progress } set { progress = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width / 2, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let start = Angle.degrees(180)
        let end = Angle.degrees(180 + max(0.001, min(1, progress)) * 180)
        p.addArc(center: center, radius: r, startAngle: start, endAngle: end, clockwise: false)
        return p
    }
}

private struct NextEventWidget: View {
    @ObservedObject var cal: CalendarController
    let options: [String: Double]
    @State private var now = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    init(context: WidgetContext, options: [String: Double] = [:]) {
        self.cal = context.calendarCtrl
        self.options = options
    }
    var body: some View {
        let fontSize = options["fontSize"] ?? 11
        let upcoming = cal.todayEvents.first { $0.end > now }
        HStack(spacing: 8) {
            if let ev = upcoming {
                Capsule().fill(Color(ev.color)).frame(width: 3, height: fontSize + 4)
                Text(ev.timeLabel)
                    .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(ev.title)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: fontSize - 1, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(cal.todayEvents.isEmpty ? "No events today" : "All done for today")
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(timer) { now = $0 }
    }
}

private struct CalendarWeekWidget: View {
    @ObservedObject var cal: CalendarController
    init(context: WidgetContext) { self.cal = context.calendarCtrl }

    var body: some View {
        if cal.authState == .granted {
            HStack(spacing: 6) {
                ForEach(cal.weekStrip, id: \.date) { day in
                    VStack(spacing: 2) {
                        Text(day.weekday).font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                        Text("\(day.dayOfMonth)")
                            .font(.system(size: 13, weight: day.isToday ? .bold : .regular))
                            .foregroundStyle(day.isToday ? .black : .white)
                            .frame(width: 22, height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 5).fill(day.isToday ? Color.white : Color.clear)
                            )
                    }
                }
            }
        } else {
            CalendarPermissionPrompt(authState: cal.authState, request: cal.requestAccessFromUser)
        }
    }
}

private struct CalendarPermissionPrompt: View {
    let authState: CalendarAuthState
    let request: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            actionButton
                .padding(.top, 2)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04))
        )
    }

    private var title: String {
        authState == .denied ? "Calendar access denied" : "Calendar access needed"
    }

    private var subtitle: String {
        authState == .denied
            ? "Re-enable StupidNotch in System Settings → Privacy → Calendars to load real events."
            : "Grant access so this widget can show real events. We'll only ask when you tap below."
    }

    @ViewBuilder
    private var actionButton: some View {
        if authState == .denied {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else {
            Button("Allow access", action: request)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}

private struct CalendarFullWidget: View {
    @ObservedObject var cal: CalendarController
    let options: [String: Double]
    @State private var focusedDate: Date = Date()
    @State private var hovering = false
    @State private var scrollAccumulator: CGFloat = 0
    @State private var scrollMonitor: Any?
    @State private var now = Date()
    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init(context: WidgetContext, options: [String: Double] = [:]) {
        self.cal = context.calendarCtrl
        self.options = options
    }

    private var compact: Bool { (options["compact"] ?? 0) > 0.5 }
    private var showWeek: Bool { (options["showWeek"] ?? 1) > 0.5 }
    private var showEvents: Bool { (options["showEvents"] ?? 1) > 0.5 }
    private var eventLimit: Int { Int(options["eventLimit"] ?? 4) }
    private var fontScale: CGFloat { CGFloat(options["fontScale"] ?? 1) }

    var body: some View {
        Group {
            if cal.authState == .granted {
                grantedBody
            } else {
                CalendarPermissionPrompt(authState: cal.authState, request: cal.requestAccessFromUser)
            }
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 60 : 120)
        .onAppear { installScrollMonitor() }
        .onDisappear {
            if let m = scrollMonitor { NSEvent.removeMonitor(m); scrollMonitor = nil }
        }
    }

    @ViewBuilder
    private var grantedBody: some View {
        if compact {
            HStack(alignment: .top, spacing: 12) {
                if showWeek { todayCard }
                if showEvents { eventsList }
            }
        } else {

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 14) {
                    if showWeek {
                        datesStrip
                            .onContinuousHover { phase in
                                switch phase {
                                case .active: hovering = true
                                case .ended: hovering = false
                                }
                            }
                    }
                    if showEvents { eventsList }
                }
                Spacer(minLength: 0)
            }
            .onReceive(clock) { now = $0 }
        }
    }

    private var todayCard: some View {
        let d = focusedDate
        return VStack(spacing: 1) {
            Text(monthFmt.string(from: d).uppercased())
                .font(.system(size: 9 * fontScale, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            Text(dayFmt.string(from: d))
                .font(.system(size: 22 * fontScale, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(weekdayFmt.string(from: d).uppercased())
                .font(.system(size: 9 * fontScale, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.vertical, 6)
        .frame(width: 54)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard hovering else { return event }
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            let delta = abs(dx) > abs(dy) ? dx : -dy
            scrollAccumulator += delta
            if abs(scrollAccumulator) >= 8 {
                let step = scrollAccumulator > 0 ? 1 : -1
                scrollAccumulator = 0
                let cal = Calendar.current
                if let next = cal.date(byAdding: .day, value: step, to: focusedDate) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        focusedDate = next
                    }
                }
                return nil
            }
            return event
        }
    }

    private let weekdayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    private let monthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f
    }()
    private let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()

    private var datesStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(-180..<181, id: \.self) { offset in
                        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                        dateCard(for: date, isFocused: Calendar.current.isDate(date, inSameDayAs: focusedDate))
                            .id(offset)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                    focusedDate = date
                                }
                            }
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(width: 180)
            .onAppear { proxy.scrollTo(0, anchor: .center) }
            .onChange(of: focusedDate) { _, _ in
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(currentOffset(), anchor: .center)
                }
            }
        }
    }

    private func currentOffset() -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                  to: cal.startOfDay(for: focusedDate)).day ?? 0
    }

    @ViewBuilder
    private func dateCard(for date: Date, isFocused: Bool) -> some View {
        let bg = isFocused ? Color.white.opacity(0.10) : Color.white.opacity(0.03)
        VStack(spacing: 1) {
            Text(monthFmt.string(from: date).uppercased())
                .font(.system(size: isFocused ? 8 : 7, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(isFocused ? 0.55 : 0.35))
            Text(dayFmt.string(from: date))
                .font(.system(size: isFocused ? 22 : 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(isFocused ? 1 : 0.55))
            Text(weekdayFmt.string(from: date).uppercased())
                .font(.system(size: isFocused ? 8 : 7, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(isFocused ? 0.55 : 0.35))
        }
        .padding(.vertical, isFocused ? 6 : 4)
        .frame(width: isFocused ? 56 : 40)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.white.opacity(isFocused ? 0.12 : 0.06), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }

    private var todayDate: Date { Date() }

    private var dateCard: some View {
        let monthFmt = DateFormatter(); monthFmt.dateFormat = "MMM"
        let weekdayFmt = DateFormatter(); weekdayFmt.dateFormat = "EEE"
        let dayFmt = DateFormatter(); dayFmt.dateFormat = "d"
        return VStack(spacing: 1) {
            Text(monthFmt.string(from: todayDate).uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 6)
            Text(dayFmt.string(from: todayDate))
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(weekdayFmt.string(from: todayDate).uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 6)
        }
        .frame(width: 68)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var focusedEvents: [CalendarEvent] { cal.events(for: focusedDate) }

    @ViewBuilder
    private var eventsList: some View {
        if focusedEvents.isEmpty {

            HStack(spacing: 8) {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Your day is clear")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("No events scheduled")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(width: 300 * fontScale, alignment: .leading)
        } else {

            let events = focusedEvents
            let rowH: CGFloat = 26 * fontScale
            let visibleRows = max(1, min(eventLimit, events.count))
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(events) { ev in
                            eventRow(ev, height: rowH).id(ev.id)
                        }
                    }
                }
                .frame(width: 300 * fontScale, height: rowH * CGFloat(visibleRows))
                .onAppear { scrollToNow(proxy, events) }
                .onChange(of: now) { _, _ in scrollToNow(proxy, events) }
                .onChange(of: focusedDate) { _, _ in scrollToNow(proxy, events) }
            }
        }
    }

    private func eventRow(_ ev: CalendarEvent, height: CGFloat) -> some View {

        let isToday = Calendar.current.isDateInToday(focusedDate)
        let past = isToday && ev.end < now
        let ongoing = isToday && ev.start <= now && ev.end > now
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(ev.timeLabel)
                .font(.system(size: 10 * fontScale, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(past ? 0.3 : 0.5))
                .frame(width: 36 * fontScale, alignment: .leading)
            Rectangle().fill(Color(ev.color))
                .frame(width: ongoing ? 3 : 2, height: 12 * fontScale)
                .clipShape(Capsule())
                .opacity(past ? 0.4 : 1)
            Text(ev.title)
                .font(.system(size: 12 * fontScale, weight: ongoing ? .semibold : .regular))
                .foregroundStyle(.white.opacity(past ? 0.4 : 0.9))
                .strikethrough(past, color: .white.opacity(0.3))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(height: height)
    }

    private func scrollToNow(_ proxy: ScrollViewProxy, _ events: [CalendarEvent]) {
        guard Calendar.current.isDateInToday(focusedDate) else {
            if let first = events.first { proxy.scrollTo(first.id, anchor: .top) }
            return
        }
        let target = events.first(where: { $0.end > now }) ?? events.last
        guard let target else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(target.id, anchor: .top)
        }
    }
}

private struct HorizontalScrollWheelCatcher: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = ScrollHookView()
        v.onScroll = onScroll
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ScrollHookView)?.onScroll = onScroll
    }

    final class ScrollHookView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        private var accumulator: CGFloat = 0
        private let threshold: CGFloat = 8

        override func scrollWheel(with event: NSEvent) {

            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            let delta = abs(dx) > abs(dy) ? dx : -dy
            accumulator += delta
            if abs(accumulator) >= threshold {
                onScroll?(accumulator > 0 ? 1 : -1)
                accumulator = 0
            }
        }
    }
}

private struct MediaCompactWidget: View {
    let context: WidgetContext
    @ObservedObject var media: MediaController

    init(context: WidgetContext) {
        self.context = context
        self.media = context.media
    }

    var body: some View {
        if let item = media.nowPlaying {
            HStack(spacing: 10) {
                Group {
                    if let img = item.artwork {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(colors: [.purple.opacity(0.55), .indigo.opacity(0.45)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white).lineLimit(1)
                    Text(item.artist).font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                }
                Spacer()
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
            .onTapGesture { context.controller.openCurrentMediaApp() }
        }
    }
}

private struct CalendarEventsWidget: View {
    @ObservedObject var cal: CalendarController
    init(context: WidgetContext) { self.cal = context.calendarCtrl }

    var body: some View {
        if cal.authState != .granted {
            CalendarPermissionPrompt(authState: cal.authState, request: cal.requestAccessFromUser)
        } else {
            grantedBody
        }
    }

    private var grantedBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            if cal.todayEvents.isEmpty {
                Text("Nothing on the calendar today").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            } else {
                ForEach(cal.todayEvents.prefix(4)) { ev in
                    HStack(spacing: 6) {
                        Circle().fill(Color(ev.color)).frame(width: 6, height: 6)
                        Text(ev.title).font(.system(size: 11)).foregroundStyle(.white).lineLimit(1)
                        Spacer()
                        Text(ev.timeLabel).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
