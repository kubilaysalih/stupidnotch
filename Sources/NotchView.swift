import SwiftUI

struct NotchContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct NotchRootView: View {
    @ObservedObject var controller: NotchController
    @ObservedObject var settings: AppSettings
    @ObservedObject var media: MediaController
    @ObservedObject var tray: TrayController
    @ObservedObject var clipboard: ClipboardController
    @ObservedObject var calendarCtrl: CalendarController
    @ObservedObject var battery: BatteryController
    @ObservedObject var notifications: NotificationController

    init(controller: NotchController) {
        self.controller = controller
        self.settings = controller.settings
        self.media = controller.media
        self.tray = controller.tray
        self.clipboard = controller.clipboard
        self.calendarCtrl = controller.calendar
        self.battery = controller.battery
        self.notifications = controller.notifications
    }

    @State private var dropTargeting = false

    @Namespace private var artworkAnimation

    private var expansionAnimation: Animation {
        if controller.isExpanded {

            let damping = 1.0 - max(0, min(1, settings.expandOvershoot)) * 0.45
            return .spring(response: settings.expandDuration, dampingFraction: damping)
        } else {

            return .spring(response: settings.collapseDuration, dampingFraction: 0.95)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {

            Color.clear

            if controller.isExpanded {
                expandedContent
                    .padding(.horizontal, 0)
                    .padding(.bottom, 12)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.985, anchor: .top))
                        )
                    )
            } else {
                collapsedContent
                    .transition(.opacity.animation(.easeInOut(duration: 0.18)))
            }

            if !controller.isExpanded, shouldShowPeekStrip {
                sneakPeekStrip
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.animation(.easeOut(duration: 0.32))
                    ))
            }

            if let notif = notifications.current, controller.isExpanded {

                VStack {
                    Spacer()
                    notificationBanner(notif)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 6)
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    )
                )
                .animation(.spring(response: 0.42, dampingFraction: 0.72), value: notifications.current)
            }

        }

        .transaction { txn in txn.animation = nil }
        .overlay(alignment: .bottom) {
            if settings.debugSizeHUD, controller.isExpanded {
                Text("h=\(Int(controller.contentHeight))  ·  tab=\(activeTab?.name ?? "—")")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.yellow.opacity(0.9))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Capsule())
                    .padding(.bottom, 4)
            }
        }

    }

    @ViewBuilder
    private var collapsedContent: some View {

        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: NotchGeometry.baseNotchHeight)
    }

    @ViewBuilder
    private var expandedContent: some View {
        let reserve = NotchGeometry.baseNotchHeight + 4
        let screen = NSScreen.builtInWithNotch ?? NSScreen.main
        let bodyWidth = screen.map {
            NotchGeometry.expandedBodyWidth(
                for: $0,
                contentWidth: controller.contentWidth,
                headerLeftMeasured: controller.headerLeftMeasured,
                headerRightMeasured: controller.headerRightMeasured
            )
        } ?? CGFloat(settings.expandedPanelWidth)

        VStack(spacing: 0) {
            Color.clear.frame(height: reserve)
            content
                .padding(.horizontal, 14)
                .padding(.top, 4)
        }
        .frame(width: bodyWidth)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var notchAlignedHeader: some View {
        let notchWidth = NotchGeometry.baseNotchWidth
        let notchHeight = NotchGeometry.baseNotchHeight
        let ctx = WidgetContext(controller: controller, artworkNamespace: artworkAnimation)
        return HStack(spacing: 0) {

            HStack(spacing: 4) {
                ForEach(settings.layout.expandedHeaderLeft) { slot in
                    WidgetView(kind: slot.kind, context: ctx, options: slot.options)
                        .modifier(HeaderSlotSizeModifier(slot: slot))
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear.frame(width: notchWidth, height: notchHeight)

            HStack(spacing: 6) {
                ForEach(settings.layout.expandedHeaderRight) { slot in
                    WidgetView(kind: slot.kind, context: ctx, options: slot.options)
                        .modifier(HeaderSlotSizeModifier(slot: slot))
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: notchHeight + 4)
    }

    private var availableTabs: [TabConfig] { settings.layout.tabs }

    private var activeTab: TabConfig? {
        availableTabs.first(where: { $0.id == controller.currentTabID })
            ?? availableTabs.first
    }

    private func reportHeight(_ h: CGFloat, tabID: UUID, tag: String) {
        DispatchQueue.main.async {
            controller.reportRenderedContentHeight(h, tabID: tabID, tag: tag)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let tab = activeTab {
            LayoutNodeView(
                node: tab.root,
                context: WidgetContext(controller: controller, artworkNamespace: artworkAnimation)
            )
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .overlay(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { reportHeight(proxy.size.height, tabID: tab.id, tag: "appear") }
                        .onChange(of: proxy.size.height) { _, new in
                            reportHeight(new, tabID: tab.id, tag: "change")
                        }
                }
            )

        } else {
            EmptyTabPlaceholder(
                icon: "square.dashed",
                title: "No tabs configured",
                subtitle: "Add a tab in Settings → Layout."
            )
        }
    }

    private var shouldShowPeekStrip: Bool {
        if controller.sneakPeek != nil { return true }
        return settings.layout.peekLeftSlots.contains(where: { peekSlotHasContent($0.kind) })
            || settings.layout.peekRightSlots.contains(where: { peekSlotHasContent($0.kind) })
    }

    private func peekSlotHasContent(_ kind: WidgetKind?) -> Bool {
        guard let kind else { return false }
        if kind.requiresMedia { return media.nowPlaying != nil }
        if kind.requiresTrayItems { return !controller.tray.items.isEmpty }
        return true
    }

    private var peekActive: Bool {
        !controller.isExpanded && shouldShowPeekStrip
    }

    private var currentCornerRadius: CGFloat {
        if controller.isExpanded { return NotchGeometry.cornerRadius }
        return NotchGeometry.baseNotchHeight / 2
    }

    private var sneakPeekStrip: some View {
        let notchWidth = NotchGeometry.baseNotchWidth
        let notchHeight = NotchGeometry.baseNotchHeight
        let cornerInset = NotchGeometry.cornerRadius + 2
        return HStack(spacing: 0) {

            HStack(spacing: 0) {
                peekLeading
                Spacer(minLength: 0)
            }
            .padding(.leading, cornerInset)
            .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear.frame(width: notchWidth, height: notchHeight)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                peekTrailing
            }
            .padding(.trailing, cornerInset)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: notchHeight)
    }

    @ViewBuilder
    private var peekLeading: some View {
        let ctx = WidgetContext(controller: controller, artworkNamespace: artworkAnimation)
        HStack(spacing: 4) {
            ForEach(settings.layout.peekLeftSlots) { slot in
                WidgetView(kind: slot.kind, context: ctx, options: slot.options)
                    .modifier(HeaderSlotSizeModifier(slot: slot))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { reportPeekLeft(proxy.size.width) }
                    .onChange(of: proxy.size.width) { _, new in reportPeekLeft(new) }
            }
        )
    }

    @ViewBuilder
    private var peekTrailing: some View {
        let ctx = WidgetContext(controller: controller, artworkNamespace: artworkAnimation)
        HStack(spacing: 4) {
            ForEach(settings.layout.peekRightSlots) { slot in
                WidgetView(kind: slot.kind, context: ctx, options: slot.options)
                    .modifier(HeaderSlotSizeModifier(slot: slot))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { reportPeekRight(proxy.size.width) }
                    .onChange(of: proxy.size.width) { _, new in reportPeekRight(new) }
            }
        )
    }

    private func reportPeekLeft(_ w: CGFloat) {
        DispatchQueue.main.async {
            if abs(controller.peekLeftMeasured - w) >= 1 { controller.peekLeftMeasured = w }
        }
    }
    private func reportPeekRight(_ w: CGFloat) {
        DispatchQueue.main.async {
            if abs(controller.peekRightMeasured - w) >= 1 { controller.peekRightMeasured = w }
        }
    }

    private func notificationBanner(_ n: InAppNotification) -> some View {
        HStack(spacing: 10) {
            if let icon = n.icon {
                Image(nsImage: icon).resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.1))
                    Image(systemName: "bell.fill").font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                }
                .frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(n.title).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white).lineLimit(1)
                Text(n.body).font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.7)).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.85))
        )
    }
}

