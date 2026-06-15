import Cocoa

let app = NSApplication.shared

let delegate: AppDelegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
