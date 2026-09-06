import Carbon
import Foundation

@MainActor final class GlobalShortcuts {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    var action: ((UInt32) -> Void)?
    private(set) var registered = false
    func install() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr else { return result }
            let owner = Unmanaged<GlobalShortcuts>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { owner.action?(identifier.id) }; return noErr
        }, 1, &event, context, &handler)
        guard status == noErr else { return }
        for (id, key) in [(UInt32(1), UInt32(kVK_Space)), (UInt32(2), UInt32(kVK_ANSI_Period))] {
            var reference: EventHotKeyRef?
            let result = RegisterEventHotKey(key, UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x45434453, id: id), GetApplicationEventTarget(), 0, &reference)
            if result == noErr, let reference { refs.append(reference) }
        }
        registered = refs.count == 2
    }
    func uninstall() { for ref in refs { UnregisterEventHotKey(ref) }; refs.removeAll(); if let handler { RemoveEventHandler(handler) }; handler = nil }
}