struct BatteryPill: View {
    let percent: Double
    let icon: String
    let charging: Bool
    var showPercent: Bool = true
    var tint: Color? = nil

    var iconSize: CGFloat = 11

    var body: some View {
        HStack(spacing: max(2, iconSize * 0.3)) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(tint ?? color)
            if showPercent {
                Text("\(Int(percent))%")
                    .font(.system(size: iconSize * 0.95, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint ?? .white.opacity(0.85))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, max(4, iconSize * 0.5))
        .padding(.vertical, max(2, iconSize * 0.25))
        .fixedSize(horizontal: true, vertical: false)
        .background(
            Capsule().fill(Color.white.opacity(0.06))
        )
    }

    private var color: Color {
        if charging { return .green }
        if percent <= 15 { return .red }
        if percent <= 25 { return .orange }
        return .white.opacity(0.7)
    }
}

struct NotchHeaderRootView: View {
    @ObservedObject var controller: NotchController
    @ObservedObject var settings: AppSettings

    init(controller: NotchController) {
        self.controller = controller
        self.settings = controller.settings
    }

    var body: some View {
        let notchWidth = NotchGeometry.baseNotchWidth
        let notchHeight = NotchGeometry.baseNotchHeight
        let screen = NSScreen.builtInWithNotch ?? NSScreen.main
        let bodyWidth = screen.map {
            NotchGeometry.expandedBodyWidth(
                for: $0,
                contentWidth: controller.contentWidth,
                headerLeftMeasured: controller.headerLeftMeasured,
                headerRightMeasured: controller.headerRightMeasured
            )
        } ?? CGFloat(settings.expandedPanelWidth)
        let ctx = WidgetContext(controller: controller, artworkNamespace: nil)
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(settings.layout.expandedHeaderLeft) { slot in
                    WidgetView(kind: slot.kind, context: ctx, options: slot.options)
                        .modifier(HeaderSlotSizeModifier(slot: slot))
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { reportHeaderLeft(proxy.size.width) }
                        .onChange(of: proxy.size.width) { _, new in reportHeaderLeft(new) }
                }
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear.frame(width: notchWidth, height: notchHeight)

            HStack(spacing: 6) {
                ForEach(settings.layout.expandedHeaderRight) { slot in
                    WidgetView(kind: slot.kind, context: ctx, options: slot.options)
                        .modifier(HeaderSlotSizeModifier(slot: slot))
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 12)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { reportHeaderRight(proxy.size.width) }
                        .onChange(of: proxy.size.width) { _, new in reportHeaderRight(new) }
                }
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: bodyWidth)
        .frame(maxWidth: .infinity)
        .frame(height: notchHeight + 4)
    }

