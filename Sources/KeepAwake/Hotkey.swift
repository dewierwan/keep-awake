import Carbon.HIToolbox
import KeepAwakeCore

/// One system-wide keyboard shortcut, registered through Carbon because that
/// needs no Accessibility permission.
final class Hotkey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    var onPress: (() -> Void)?

    var isRegistered: Bool { hotKeyRef != nil }

    /// Returns false when another app already holds the shortcut.
    @discardableResult
    func register(_ spec: HotkeySpec) -> Bool {
        if handlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)
            )
            InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
                guard let userData else { return noErr }
                let hotkey = Unmanaged<Hotkey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { hotkey.onPress?() }
                return noErr
            }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        }
        guard hotKeyRef == nil else { return true }
        let id = EventHotKeyID(signature: OSType(0x4B_41_57_4B), id: 1) // "KAWK"
        let status = RegisterEventHotKey(
            spec.keyCode, spec.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        if status != noErr { hotKeyRef = nil }
        return status == noErr
    }
}
