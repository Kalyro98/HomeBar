import AppKit
import Carbon.HIToolbox

/// Registriert einen systemweiten Tastatur-Shortcut (Carbon RegisterEventHotKey).
/// Braucht – anders als ein NSEvent-Global-Monitor – keine Bedienungshilfen-Berechtigung.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    /// - Parameters:
    ///   - keyCode: virtueller Tastencode (z. B. `kVK_ANSI_H`)
    ///   - modifiers: Carbon-Modifier (z. B. `cmdKey | shiftKey`)
    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: OSType(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var hRef: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let me = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { me.action() }
            return noErr
        }, 1, &eventType, selfPtr, &hRef)
        handlerRef = hRef

        let hotKeyID = EventHotKeyID(signature: OSType(0x484D4252) /* 'HMBR' */, id: 1)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        hotKeyRef = ref
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