    private func reportHeaderLeft(_ w: CGFloat) {
        DispatchQueue.main.async {
            if abs(controller.headerLeftMeasured - w) >= 1 { controller.headerLeftMeasured = w }
        }
    }
    private func reportHeaderRight(_ w: CGFloat) {
        DispatchQueue.main.async {
            if abs(controller.headerRightMeasured - w) >= 1 { controller.headerRightMeasured = w }
        }
    }
}

private struct HeaderSlotSizeModifier: ViewModifier {
    let slot: HeaderSlot
    func body(content: Content) -> some View {
        var view: AnyView = AnyView(content)
        if let w = slot.customWidth {
            view = slot.widthUnit == .points
                ? AnyView(view.frame(width: w))
                : AnyView(view.containerRelativeFrame(.horizontal) { v, _ in v * max(0, min(1, w / 100)) })
        }
        if let h = slot.customHeight {
            view = slot.heightUnit == .points
                ? AnyView(view.frame(height: h))
                : AnyView(view.containerRelativeFrame(.vertical) { v, _ in v * max(0, min(1, h / 100)) })
        }
        return view
    }
}

struct NotchHeaderButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    var iconSize: CGFloat = 13
    var tint: Color? = nil
    @State private var hovering = false

    var body: some View {
        let cellW = max(24, iconSize + 17)
        let cellH = max(20, iconSize + 13)
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(background)
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(tint ?? foreground)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: cellW, height: cellH)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }

        .animation(.easeOut(duration: 0.12), value: hovering)

    }

    private var background: Color {
        if isSelected { return Color.white.opacity(0.16) }
        if hovering { return Color.white.opacity(0.08) }
        return Color.clear
    }

    private var foreground: Color {
        if isSelected { return Color.white }
        if hovering { return Color.white.opacity(0.85) }
        return Color.white.opacity(0.55)
    }
}

