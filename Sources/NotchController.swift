import Cocoa
import SwiftUI
import Combine

@MainActor
final class NotchController: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var currentTabID: UUID = UUID()

    @Published var pinnedFromSettings: Bool = false
    @Published var sneakPeek: SneakPeekModel? = nil
    @Published var liveActivity: LiveActivityModel? = nil
    @Published var dragOver: Bool = false

    @Published var contentHeight: CGFloat = 0

    @Published var contentWidth: CGFloat = 0

    @Published var peekLeftMeasured: CGFloat = 0
    @Published var peekRightMeasured: CGFloat = 0

    @Published var headerLeftMeasured: CGFloat = 0
    @Published var headerRightMeasured: CGFloat = 0

    private var window: NotchWindow?

    private var headerHostView: NSHostingView<NotchHeaderRootView>?
    private static let layerNoopActions: [String: CAAction] = [
        "opacity": NSNull(),
        "bounds": NSNull(),
        "position": NSNull(),
        "transform": NSNull(),
        "contents": NSNull(),
        "sublayers": NSNull(),
        "hidden": NSNull()
    ]
    private var trackingArea: NSTrackingArea?
    private var contentView: HoverTrackingView?
    private var sneakDismissWork: DispatchWorkItem?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var clickOutsideMonitor: Any?
    private var hoverDebounce: DispatchWorkItem?

    private var scrollAccumulator: CGFloat = 0
    private var scrollAccumulatorTimer: Timer?
    private var scrollCooldownUntil: Date = .distantPast

    let settings: AppSettings
    let media: MediaController
    let tray: TrayController
    let clipboard: ClipboardController
    let calendar: CalendarController
    let battery: BatteryController
    let notifications: NotificationController
    let liveActivities: LiveActivityController
    let hotkeys: HotkeyController

    static let mediaWidgetKinds: Set<WidgetKind> = [
        .mediaPlayer, .mediaCompact, .mediaArtwork,
        .nowPlayingText, .mediaProgress, .mediaControls,
        .visualizerBars
    ]

    init(settings: AppSettings) {
        self.settings = settings
        self.media = MediaController()
        self.tray = TrayController()
        self.clipboard = ClipboardController(historySize: settings.clipboardHistorySize)
        self.calendar = CalendarController()
        self.battery = BatteryController()
        self.notifications = NotificationController()
        self.liveActivities = LiveActivityController()
        self.hotkeys = HotkeyController()

        bindSettings()
    }

    func start() {
        guard settings.notchEnabled else { return }

        if !settings.layout.tabs.contains(where: { $0.id == currentTabID }),
           let firstID = settings.layout.tabs.first?.id {
            currentTabID = firstID
        }
        rebuildWindow()
        applyDebugForcedState()

        DispatchQueue.main.async { [weak self] in self?.measureContentHeight() }

        if settings.layout.usesAny(of: NotchController.mediaWidgetKinds) {
            media.start()
        }

        clipboard.start()
        battery.start()

        if settings.layout.usesAny(of: [.calendar, .calendarWeek, .calendarEvents]) {
            calendar.start()
        }

        notifications.start()
        liveActivities.start(media: media)
        hotkeys.register(settings: settings, onToggleNotch: { [weak self] in
            self?.toggleExpanded()
        }, onSneakPeek: { [weak self] in
            self?.triggerSneakPeekFromMedia()
        }, onShowClipboard: { [weak self] in
            self?.showTabContaining(.clipboardList)
        })

        media.onTrackChange = { [weak self] item in
            guard let self else { return }
            if self.settings.sneakPeekEnabled, let item {
                self.showSneakPeek(SneakPeekModel(title: item.title, subtitle: item.artist))
            } else {
                self.updatePersistentPeek()
            }
            self.liveActivities.update(from: item)
        }

        media.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updatePersistentPeek() }
            .store(in: &settingsCancellables)
        media.$nowPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updatePersistentPeek() }
            .store(in: &settingsCancellables)

        settings.$layout
            .map { layout -> Int in
                var hasher = Hasher()
                hasher.combine(layout.peekLeftSlots)
                hasher.combine(layout.peekRightSlots)
                return hasher.finalize()
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updatePersistentPeek() }
            .store(in: &settingsCancellables)

        Publishers.CombineLatest($peekLeftMeasured, $peekRightMeasured)
            .removeDuplicates(by: { abs($0.0 - $1.0) < 1 && abs($0.1 - $1.1) < 1 })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updatePersistentPeek() }
            .store(in: &settingsCancellables)

        Publishers.CombineLatest($headerLeftMeasured, $headerRightMeasured)
            .removeDuplicates(by: { abs($0.0 - $1.0) < 1 && abs($0.1 - $1.1) < 1 })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] left, right in
                self?.applyCurrentFrame()
            }
            .store(in: &settingsCancellables)

        settings.$debugForceState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyDebugForcedState() }
            .store(in: &settingsCancellables)
        settings.$debugOffsetFromTop
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildWindow() }
            .store(in: &settingsCancellables)

        Publishers.MergeMany([
            settings.$useSystemNotchDimensions.map { _ in () }.eraseToAnyPublisher(),
            settings.$customNotchWidth.map { _ in () }.eraseToAnyPublisher(),
            settings.$customNotchHeight.map { _ in () }.eraseToAnyPublisher(),
            settings.$peekExtraWidth.map { _ in () }.eraseToAnyPublisher(),
            settings.$expandedPanelWidth.map { _ in () }.eraseToAnyPublisher(),
            settings.$notchCornerRadius.map { _ in () }.eraseToAnyPublisher()
        ])
        .dropFirst()
        .throttle(for: .milliseconds(80), scheduler: DispatchQueue.main, latest: true)
        .sink { [weak self] _ in
            guard let self else { return }
            self.applyCurrentFrame()
            self.updateShapeCornerRadius()
        }
        .store(in: &settingsCancellables)

        $isExpanded
            .sink { [weak self] expanded in
                self?.headerHostView?.isHidden = !expanded
            }
        .store(in: &settingsCancellables)

        $currentTabID
            .dropFirst()
            .sink { [weak self] newID in
                guard let self else { return }
                let tab = self.settings.layout.tabs.first(where: { $0.id == newID })
                let cached = self.cachedTabHeights[newID]
                if let cached, cached >= 1, abs(cached - self.contentHeight) >= 1 {
                    withTransaction(Transaction(animation: nil)) {
                        self.contentHeight = cached
                    }
                }

                let newWidth = tab?.root.intrinsicPointsWidth ?? 0
                if abs(newWidth - self.contentWidth) >= 1 {
                    withTransaction(Transaction(animation: nil)) {
                        self.contentWidth = newWidth
                    }
                }
                if self.isExpanded {
                    self.animateFrame(to: true, animated: true)
                }
            }
            .store(in: &settingsCancellables)

        Publishers.MergeMany([
            settings.$layout.map { _ in () }.eraseToAnyPublisher(),
            media.$nowPlaying.map { _ in () }.eraseToAnyPublisher(),
            media.$isPlaying.map { _ in () }.eraseToAnyPublisher(),
            clipboard.$items.map { _ in () }.eraseToAnyPublisher(),
            calendar.$authState.map { _ in () }.eraseToAnyPublisher(),
            calendar.$todayEvents.map { _ in () }.eraseToAnyPublisher(),
            settings.$mediaPlayerShowVisualizer.map { _ in () }.eraseToAnyPublisher()
        ])
        .debounce(for: .milliseconds(80), scheduler: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self else { return }
            let beforeH = self.contentHeight
            let beforeW = self.contentWidth
            self.measureContentHeight()

            let newW = self.activeTabForGeometry?.root.intrinsicPointsWidth ?? 0
            if abs(newW - self.contentWidth) >= 1 {
                withTransaction(Transaction(animation: nil)) {
                    self.contentWidth = newW
                }
            }
            let widthChanged = abs(self.contentWidth - beforeW) >= 1
            let heightChanged = abs(self.contentHeight - beforeH) >= 1
            if self.isExpanded, widthChanged || heightChanged {
                self.animateFrame(to: true, animated: true)
            }
        }
        .store(in: &settingsCancellables)
    }

    func forceExpandForSettings() {
        guard window != nil else {
            return
        }
        pinnedFromSettings = true
        let alreadyExpanded = isExpanded
        isExpanded = true

        animateFrame(to: true, animated: alreadyExpanded)
        updateShapeCornerRadius()
    }

    private var activeTabForGeometry: TabConfig? {
        settings.layout.tabs.first(where: { $0.id == currentTabID }) ?? settings.layout.tabs.first
    }

    func applyCurrentFrame() {
        guard let window, let screen = window.screen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return }
        let size: NSSize
        if pinnedFromSettings || isExpanded {

            size = NotchGeometry.expandedSize(for: screen, contentHeight: contentHeight, contentWidth: contentWidth, headerLeftMeasured: headerLeftMeasured, headerRightMeasured: headerRightMeasured)
            if !isExpanded { isExpanded = true }
        } else if shouldHoldPeek || sneakPeek != nil {
            size = NotchGeometry.peekSize(for: screen, measuredLeft: peekLeftMeasured, measuredRight: peekRightMeasured)
        } else {
            size = NotchGeometry.collapsedSize(for: screen)
        }
        let frame = NSRect(origin: NotchGeometry.origin(for: screen, size: size), size: size)
        window.setFrame(frame, display: true, animate: false)
        updateShapeCornerRadius()
    }

    func stop() {
        window?.orderOut(nil)
        window = nil
        media.stop()
        clipboard.stop()
        notifications.stop()
        liveActivities.stop()
        hotkeys.unregisterAll()
    }

    func rebuildWindow() {
        window?.orderOut(nil)
        window = nil
        tearDownMouseMonitors()
        guard settings.notchEnabled, let screen = NSScreen.builtInWithNotch ?? NSScreen.main else { return }
        let w = NotchWindow(screen: screen)
        let host = NSHostingView(rootView: NotchRootView(controller: self))
        host.translatesAutoresizingMaskIntoConstraints = false

        host.setContentHuggingPriority(.defaultLow, for: .horizontal)
        host.setContentHuggingPriority(.defaultLow, for: .vertical)
        host.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        host.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        if #available(macOS 13.0, *) {
            host.sizingOptions = []
        }

        host.wantsLayer = true
        host.layer?.isOpaque = false
        host.layer?.backgroundColor = NSColor.clear.cgColor

        let noopActions: [String: CAAction] = [
            "opacity": NSNull(),
            "bounds": NSNull(),
            "position": NSNull(),
            "transform": NSNull(),
            "contents": NSNull(),
            "sublayers": NSNull(),
            "hidden": NSNull()
        ]
        host.layer?.actions = noopActions
        let container = HoverTrackingView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        container.layer?.masksToBounds = true
        container.layer?.actions = noopActions
        container.layer?.cornerCurve = .continuous

        container.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        container.onScroll = { [weak self] dx in self?.handleScroll(dx: dx) }

        container.onDragEnter = { [weak self] in
            guard let self else { return }
            self.dragOver = true
            if !self.isExpanded { self.setExpanded(true, animated: true) }
            if let trayTab = self.settings.layout.tabs.first(where: { $0.contains(kind: .tray) }) {
                self.currentTabID = trayTab.id
            }
        }
        container.onDragExit = { [weak self] in
            self?.dragOver = false
        }
        container.onDrop = { [weak self] providers in
            guard let self else { return false }
            self.dragOver = false
            self.tray.handleDrop(providers: providers)
            return true
        }
        container.addSubview(host)
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        let headerHeight: CGFloat = NotchGeometry.baseNotchHeight + 4
        let headerHost = NSHostingView(rootView: NotchHeaderRootView(controller: self))
        headerHost.translatesAutoresizingMaskIntoConstraints = false
        headerHost.wantsLayer = true
        headerHost.layer?.isOpaque = false
        headerHost.layer?.backgroundColor = NSColor.clear.cgColor
        headerHost.layer?.actions = noopActions
        headerHost.unregisterDraggedTypes()
        if #available(macOS 13.0, *) {
            headerHost.sizingOptions = []
        }
        headerHost.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerHost.setContentHuggingPriority(.defaultLow, for: .vertical)
        container.addSubview(headerHost, positioned: .above, relativeTo: host)
        NSLayoutConstraint.activate([
            headerHost.topAnchor.constraint(equalTo: container.topAnchor),
            headerHost.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headerHost.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            headerHost.heightAnchor.constraint(equalToConstant: headerHeight)
        ])
        headerHost.isHidden = !isExpanded
        self.headerHostView = headerHost
        w.contentView = container
        window = w
        contentView = container
        w.positionForScreen(screen, expanded: false)
        w.orderFrontRegardless()
        installMouseMonitors(screen: screen)
        updateShapeCornerRadius()
    }

    private var pendingHeightWork: DispatchWorkItem?

    func reportRenderedContentHeight(_ h: CGFloat, tabID: UUID, tag: String) {
        guard tabID == currentTabID else {
            return
        }
        reportRenderedContentHeight(h)
    }

    func reportRenderedContentHeight(_ h: CGFloat) {
        let rounded = h.rounded()
        guard rounded >= 1 else { return }
        let delta = abs(rounded - contentHeight)
        if delta < 1 { return }
        if delta < 12 {

            pendingHeightWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.applyContentHeight(rounded, reason: "deferred")
            }
            pendingHeightWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09, execute: work)
        } else {

            pendingHeightWork?.cancel()
            pendingHeightWork = nil
            applyContentHeight(rounded, reason: "immediate-tabswitch")
        }
    }

    private func applyContentHeight(_ h: CGFloat, reason: String) {
        if let tab = activeTabForGeometry, h <= 300 {

            cachedTabHeights[tab.id] = h
            saveCachedHeights()
        }
        let delta = abs(h - contentHeight)
        if delta < 1 { return }

        if delta < 8 && contentHeight > 0 {
                return
        }
        withTransaction(Transaction(animation: nil)) {
            contentHeight = h
        }
        if isExpanded {
            animateFrame(to: true, animated: true)
        }
    }

    private var cachedTabHeights: [UUID: CGFloat] = NotchController.loadCachedHeights()

    private static func loadCachedHeights() -> [UUID: CGFloat] {
        let raw = UserDefaults.standard.dictionary(forKey: "stupidnotch.cachedTabHeights") as? [String: Double] ?? [:]
        return raw.reduce(into: [UUID: CGFloat]()) { acc, kv in
            if let id = UUID(uuidString: kv.key) { acc[id] = CGFloat(kv.value) }
        }
    }

    private func saveCachedHeights() {
        let raw = cachedTabHeights.reduce(into: [String: Double]()) { acc, kv in
            acc[kv.key.uuidString] = Double(kv.value)
        }
        UserDefaults.standard.set(raw, forKey: "stupidnotch.cachedTabHeights")
    }

    func primeContentHeightForActiveTab() {
        let tab = activeTabForGeometry
        let cached = tab.flatMap { cachedTabHeights[$0.id] }
        guard let cached, cached >= 1, abs(cached - contentHeight) >= 1 else { return }
        contentHeight = cached
    }

    func measureContentHeight() {

    }

    private static let suppressedLayerActions: [String: CAAction] = [
        "opacity": NSNull(),
        "bounds": NSNull(),
        "position": NSNull(),
        "transform": NSNull(),
        "contents": NSNull(),
        "sublayers": NSNull(),
        "hidden": NSNull(),
        "backgroundColor": NSNull(),
        "cornerRadius": NSNull()
    ]
    private static func suppressAllLayerActions(in layer: CALayer) {
        if layer.actions?["opacity"] is NSNull == false {
            layer.actions = suppressedLayerActions
        }
        layer.sublayers?.forEach(suppressAllLayerActions(in:))
    }

    func updateShapeCornerRadius() {
        guard let layer = contentView?.layer else { return }
        let target: CGFloat = NotchGeometry.cornerRadius
        layer.backgroundColor = NSColor.black.cgColor
        layer.cornerCurve = .continuous
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = layer.cornerRadius
        animation.toValue = target
        animation.duration = 0.32
        animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
        layer.add(animation, forKey: "cornerRadius")
        layer.cornerRadius = target
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }

    private func installMouseMonitors(screen: NSScreen) {
        let handler: (NSEvent) -> Void = { [weak self] _ in self?.evaluateMouseHover(screen: screen) }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.evaluateMouseHover(screen: screen)
            return event
        }

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.evaluateClickOutside(screen: screen)
        }
    }

    private func tearDownMouseMonitors() {
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m); globalMouseMonitor = nil }
        if let m = localMouseMonitor { NSEvent.removeMonitor(m); localMouseMonitor = nil }
        if let m = clickOutsideMonitor { NSEvent.removeMonitor(m); clickOutsideMonitor = nil }
    }

    private func evaluateClickOutside(screen: NSScreen) {
        guard isExpanded, !isDebugForced, !pinnedFromSettings, let window else { return }
        let mouse = NSEvent.mouseLocation
        if !window.frame.contains(mouse) {
            setExpanded(false, animated: true)
        }
    }

    private func evaluateMouseHover(screen: NSScreen) {
        guard settings.notchEnabled, !isDebugForced, !pinnedFromSettings else { return }
        guard window != nil else { return }
        let mouse = NSEvent.mouseLocation

        let collapsedSize = NotchGeometry.collapsedSize(for: screen)
        let hMargin = -CGFloat(settings.hoverMarginHorizontal)
        let vMargin = -CGFloat(settings.hoverMarginVertical)
        var collapsedRect = NSRect(
            origin: NotchGeometry.origin(for: screen, size: collapsedSize),
            size: collapsedSize
        ).insetBy(dx: hMargin, dy: vMargin)

        let expandedSize = NotchGeometry.expandedSize(for: screen, contentHeight: contentHeight, contentWidth: contentWidth, headerLeftMeasured: headerLeftMeasured, headerRightMeasured: headerRightMeasured)
        var expandedRect = NSRect(
            origin: NotchGeometry.origin(for: screen, size: expandedSize),
            size: expandedSize
        ).insetBy(dx: hMargin / 2, dy: vMargin)

        if collapsedRect.maxY < screen.frame.maxY + 4 { collapsedRect.size.height += 6 }
        if expandedRect.maxY < screen.frame.maxY + 4 { expandedRect.size.height += 6 }
        let triggerRect = isExpanded ? expandedRect : collapsedRect
        let inside = triggerRect.contains(mouse)

        let delay = inside ? settings.hoverEnterDelay : settings.hoverExitDelay
        hoverDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if inside { self.setExpanded(true, animated: true) }
            else { self.setExpanded(false, animated: true) }
        }
        hoverDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func toggleExpanded() {
        setExpanded(!isExpanded, animated: true)
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {

        if pinnedFromSettings && !expanded { return }
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        animateFrame(to: expanded, animated: animated)
        updateShapeCornerRadius()

        if !expanded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { [weak self] in
                self?.updatePersistentPeek()
            }
        }
    }

    private func resizeForPeek(active: Bool) {
        guard !isExpanded, let window,
              let screen = window.screen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return }
        if isDebugForced { return }
        let size = active ? NotchGeometry.peekSize(for: screen, measuredLeft: peekLeftMeasured, measuredRight: peekRightMeasured) : NotchGeometry.collapsedSize(for: screen)
        let origin = NotchGeometry.origin(for: screen, size: size)
        let frame = NSRect(origin: origin, size: size)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.32
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
            ctx.allowsImplicitAnimation = true
            window.animator().setFrame(frame, display: true)
        }
    }

    private func animateFrame(to expanded: Bool, animated: Bool) {
        guard let window, let screen = window.screen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return }

        let isColdOpen = expanded && abs(window.frame.size.height - NotchGeometry.baseNotchHeight) < 6
        if isColdOpen {
            primeContentHeightForActiveTab()
        }
        let size = expanded ? NotchGeometry.expandedSize(for: screen, contentHeight: contentHeight, contentWidth: contentWidth, headerLeftMeasured: headerLeftMeasured, headerRightMeasured: headerRightMeasured) : NotchGeometry.collapsedSize(for: screen)
        let origin = NotchGeometry.origin(for: screen, size: size)
        let frame = NSRect(origin: origin, size: size)

        let currentHeight = window.frame.size.height
        let baseNotch = NotchGeometry.baseNotchHeight
        let isInitialOpen = expanded && abs(currentHeight - baseNotch) < 6
        guard animated, !settings.debugDisableAnimations else {
            if let root = window.contentView?.layer {
                NotchController.suppressAllLayerActions(in: root)
            }

            let topLeft = NSPoint(x: frame.origin.x, y: frame.origin.y + frame.size.height)
            NSDisableScreenUpdates()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0
                ctx.allowsImplicitAnimation = false
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                CATransaction.setAnimationDuration(0)
                window.setContentSize(size)
                window.setFrameTopLeftPoint(topLeft)
                window.contentView?.layoutSubtreeIfNeeded()
                CATransaction.commit()
            }
            NSEnableScreenUpdates()
            return
        }
        let duration: TimeInterval
        let timing: CAMediaTimingFunction
        if isInitialOpen {

            duration = settings.expandDuration
            let y2 = 1.0 + max(0, min(1, settings.expandOvershoot)) * 0.8
            timing = CAMediaTimingFunction(controlPoints: 0.34, Float(y2), 0.64, 1.0)
        } else if !expanded {
            duration = settings.collapseDuration
            timing = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
        } else {

            duration = 0.22
            timing = CAMediaTimingFunction(controlPoints: 0.25, 0.85, 0.30, 1.0)
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = timing
            ctx.allowsImplicitAnimation = true
            window.animator().setFrame(frame, display: true)
        }
    }

    private func handleHover(entered: Bool) {
        guard settings.notchEnabled else { return }
        if entered {
            if settings.notchHoverToOpen { setExpanded(true, animated: true) }
        } else {
            setExpanded(false, animated: true)
        }
    }

    private func handleScroll(dx: CGFloat) {
        guard settings.swipeGesturesEnabled, isExpanded else { return }

        if Date() < scrollCooldownUntil { return }
        scrollAccumulator += dx
        let threshold = max(20, CGFloat(settings.swipeDistancePerTab))
        if abs(scrollAccumulator) >= threshold {
            let direction = scrollAccumulator > 0 ? -1 : 1
            advanceTab(direction)
            scrollAccumulator = 0
            scrollCooldownUntil = Date().addingTimeInterval(0.25)
        }
        scrollAccumulatorTimer?.invalidate()
        scrollAccumulatorTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            self?.scrollAccumulator = 0
        }
    }

    private func advanceTab(_ delta: Int) {
        let tabs = settings.layout.tabs
        guard !tabs.isEmpty else { return }
        let idx = tabs.firstIndex(where: { $0.id == currentTabID }) ?? 0
        let next = (idx + delta + tabs.count) % tabs.count
        currentTabID = tabs[next].id
    }

    func showTabContaining(_ kind: WidgetKind) {
        if let tab = settings.layout.tabs.first(where: { $0.contains(kind: kind) }) {
            currentTabID = tab.id
        }
        setExpanded(true, animated: true)
    }

    func showSneakPeek(_ model: SneakPeekModel) {
        guard !isDebugForced else { return }
        sneakPeek = model
        resizeForPeek(active: true)
        sneakDismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.sneakPeek = nil
            if !self.shouldHoldPeek { self.resizeForPeek(active: false) }
        }
        sneakDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.sneakPeekDuration, execute: work)
    }

    private var shouldHoldPeek: Bool {
        settings.layout.peekLeftSlots.contains { peekSlotHasContent($0.kind) } ||
        settings.layout.peekRightSlots.contains { peekSlotHasContent($0.kind) }
    }

    private func peekSlotHasContent(_ kind: WidgetKind?) -> Bool {
        guard let kind else { return false }
        if kind.requiresMedia { return media.nowPlaying != nil }
        if kind.requiresTrayItems { return !tray.items.isEmpty }
        return true
    }

    private func updatePersistentPeek() {
        guard !isExpanded, !isDebugForced else { return }
        if shouldHoldPeek {
            resizeForPeek(active: true)
        } else if sneakPeek == nil {
            resizeForPeek(active: false)
        }
    }

    func applyDebugForcedState() {
        let forced = settings.debugForceState
        guard forced != "off" else { return }
        guard let window,
              let screen = window.screen ?? NSScreen.builtInWithNotch ?? NSScreen.main else {
            return
        }
        let collapsed = NotchGeometry.collapsedSize(for: screen)
        let peek = NotchGeometry.peekSize(for: screen, measuredLeft: peekLeftMeasured, measuredRight: peekRightMeasured)
        let expandedS = NotchGeometry.expandedSize(for: screen, contentHeight: contentHeight, contentWidth: contentWidth, headerLeftMeasured: headerLeftMeasured, headerRightMeasured: headerRightMeasured)
        let size: NSSize
        let expanded: Bool
        switch forced {
        case "expanded":
            size = expandedS
            expanded = true
        case "peek":
            size = peek
            expanded = false
        case "collapsed":
            size = collapsed
            expanded = false
        default:
            return
        }
        isExpanded = expanded
        let frame = NSRect(origin: NotchGeometry.origin(for: screen, size: size), size: size)
        window.setFrame(frame, display: true, animate: false)
    }

    var isDebugForced: Bool { settings.debugForceState != "off" }

    func openCurrentMediaApp() {
        guard settings.clickIconOpensApp,
              let bundleID = media.nowPlaying?.bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func triggerSneakPeekFromMedia() {
        guard let now = media.nowPlaying else { return }
        showSneakPeek(SneakPeekModel(title: now.title, subtitle: now.artist))
    }

    private var settingsCancellables = Set<AnyCancellable>()

    private func bindSettings() {
        settings.$notchEnabled
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled { self.start() } else { self.stop() }
            }
            .store(in: &settingsCancellables)

        settings.$clipboardHistorySize.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] size in
            self?.clipboard.setHistorySize(size)
        }.store(in: &settingsCancellables)

        settings.$layout
            .map { $0.usesAny(of: [.calendar, .calendarWeek, .calendarEvents]) }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] needsCalendar in
                guard let self else { return }
                if needsCalendar { self.calendar.start() } else { self.calendar.stop() }
            }
            .store(in: &settingsCancellables)

        settings.$layout
            .map { $0.usesAny(of: NotchController.mediaWidgetKinds) }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] needsMedia in
                guard let self else { return }
                if needsMedia { self.media.start() } else { self.media.stop() }
            }
            .store(in: &settingsCancellables)

        Publishers.CombineLatest3(settings.$hotkeyToggleNotch, settings.$hotkeySneakPeek, settings.$hotkeyClipboard)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                guard let self else { return }
                self.hotkeys.register(
                    settings: self.settings,
                    onToggleNotch: { [weak self] in self?.toggleExpanded() },
                    onSneakPeek: { [weak self] in self?.triggerSneakPeekFromMedia() },
                    onShowClipboard: { [weak self] in self?.showTabContaining(.clipboardList) }
                )
            }.store(in: &settingsCancellables)
    }
}

