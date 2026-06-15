import Cocoa

final class NotchWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.level = .statusBar + 1
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        self.isMovable = false
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
        self.tabbingMode = .disallowed

        self.animationBehavior = .none
        positionForScreen(screen, expanded: false)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var dropHandler: HoverTrackingView? { contentView as? HoverTrackingView }

    func positionForScreen(_ screen: NSScreen, expanded: Bool) {
        let size = expanded ? NotchGeometry.expandedSize(for: screen) : NotchGeometry.collapsedSize(for: screen)
        let origin = NotchGeometry.origin(for: screen, size: size)
        setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
    }
}

enum NotchGeometry {
    static let fallbackNotchWidth: CGFloat = 200
    static let fallbackNotchHeight: CGFloat = 32

    static var baseNotchWidth: CGFloat { notchWidth(for: NSScreen.builtInWithNotch ?? NSScreen.main!) }
    static var baseNotchHeight: CGFloat { notchHeight(for: NSScreen.builtInWithNotch ?? NSScreen.main!) }
    static var cornerRadius: CGFloat { CGFloat(AppSettings.shared.notchCornerRadius) }

    static func expandedBodyWidth(for screen: NSScreen,
                                  contentWidth: CGFloat = 0,
                                  headerLeftMeasured: CGFloat = 0,
                                  headerRightMeasured: CGFloat = 0) -> CGFloat {
        let configured = CGFloat(AppSettings.shared.expandedPanelWidth)
        let widthFromContent = contentWidth > 0 ? contentWidth + 28 : 0
        let bandWidth = max(headerLeftMeasured, headerRightMeasured)
        let widthFromHeader = bandWidth > 0 ? 2 * bandWidth + notchWidth(for: screen) + 8 : 0
        return max(configured, widthFromContent, widthFromHeader)
    }

    static func notchHeight(for screen: NSScreen) -> CGFloat {
        let settings = AppSettings.shared
        if !settings.useSystemNotchDimensions {
            return CGFloat(settings.customNotchHeight)
        }
        if #available(macOS 12.0, *), screen.safeAreaInsets.top > 0 {
            return screen.safeAreaInsets.top
        }
        return fallbackNotchHeight
    }

    static func notchWidth(for screen: NSScreen) -> CGFloat {
        let settings = AppSettings.shared
        if !settings.useSystemNotchDimensions {
            return CGFloat(settings.customNotchWidth)
        }
        if #available(macOS 12.0, *),
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let w = right.minX - left.maxX
            if w > 0 { return w }
        }
        return fallbackNotchWidth
    }

    static func collapsedSize(for screen: NSScreen) -> NSSize {
        NSSize(width: notchWidth(for: screen), height: notchHeight(for: screen))
    }

    static func peekSize(for screen: NSScreen) -> NSSize {
        return peekSize(for: screen, measuredLeft: 0, measuredRight: 0)
    }

    static func peekSize(for screen: NSScreen,
                         measuredLeft: CGFloat,
                         measuredRight: CGFloat) -> NSSize {
        let bandWidth = max(measuredLeft, measuredRight)
        let cornerInset: CGFloat = 16
        let floor = CGFloat(AppSettings.shared.peekExtraWidth)
        let computedExtra = 2 * (bandWidth + cornerInset)
        return NSSize(
            width: notchWidth(for: screen) + max(floor, computedExtra),
            height: notchHeight(for: screen)
        )
    }

    static func expandedSize(for screen: NSScreen,
                             contentHeight: CGFloat = 0,
                             contentWidth: CGFloat = 0,
                             headerLeftMeasured: CGFloat = 0,
                             headerRightMeasured: CGFloat = 0) -> NSSize {
        let headerReserve = baseNotchHeight + 4
        let bottomPadding: CGFloat = 12
        let content: CGFloat = contentHeight > 0 ? contentHeight : 160
        let total = headerReserve + content + bottomPadding
        let minHeight = baseNotchHeight + 60
        let maxHeight = max(minHeight, screen.frame.height - 80)
        let configured = CGFloat(AppSettings.shared.expandedPanelWidth)
        let width = expandedBodyWidth(
            for: screen,
            contentWidth: contentWidth,
            headerLeftMeasured: headerLeftMeasured,
            headerRightMeasured: headerRightMeasured
        )
        let maxWidth = max(configured, screen.frame.width - 80)
        return NSSize(
            width: min(width, maxWidth),
            height: max(minHeight, min(maxHeight, total))
        )
    }

    static func origin(for screen: NSScreen, size: NSSize) -> NSPoint {
        let x = screen.frame.midX - size.width / 2
        let topOffset = AppSettings.shared.debugOffsetFromTop
        let y = screen.frame.maxY - size.height - CGFloat(topOffset)
        return NSPoint(x: x, y: y)
    }
}
