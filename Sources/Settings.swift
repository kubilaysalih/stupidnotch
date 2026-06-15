import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    @Published var startAtLogin: Bool { didSet { defaults.set(startAtLogin, forKey: "startAtLogin") } }
    @Published var notchEnabled: Bool { didSet { defaults.set(notchEnabled, forKey: "notchEnabled") } }
    @Published var notchHoverToOpen: Bool { didSet { defaults.set(notchHoverToOpen, forKey: "notchHoverToOpen") } }

    @Published var useSystemNotchDimensions: Bool { didSet { defaults.set(useSystemNotchDimensions, forKey: "useSystemNotchDimensions") } }
    @Published var customNotchWidth: Double { didSet { defaults.set(customNotchWidth, forKey: "customNotchWidth") } }
    @Published var customNotchHeight: Double { didSet { defaults.set(customNotchHeight, forKey: "customNotchHeight") } }
    @Published var peekExtraWidth: Double { didSet { defaults.set(peekExtraWidth, forKey: "peekExtraWidth") } }

    @Published var expandedPanelWidth: Double { didSet { defaults.set(expandedPanelWidth, forKey: "expandedPanelWidth") } }
    @Published var notchCornerRadius: Double { didSet { defaults.set(notchCornerRadius, forKey: "notchCornerRadius") } }

    @Published var hoverMarginHorizontal: Double { didSet { defaults.set(hoverMarginHorizontal, forKey: "hoverMarginHorizontal") } }
    @Published var hoverMarginVertical: Double { didSet { defaults.set(hoverMarginVertical, forKey: "hoverMarginVertical") } }

    @Published var expandDuration: Double { didSet { defaults.set(expandDuration, forKey: "expandDuration") } }
    @Published var collapseDuration: Double { didSet { defaults.set(collapseDuration, forKey: "collapseDuration") } }
    @Published var expandOvershoot: Double { didSet { defaults.set(expandOvershoot, forKey: "expandOvershoot") } }
    @Published var hoverEnterDelay: Double { didSet { defaults.set(hoverEnterDelay, forKey: "hoverEnterDelay") } }
    @Published var hoverExitDelay: Double { didSet { defaults.set(hoverExitDelay, forKey: "hoverExitDelay") } }

    @Published var sneakPeekEnabled: Bool { didSet { defaults.set(sneakPeekEnabled, forKey: "sneakPeekEnabled") } }
    @Published var sneakPeekDuration: Double { didSet { defaults.set(sneakPeekDuration, forKey: "sneakPeekDuration") } }
    @Published var clickIconOpensApp: Bool { didSet { defaults.set(clickIconOpensApp, forKey: "clickIconOpensApp") } }

    @Published var visualizerAlignment: String { didSet { defaults.set(visualizerAlignment, forKey: "visualizerAlignment") } }
    @Published var visualizerBarCount: Int { didSet { defaults.set(visualizerBarCount, forKey: "visualizerBarCount") } }
    @Published var visualizerBarWidth: Double { didSet { defaults.set(visualizerBarWidth, forKey: "visualizerBarWidth") } }
    @Published var visualizerBarSpacing: Double { didSet { defaults.set(visualizerBarSpacing, forKey: "visualizerBarSpacing") } }

    @Published var mediaPlayerShowVisualizer: Bool { didSet { defaults.set(mediaPlayerShowVisualizer, forKey: "mediaPlayerShowVisualizer") } }

    @Published var clipboardHistorySize: Int { didSet { defaults.set(clipboardHistorySize, forKey: "clipboardHistorySize") } }

    @Published var swipeGesturesEnabled: Bool { didSet { defaults.set(swipeGesturesEnabled, forKey: "swipeGesturesEnabled") } }

    @Published var swipeDistancePerTab: Double { didSet { defaults.set(swipeDistancePerTab, forKey: "swipeDistancePerTab") } }

    @Published var hotkeyToggleNotch: HotkeyValue? {
        didSet { HotkeyValue.write(hotkeyToggleNotch, forKey: "hk.toggleNotch", defaults: defaults) }
    }
    @Published var hotkeySneakPeek: HotkeyValue? {
        didSet { HotkeyValue.write(hotkeySneakPeek, forKey: "hk.sneakPeek", defaults: defaults) }
    }
    @Published var hotkeyClipboard: HotkeyValue? {
        didSet { HotkeyValue.write(hotkeyClipboard, forKey: "hk.clipboard", defaults: defaults) }
    }

    @Published var cornerRadius: Double { didSet { defaults.set(cornerRadius, forKey: "cornerRadius") } }
    @Published var cornerStyle: Int { didSet { defaults.set(cornerStyle, forKey: "cornerStyle") } }
    @Published var originalWallpaperPath: String? {
        didSet { defaults.set(originalWallpaperPath, forKey: "originalWallpaperPath") }
    }

    @Published var layout: LayoutConfig {
        didSet {
            if let data = try? JSONEncoder().encode(layout) {
                defaults.set(data, forKey: "layoutConfigJSON")
            }
        }
    }

    @Published var debugForceState: String { didSet { defaults.set(debugForceState, forKey: "debugForceState") } }
    @Published var debugOffsetFromTop: Int { didSet { defaults.set(debugOffsetFromTop, forKey: "debugOffsetFromTop") } }
    @Published var debugDisableAnimations: Bool { didSet { defaults.set(debugDisableAnimations, forKey: "debugDisableAnimations") } }

    @Published var debugSizeHUD: Bool { didSet { defaults.set(debugSizeHUD, forKey: "debugSizeHUD") } }

    private init() {
        let d = UserDefaults.standard
        startAtLogin = (d.object(forKey: "startAtLogin") as? Bool) ?? false
        notchEnabled = (d.object(forKey: "notchEnabled") as? Bool) ?? true
        notchHoverToOpen = (d.object(forKey: "notchHoverToOpen") as? Bool) ?? true

        useSystemNotchDimensions = (d.object(forKey: "useSystemNotchDimensions") as? Bool) ?? true
        customNotchWidth = (d.object(forKey: "customNotchWidth") as? Double) ?? 209
        customNotchHeight = (d.object(forKey: "customNotchHeight") as? Double) ?? 38
        peekExtraWidth = (d.object(forKey: "peekExtraWidth") as? Double) ?? 100
        expandedPanelWidth = (d.object(forKey: "expandedPanelWidth") as? Double) ?? 600
        notchCornerRadius = (d.object(forKey: "notchCornerRadius") as? Double) ?? 10
        hoverMarginHorizontal = (d.object(forKey: "hoverMarginHorizontal") as? Double) ?? 28
        hoverMarginVertical = (d.object(forKey: "hoverMarginVertical") as? Double) ?? 10

        expandDuration = (d.object(forKey: "expandDuration") as? Double) ?? 0.42
        collapseDuration = (d.object(forKey: "collapseDuration") as? Double) ?? 0.32
        expandOvershoot = (d.object(forKey: "expandOvershoot") as? Double) ?? 0.35
        hoverEnterDelay = (d.object(forKey: "hoverEnterDelay") as? Double) ?? 0.05
        hoverExitDelay = (d.object(forKey: "hoverExitDelay") as? Double) ?? 0.18

        sneakPeekEnabled = (d.object(forKey: "sneakPeekEnabled") as? Bool) ?? true
        sneakPeekDuration = (d.object(forKey: "sneakPeekDuration") as? Double) ?? 2.6
        clickIconOpensApp = (d.object(forKey: "clickIconOpensApp") as? Bool) ?? true
        visualizerAlignment = d.string(forKey: "visualizerAlignment") ?? "centered"
        visualizerBarCount = (d.object(forKey: "visualizerBarCount") as? Int) ?? 4
        visualizerBarWidth = (d.object(forKey: "visualizerBarWidth") as? Double) ?? 4
        visualizerBarSpacing = (d.object(forKey: "visualizerBarSpacing") as? Double) ?? 2
        mediaPlayerShowVisualizer = (d.object(forKey: "mediaPlayerShowVisualizer") as? Bool) ?? true

        clipboardHistorySize = (d.object(forKey: "clipboardHistorySize") as? Int) ?? 25

        swipeGesturesEnabled = (d.object(forKey: "swipeGesturesEnabled") as? Bool) ?? true
        swipeDistancePerTab = (d.object(forKey: "swipeDistancePerTab") as? Double) ?? 80

        hotkeyToggleNotch = HotkeyValue.read(forKey: "hk.toggleNotch", defaults: d)
        hotkeySneakPeek = HotkeyValue.read(forKey: "hk.sneakPeek", defaults: d)
        hotkeyClipboard = HotkeyValue.read(forKey: "hk.clipboard", defaults: d)

        cornerRadius = (d.object(forKey: "cornerRadius") as? Double) ?? 22
        cornerStyle = (d.object(forKey: "cornerStyle") as? Int) ?? 0
        originalWallpaperPath = d.string(forKey: "originalWallpaperPath")

        if let data = d.data(forKey: "layoutConfigJSON"),
           var decoded = try? JSONDecoder().decode(LayoutConfig.self, from: data) {

            decoded.migrateLegacyHeaderArrays()
            let leftHasNav = decoded.expandedHeaderLeft.contains { $0.kind == .tabSwitcher } ||
                             decoded.expandedHeaderRight.contains { $0.kind == .tabSwitcher }
            let rightHasGear = decoded.expandedHeaderLeft.contains { $0.kind == .settingsButton } ||
                               decoded.expandedHeaderRight.contains { $0.kind == .settingsButton }
            if !leftHasNav { decoded.expandedHeaderLeft.insert(HeaderSlot(kind: .tabSwitcher), at: 0) }
            if !rightHasGear { decoded.expandedHeaderRight.insert(HeaderSlot(kind: .settingsButton), at: 0) }
            layout = decoded
        } else {
            layout = .default
        }

        debugForceState = (d.string(forKey: "debugForceState")) ?? "off"
        debugOffsetFromTop = (d.object(forKey: "debugOffsetFromTop") as? Int) ?? 0
        debugDisableAnimations = (d.object(forKey: "debugDisableAnimations") as? Bool) ?? false
        debugSizeHUD = (d.object(forKey: "debugSizeHUD") as? Bool) ?? false
    }
}