struct VisualizerBars: View {
    let active: Bool
    var alignment: VisualizerAlignment = .centered
    var barCount: Int = 4
    var barWidth: CGFloat = 4
    var barSpacing: CGFloat = 2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let n = max(1, barCount)
                let totalSpacing = barSpacing * CGFloat(n - 1)

                let groupWidth = barWidth * CGFloat(n) + totalSpacing
                let originX = max(0, (size.width - groupWidth) / 2)
                let restHeight = size.height * 0.2
                for i in 0..<n {
                    let h: CGFloat
                    if active {
                        let phase = t * 6 + Double(i) * 1.3
                        h = CGFloat((sin(phase) * 0.5 + 0.5)) * size.height * 0.85 + size.height * 0.15
                    } else {
                        h = restHeight
                    }
                    let y: CGFloat
                    switch alignment {
                    case .centered: y = (size.height - h) / 2
                    case .bottom:   y = size.height - h
                    }
                    let rect = CGRect(
                        x: originX + CGFloat(i) * (barWidth + barSpacing),
                        y: y,
                        width: barWidth,
                        height: h
                    )
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(.white.opacity(active ? 0.85 : 0.35))
                    )
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: active)
    }
}

struct HomeTab: View {
    @ObservedObject var media: MediaController
    let controller: NotchController
    let artworkNamespace: Namespace.ID

    let options: [String: Double]

    init(controller: NotchController, artworkNamespace: Namespace.ID, options: [String: Double] = [:]) {
        self.controller = controller
        self.media = controller.media
        self.artworkNamespace = artworkNamespace
        self.options = options
    }

    private func flag(_ key: String, default def: Double = 1) -> Bool {
        (options[key] ?? def) > 0.5
    }

    var body: some View {
        if let np = media.nowPlaying {
            playing(np)
        } else {
            EmptyTabPlaceholder(icon: "music.note",
                                 title: "Nothing playing",
                                 subtitle: "Start playback in Spotify, Music, or any media app.")
        }
    }

