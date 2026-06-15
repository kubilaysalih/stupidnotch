import Cocoa
import Carbon.HIToolbox

final class HotkeyController {
    private var registered: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false
    private var nextID: UInt32 = 1

    func register(settings: AppSettings,
                  onToggleNotch: @escaping () -> Void,
                  onSneakPeek: @escaping () -> Void,
                  onShowClipboard: @escaping () -> Void) {
        unregisterAll()
        installHandlerIfNeeded()
        if let hk = settings.hotkeyToggleNotch { add(hk, action: onToggleNotch) }
        if let hk = settings.hotkeySneakPeek { add(hk, action: onSneakPeek) }
        if let hk = settings.hotkeyClipboard { add(hk, action: onShowClipboard) }
    }

    func unregisterAll() {
        for (_, ref) in registered {
            UnregisterEventHotKey(ref)
        }
        registered.removeAll()
        actions.removeAll()
    }

    private func add(_ value: HotkeyValue, action: @escaping () -> Void) {
        let id = nextID; nextID += 1
        var ref: EventHotKeyRef?
        var hkID = EventHotKeyID(signature: OSType(0x53544E48), id: id)
        let carbonMods = carbonModifiers(from: value.modifiers)
        let status = RegisterEventHotKey(UInt32(value.keyCode), carbonMods, hkID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return }
        registered[id] = ref
        actions[id] = action
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, ctx -> OSStatus in
            guard let event, let ctx else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil, &id)
            let unmanaged = Unmanaged<HotkeyController>.fromOpaque(ctx).takeUnretainedValue()
            unmanaged.actions[id.id]?()
            return noErr
        }, 1, &spec, context, nil)
        handlerInstalled = true
    }

    private func carbonModifiers(from cocoa: UInt32) -> UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(cocoa))
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option)  { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift)   { result |= UInt32(shiftKey) }
        return result
    }
}
