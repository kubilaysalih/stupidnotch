import Cocoa
import Combine

final class OverlayManager: ObservableObject {
    @Published var cornerRadius: Double {
        didSet {
            AppSettings.cornerRadius = cornerRadius
            if isApplied { render() }
        }
    }
    @Published var cornerStyle: CornerStyle {
        didSet {
            AppSettings.cornerStyle = cornerStyle.rawValue
            if isApplied { render() }
        }
    }
    @Published private(set) var isApplied: Bool = false
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var unsupportedWallpaper: Bool = false

    private var cachedOriginalURL: URL?
    private var pendingCount: Int = 0
    private let renderQueue = DispatchQueue(label: "io.kubilay.stupidnotch.render", qos: .userInitiated)

    init() {
        self.cornerRadius = AppSettings.cornerRadius
        self.cornerStyle = CornerStyle(rawValue: AppSettings.cornerStyle) ?? .circular
        if let stored = AppSettings.originalWallpaperPath {
            let url = URL(fileURLWithPath: stored)
            if FileManager.default.fileExists(atPath: url.path) {
                self.cachedOriginalURL = url
            }
        }
        refreshState()
    }

    var hasNotch: Bool { NSScreen.builtInWithNotch != nil }

    func refreshState() {
        guard let screen = NSScreen.builtInWithNotch else {
            isApplied = false
            unsupportedWallpaper = false
            return
        }
        isApplied = WallpaperMasker.isMaskCurrentlySet(for: screen)
        unsupportedWallpaper = false
    }

    func apply() {
        guard let screen = NSScreen.builtInWithNotch else { return }
        pendingCount += 1
        isProcessing = true

        Task { [weak self] in
            guard let self else { return }
            let captured = await WallpaperMasker.captureWallpaper(for: screen)
            await MainActor.run {
                self.pendingCount = max(0, self.pendingCount - 1)
                self.isProcessing = self.pendingCount > 0
                guard let captured else {
                    self.unsupportedWallpaper = true
                    self.isApplied = false
                    return
                }
                self.unsupportedWallpaper = false
                self.render(source: captured, screen: screen)
            }
        }
    }

    func remove() {
        guard let screen = NSScreen.builtInWithNotch,
              let cached = cachedOriginalURL,
              FileManager.default.fileExists(atPath: cached.path) else {
            isApplied = false
            return
        }
        WallpaperMasker.restore(for: screen, originalURL: cached)
        isApplied = false
    }

    private func render() {
        guard let screen = NSScreen.builtInWithNotch,
              let cached = cachedOriginalURL else { return }
        render(source: cached, screen: screen)
    }

    private func render(source: URL, screen: NSScreen) {
        let style = cornerStyle
        let radius = CGFloat(cornerRadius) * (style == .continuous ? 2 : 1)

        pendingCount += 1
        isProcessing = true

        renderQueue.async { [weak self] in
            var failure: Error?
            var result: WallpaperMasker.ApplyResult?
            do {
                result = try WallpaperMasker.apply(
                    to: screen,
                    cornerRadius: radius,
                    cornerStyle: style,
                    sourceURL: source
                )
            } catch {
                failure = error
                NSLog("StupidNotch: failed to apply mask: \(error)")
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.pendingCount = max(0, self.pendingCount - 1)
                self.isProcessing = self.pendingCount > 0
                if case WallpaperMaskerError.unsupportedFormat = failure as Any {
                    self.unsupportedWallpaper = true
                    self.isApplied = false
                } else if let result = result {
                    self.cachedOriginalURL = result.cachedOriginal
                    AppSettings.originalWallpaperPath = result.cachedOriginal.path
                    self.isApplied = true
                    self.unsupportedWallpaper = false
                }
            }
        }
    }
}
