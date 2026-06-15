import Cocoa
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private let overlay = OverlayManager()
    private lazy var notch: NotchController = NotchController(settings: settings)

    private var settingsWindow: NSWindow?
    private let settingsController = SettingsController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        notch.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(workspaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings(nil)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    @objc func openSettings(_ sender: Any?) {
        if let w = settingsWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let root = SettingsRoot(settings: settings, overlay: overlay, controller: settingsController, notch: notch)
        let host = NSHostingController(rootView: root)
        let w = NSWindow(contentViewController: host)
        w.title = ""
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]

        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.setContentSize(NSSize(width: 760, height: 560))
        w.setFrameAutosaveName("StupidNotchSettingsWindow")
        w.center()
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        settingsWindow = w
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: w,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.notch.pinnedFromSettings = false
            self.notch.setExpanded(false, animated: true)
        }
    }

    @objc private func screensChanged() {
        overlay.refreshState()
        notch.rebuildWindow()
    }

    @objc private func workspaceChanged() {
        overlay.refreshState()
    }
}
