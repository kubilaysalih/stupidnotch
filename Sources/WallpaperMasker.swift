import Cocoa
import UniformTypeIdentifiers
import ScreenCaptureKit

enum WallpaperMaskerError: Error {
    case loadFailed
    case unsupportedFormat
    case contextFailed
    case writeFailed
}

enum WallpaperMasker {
    static let appSupportDir: URL = {
        let fm = FileManager.default
        let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StupidNotch", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let cacheRoot: URL = {
        let url = appSupportDir.appendingPathComponent("cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static func cacheKey(for url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modDate = attrs[.modificationDate] as? Date,
              let size = attrs[.size] as? Int else { return nil }
        let signature = "\(url.standardized.path)|\(Int(modDate.timeIntervalSince1970))|\(size)"
        var h: UInt64 = 14695981039346656037
        for byte in signature.utf8 {
            h ^= UInt64(byte)
            h = h &* 1099511628211
        }
        return String(h, radix: 16)
    }

    static func cacheEntry(for key: String) -> URL {
        cacheRoot.appendingPathComponent(key, isDirectory: true)
    }

    static func cacheOriginalIfNeeded(_ source: URL, key: String) throws -> URL {
        let dir = cacheEntry(for: key)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = source.pathExtension.isEmpty ? "img" : source.pathExtension
        let cached = dir.appendingPathComponent("original.\(ext)")
        if !FileManager.default.fileExists(atPath: cached.path) {
            try FileManager.default.copyItem(at: source, to: cached)
        }
        return cached
    }

    static func maskedURL(for key: String, radius: CGFloat, style: CornerStyle) -> URL {
        let name = "masked-r\(Int(radius))-s\(style.rawValue).png"
        return cacheEntry(for: key).appendingPathComponent(name)
    }

    static func isMaskCurrentlySet(for screen: NSScreen) -> Bool {
        guard let current = NSWorkspace.shared.desktopImageURL(for: screen) else { return false }
        return isMaskFile(current)
    }

    static func captureWallpaper(for screen: NSScreen) async -> URL? {
        guard let displayIDNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        let displayID = displayIDNumber.uint32Value

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let scDisplay = content.displays.first(where: { $0.displayID == displayID }) else { return nil }

            let wallpaperWindows = content.windows.filter { window in
                window.owningApplication?.applicationName == "Dock"
                    && (window.title?.hasPrefix("Wallpaper") ?? false)
            }

            let filter: SCContentFilter
            if !wallpaperWindows.isEmpty, #available(macOS 14.0, *) {
                filter = SCContentFilter(display: scDisplay, including: wallpaperWindows)
            } else {
                let myApp = content.applications.first {
                    $0.processID == ProcessInfo.processInfo.processIdentifier
                }
                filter = SCContentFilter(
                    display: scDisplay,
                    excludingApplications: [myApp].compactMap { $0 },
                    exceptingWindows: []
                )
            }

            let config = SCStreamConfiguration()
            config.width = Int(screen.frame.width * screen.backingScaleFactor)
            config.height = Int(screen.frame.height * screen.backingScaleFactor)
            config.showsCursor = false
            config.capturesAudio = false

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            let stamp = Int(Date().timeIntervalSince1970 * 1000)
            let captureDir = appSupportDir.appendingPathComponent("captures", isDirectory: true)
            try? FileManager.default.createDirectory(at: captureDir, withIntermediateDirectories: true)
            let outURL = captureDir.appendingPathComponent("display-\(displayID)-\(stamp).png")

            guard let dest = CGImageDestinationCreateWithURL(
                outURL as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            ) else { return nil }
            CGImageDestinationAddImage(dest, cgImage, nil)
            guard CGImageDestinationFinalize(dest) else { return nil }

            if let entries = try? FileManager.default.contentsOfDirectory(at: captureDir, includingPropertiesForKeys: nil) {
                for entry in entries where entry != outURL {
                    try? FileManager.default.removeItem(at: entry)
                }
            }
            return outURL
        } catch {
            NSLog("StupidNotch: capture failed: \(error)")
            return nil
        }
    }

    static func isStaticImage(_ url: URL) -> Bool {
        let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "qt"]
        if videoExtensions.contains(url.pathExtension.lowercased()) {
            return false
        }
        guard let img = NSImage(contentsOf: url),
              img.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil else {
            return false
        }
        return true
    }

    struct ApplyResult {
        let cachedOriginal: URL
        let maskedURL: URL
    }

    @discardableResult
    static func apply(
        to screen: NSScreen,
        cornerRadius: CGFloat,
        cornerStyle: CornerStyle,
        sourceURL: URL
    ) throws -> ApplyResult {
        if !isStaticImage(sourceURL) {
            throw WallpaperMaskerError.unsupportedFormat
        }
        guard let key = cacheKey(for: sourceURL) else {
            throw WallpaperMaskerError.loadFailed
        }
        let cachedOriginal = try cacheOriginalIfNeeded(sourceURL, key: key)
        let outURL = maskedURL(for: key, radius: cornerRadius, style: cornerStyle)

        if !FileManager.default.fileExists(atPath: outURL.path) {
            try renderMask(
                from: cachedOriginal,
                to: outURL,
                screen: screen,
                cornerRadius: cornerRadius,
                cornerStyle: cornerStyle
            )
        }

        try NSWorkspace.shared.setDesktopImageURL(outURL, for: screen, options: [
            .imageScaling: NSNumber(value: NSImageScaling.scaleProportionallyUpOrDown.rawValue),
            .allowClipping: true
        ])

        return ApplyResult(cachedOriginal: cachedOriginal, maskedURL: outURL)
    }

    private static func renderMask(
        from sourceURL: URL,
        to destURL: URL,
        screen: NSScreen,
        cornerRadius: CGFloat,
        cornerStyle: CornerStyle
    ) throws {
        guard let source = NSImage(contentsOf: sourceURL),
              let cgSource = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw WallpaperMaskerError.loadFailed
        }

        let scale = screen.backingScaleFactor
        let pxWidth = Int((screen.frame.width * scale).rounded())
        let pxHeight = Int((screen.frame.height * scale).rounded())

        let menuBarHeightPt: CGFloat = {
            if #available(macOS 12.0, *), screen.safeAreaInsets.top > 0 {
                return screen.safeAreaInsets.top
            }
            return NSStatusBar.system.thickness
        }()

        let bottomExtension: CGFloat = 4 * scale
        let h = menuBarHeightPt * scale + bottomExtension
        let r = max(0, cornerRadius * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: pxWidth,
            height: pxHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw WallpaperMaskerError.contextFailed
        }

        let dstW = CGFloat(pxWidth)
        let dstH = CGFloat(pxHeight)
        let srcW = CGFloat(cgSource.width)
        let srcH = CGFloat(cgSource.height)
        let srcAspect = srcW / srcH
        let dstAspect = dstW / dstH

        let drawRect: CGRect
        if srcAspect > dstAspect {
            let drawWidth = dstH * srcAspect
            drawRect = CGRect(x: (dstW - drawWidth) / 2, y: 0, width: drawWidth, height: dstH)
        } else {
            let drawHeight = dstW / srcAspect
            drawRect = CGRect(x: 0, y: (dstH - drawHeight) / 2, width: dstW, height: drawHeight)
        }

        ctx.interpolationQuality = .high
        ctx.draw(cgSource, in: drawRect)

        let topPath = CGMutablePath()
        topPath.move(to: CGPoint(x: 0, y: dstH))
        topPath.addLine(to: CGPoint(x: dstW, y: dstH))
        if r > 0 {
            topPath.addLine(to: CGPoint(x: dstW, y: dstH - h - r))
            addCornerCurve(
                path: topPath,
                from: CGPoint(x: dstW, y: dstH - h - r),
                to: CGPoint(x: dstW - r, y: dstH - h),
                corner: CGPoint(x: dstW, y: dstH - h),
                style: cornerStyle
            )
            topPath.addLine(to: CGPoint(x: r, y: dstH - h))
            addCornerCurve(
                path: topPath,
                from: CGPoint(x: r, y: dstH - h),
                to: CGPoint(x: 0, y: dstH - h - r),
                corner: CGPoint(x: 0, y: dstH - h),
                style: cornerStyle
            )
        } else {
            topPath.addLine(to: CGPoint(x: dstW, y: dstH - h))
            topPath.addLine(to: CGPoint(x: 0, y: dstH - h))
        }
        topPath.closeSubpath()

        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.addPath(topPath)
        ctx.fillPath()

        if r > 0 {
            let bottomPath = CGMutablePath()
            bottomPath.move(to: CGPoint(x: 0, y: 0))
            bottomPath.addLine(to: CGPoint(x: 0, y: r))
            addCornerCurve(
                path: bottomPath,
                from: CGPoint(x: 0, y: r),
                to: CGPoint(x: r, y: 0),
                corner: CGPoint(x: 0, y: 0),
                style: cornerStyle
            )
            bottomPath.closeSubpath()

            bottomPath.move(to: CGPoint(x: dstW, y: 0))
            bottomPath.addLine(to: CGPoint(x: dstW - r, y: 0))
            addCornerCurve(
                path: bottomPath,
                from: CGPoint(x: dstW - r, y: 0),
                to: CGPoint(x: dstW, y: r),
                corner: CGPoint(x: dstW, y: 0),
                style: cornerStyle
            )
            bottomPath.closeSubpath()

            ctx.setFillColor(CGColor(gray: 0, alpha: 1))
            ctx.addPath(bottomPath)
            ctx.fillPath()
        }

        guard let outImage = ctx.makeImage() else {
            throw WallpaperMaskerError.contextFailed
        }

        guard let dest = CGImageDestinationCreateWithURL(
            destURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw WallpaperMaskerError.writeFailed
        }
        CGImageDestinationAddImage(dest, outImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw WallpaperMaskerError.writeFailed
        }
    }

    static func restore(for screen: NSScreen, originalURL: URL) {
        try? NSWorkspace.shared.setDesktopImageURL(originalURL, for: screen, options: [:])
    }

    static func isMaskFile(_ url: URL) -> Bool {
        url.path.hasPrefix(appSupportDir.path)
    }

    private static func addCornerCurve(
        path: CGMutablePath,
        from: CGPoint,
        to: CGPoint,
        corner: CGPoint,
        style: CornerStyle
    ) {
        switch style {
        case .circular:
            path.addQuadCurve(to: to, control: corner)
        case .continuous:
            // figma-squircle math (smoothness = 1.0)
            //   https://www.figma.com/blog/desperately-seeking-squircles/
            // For s = 1, arcMeasure = 0 → two cubic beziers cover the whole corner.
            // a + b + c + d = p (the distance along each edge from the corner).
            let p = hypot(corner.x - from.x, corner.y - from.y)
            guard p > 0 else { path.addLine(to: to); return }

            let a = 0.4714 * p
            let b = 0.2357 * p
            let c = 0.1464 * p
            let d = 0.1464 * p

            let uX = (corner.x - from.x) / p
            let uY = (corner.y - from.y) / p
            let vX = (to.x - corner.x) / p
            let vY = (to.y - corner.y) / p

            let mid = CGPoint(
                x: from.x + (a + b + c) * uX + d * vX,
                y: from.y + (a + b + c) * uY + d * vY
            )

            path.addCurve(
                to: mid,
                control1: CGPoint(x: from.x + a * uX, y: from.y + a * uY),
                control2: CGPoint(x: from.x + (a + b) * uX, y: from.y + (a + b) * uY)
            )

            path.addCurve(
                to: to,
                control1: CGPoint(
                    x: mid.x + d * uX + c * vX,
                    y: mid.y + d * uY + c * vY
                ),
                control2: CGPoint(
                    x: mid.x + d * uX + (b + c) * vX,
                    y: mid.y + d * uY + (b + c) * vY
                )
            )
        }
    }

}

extension NSScreen {
    var hasNotch: Bool {
        if #available(macOS 12.0, *) {
            return safeAreaInsets.top > 0
        }
        return false
    }

    static var builtInWithNotch: NSScreen? {
        screens.first(where: { $0.hasNotch })
    }

    var uniqueID: String {
        if let n = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "\(n.uint32Value)"
        }
        return "main"
    }
}