enum CornerStyle: Int, CaseIterable {
    case circular = 0
    case continuous = 1

    var label: String {
        switch self {
        case .circular: return "Circular"
        case .continuous: return "Squircle"
        }
    }
}

enum VisualizerAlignment: String, CaseIterable, Identifiable {
    case centered, bottom

    var id: String { rawValue }
    var label: String {
        switch self {
        case .centered: return "Centered (grow from middle)"
        case .bottom: return "Bottom (grow upward)"
        }
    }
}

enum DebugForceState: String, CaseIterable, Identifiable {
    case off, collapsed, peek, expanded

    var id: String { rawValue }
    var label: String {
        switch self {
        case .off: return "Off (normal behavior)"
        case .collapsed: return "Force collapsed"
        case .peek: return "Force peek (music indicator)"
        case .expanded: return "Force expanded"
        }
    }
}

struct HotkeyValue: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static func read(forKey key: String, defaults: UserDefaults) -> HotkeyValue? {
        guard let dict = defaults.dictionary(forKey: key),
              let kc = dict["k"] as? UInt32 ?? (dict["k"] as? Int).map({ UInt32($0) }),
              let mod = dict["m"] as? UInt32 ?? (dict["m"] as? Int).map({ UInt32($0) }) else { return nil }
        return HotkeyValue(keyCode: kc, modifiers: mod)
    }

    static func write(_ value: HotkeyValue?, forKey key: String, defaults: UserDefaults) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(["k": Int(value.keyCode), "m": Int(value.modifiers)], forKey: key)
    }
}