    private func playing(_ item: MediaItem) -> some View {
        let showArtwork = flag("showArtwork")
        let showTitle = flag("showTitle")
        let showArtist = flag("showArtist")
        let showProgress = flag("showProgress")
        let showTimes = flag("showTimes")
        let showControls = flag("showControls")
        let showVisualizer = flag("showVisualizer")
        let artworkSize: CGFloat = CGFloat(options["artworkSize"] ?? 72)
        return HStack(spacing: 12) {
            if showArtwork {
                artwork(item)
                    .frame(width: artworkSize, height: artworkSize)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                if showTitle {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if showArtist, !item.artist.isEmpty {
                    Text(item.artist)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if showProgress {
                    MediaProgress(elapsed: media.elapsed, duration: item.duration)
                        .frame(height: 3)
                        .padding(.top, 2)
                }
                if showTimes {
                    HStack {
                        Text(timeString(media.elapsed))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text("-" + timeString(max(0, item.duration - media.elapsed)))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                if showControls { controls }
            }
            Spacer(minLength: 0)
            if showVisualizer {
                VisualizerBars(
                    active: media.isPlaying,
                    alignment: VisualizerAlignment(rawValue: controller.settings.visualizerAlignment) ?? .centered,
                    barCount: max(1, controller.settings.visualizerBarCount),
                    barWidth: controller.settings.visualizerBarWidth,
                    barSpacing: controller.settings.visualizerBarSpacing
                )
                .frame(width: 36, height: 40)
                .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func artwork(_ item: MediaItem) -> some View {
        Group {
            if let img = item.artwork {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.purple.opacity(0.5), Color.indigo.opacity(0.4), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 4) {
            MediaButton(icon: "backward.fill", size: 11) { media.previous() }
            MediaButton(icon: media.isPlaying ? "pause.fill" : "play.fill", size: 14, emphasized: true) { media.togglePlay() }
            MediaButton(icon: "forward.fill", size: 11) { media.next() }
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct MediaButton: View {
    let icon: String
    var size: CGFloat = 13
    var emphasized: Bool = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(bg)
                Image(systemName: icon)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: emphasized ? 30 : 26, height: 22)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private var bg: Color {
        if emphasized { return Color.white.opacity(hovering ? 0.22 : 0.16) }
        return Color.white.opacity(hovering ? 0.14 : 0.08)
    }
}

struct MediaProgress: View {
    let elapsed: TimeInterval
    let duration: TimeInterval

    var body: some View {
        GeometryReader { geo in
            let frac = duration > 0 ? min(1.0, max(0.0, elapsed / duration)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule().fill(Color.white.opacity(0.9)).frame(width: geo.size.width * CGFloat(frac))
            }
        }
    }
}

struct EmptyTabPlaceholder: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(Color.white.opacity(0.06)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(.white.opacity(0.55))
            }
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04))
        )
    }
}

struct TrayTab: View {
    @ObservedObject var tray: TrayController
    let controller: NotchController

    init(controller: NotchController) {
        self.controller = controller
        self.tray = controller.tray
    }

    var body: some View {

        dropField
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04))
            )
    }

    @ViewBuilder
    private var dropField: some View {
        let highlighted = controller.dragOver
        Group {
            if tray.items.isEmpty {
                emptyTrayHint(highlighted: highlighted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tray.items) { item in
                            TrayFileTile(item: item) { tray.remove(item) }
                                .onDrag { NSItemProvider(object: item.url as NSURL) }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, 2)

                .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(highlighted ? 0.12 : 0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(highlighted ? 0.8 : 0), lineWidth: 2)
                )
            }
        }

    }

    private func emptyTrayHint(highlighted: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 18))
                .foregroundStyle(highlighted ? Color.accentColor : .white.opacity(0.45))
            VStack(alignment: .leading, spacing: 2) {
                Text("Drop files here").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Text("From Finder or any app — the notch grabs them.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(highlighted ? 0.15 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    highlighted ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.15),
                    style: StrokeStyle(lineWidth: highlighted ? 2 : 1, dash: highlighted ? [] : [5, 4])
                )
        )
    }

}