struct SneakPeekModel: Equatable {
    let title: String
    let subtitle: String
}

struct LiveActivityModel: Equatable {
    let kind: Kind
    let label: String
    let detail: String?

    enum Kind: Equatable {
        case music
        case timer
        case download
        case custom
    }
}

final class HoverTrackingView: NSView {
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var onScroll: ((CGFloat) -> Void)?

    var onDragEnter: (() -> Void)?
    var onDragExit: (() -> Void)?
    var onDrop: (([NSItemProvider]) -> Bool)?
    private var tracking: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.image")
        ])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.image")
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { onMouseEnter?() }
    override func mouseExited(with event: NSEvent) { onMouseExit?() }
    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.scrollingDeltaX)
    }
    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEnter?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExit?()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        let providers = (pasteboard.pasteboardItems ?? []).compactMap { item -> NSItemProvider? in
            let provider = NSItemProvider()
            for type in item.types {
                if let data = item.data(forType: type) {
                    provider.registerDataRepresentation(forTypeIdentifier: type.rawValue, visibility: .all) { handler in
                        handler(data, nil)
                        return nil
                    }
                }
            }
            return provider
        }

        var urlProviders: [NSItemProvider] = []
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            for url in urls {
                let p = NSItemProvider()
                p.registerObject(url as NSURL, visibility: .all)
                urlProviders.append(p)
            }
        }
        let all = urlProviders.isEmpty ? providers : urlProviders
        return onDrop?(all) ?? false
    }
}