struct TrayFileTile: View {
    let item: TrayItem
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    if let img = item.thumbnail {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).padding(4)
                    } else {
                        Image(systemName: "doc.fill").font(.system(size: 26)).foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 54, height: 54)
                Text(item.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: 74)
            }
            .padding(.vertical, 6)
            .frame(width: 84, height: 84)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(hovering ? 0.1 : 0.06))
            )

            if hovering {
                Button(action: onRemove) {
                    ZStack {
                        Circle().fill(Color.black.opacity(0.7))
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .padding(4)
                .transition(.opacity)
            }
        }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

struct ClipboardTab: View {
    @ObservedObject var clipboard: ClipboardController
    let controller: NotchController

    init(controller: NotchController) {
        self.controller = controller
        self.clipboard = controller.clipboard
    }

    var body: some View {
        if clipboard.items.isEmpty {
            EmptyTabPlaceholder(
                icon: "doc.on.clipboard",
                title: "Clipboard history is empty",
                subtitle: "Copy text or images and they'll appear here."
            )
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(clipboard.items) { item in
                        ClipboardTile(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                clipboard.copyToPasteboard(item)
                                controller.notifications.post(
                                    title: "Copied to clipboard",
                                    body: previewText(for: item)
                                )
                            }
                            .onDrag { makeItemProvider(for: item) }
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: 76)
            .clipped()
        }
    }

    private func previewText(for item: ClipboardItem) -> String {
        switch item.kind {
        case .text(let s):
            let single = s.replacingOccurrences(of: "\n", with: " ")
            return single.count > 80 ? String(single.prefix(80)) + "…" : single
        case .image: return "Image"
        }
    }

    private func makeItemProvider(for item: ClipboardItem) -> NSItemProvider {
        switch item.kind {
        case .text(let s):
            return NSItemProvider(object: s as NSString)
        case .image(let img):

            if let tmp = writeImageToTempFile(img) {
                return NSItemProvider(contentsOf: tmp) ?? NSItemProvider(object: img)
            }
            return NSItemProvider(object: img)
        }
    }

    private func writeImageToTempFile(_ img: NSImage) -> URL? {
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clip-\(UUID().uuidString).png")
        do { try png.write(to: url); return url } catch { return nil }
    }
}

struct ClipboardTile: View {
    let item: ClipboardItem
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(spacing: 4) {
                Image(systemName: kindIcon)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer(minLength: 0)
                Text(timeLabel)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 6)
            .frame(height: 14)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
        }
        .frame(width: 124, height: 74, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(hovering ? 0.12 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text(let str):
            Text(str)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(3)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        case .image(let img):
            GeometryReader { proxy in
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
        }
    }

    private var kindIcon: String {
        switch item.kind {
        case .text: return "textformat"
        case .image: return "photo"
        }
    }

    private var kindLabel: String {
        switch item.kind {
        case .text: return "Text"
        case .image: return "Image"
        }
    }

    private var timeLabel: String {
        let now = Date()
        let s = Int(now.timeIntervalSince(item.timestamp))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s/60)m" }
        return "\(s/3600)h"
    }
}

struct CalendarTab: View {
    @ObservedObject var calendarCtrl: CalendarController
    let controller: NotchController

    init(controller: NotchController) {
        self.controller = controller
        self.calendarCtrl = controller.calendar
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(calendarCtrl.monthLabel.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 6) {
                    ForEach(calendarCtrl.weekStrip, id: \.date) { day in
                        VStack(spacing: 2) {
                            Text(day.weekday).font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                            Text("\(day.dayOfMonth)")
                                .font(.system(size: 13, weight: day.isToday ? .bold : .regular))
                                .foregroundStyle(day.isToday ? .black : .white)
                                .frame(width: 24, height: 22)
                                .background(
                                    RoundedRectangle(cornerRadius: 5).fill(day.isToday ? Color.white : Color.clear)
                                )
                        }
                    }
                }
            }

            Divider().overlay(Color.white.opacity(0.12))

            VStack(alignment: .leading, spacing: 4) {
                if calendarCtrl.todayEvents.isEmpty {
                    Text("Nothing on the calendar today").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                } else {
                    ForEach(calendarCtrl.todayEvents.prefix(4)) { ev in
                        HStack(spacing: 6) {
                            Circle().fill(Color(ev.color)).frame(width: 6, height: 6)
                            Text(ev.title).font(.system(size: 11)).foregroundStyle(.white).lineLimit(1)
                            Spacer()
                            Text(ev.timeLabel).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
