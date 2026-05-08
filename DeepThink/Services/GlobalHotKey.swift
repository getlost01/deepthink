import AppKit
import Carbon
import SwiftData

final class GlobalHotKey {
    static let shared = GlobalHotKey()
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var container: ModelContainer?

    private init() {}

    func register(container: ModelContainer) {
        self.container = container

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            GlobalHotKey.shared.handleHotKey()
            return noErr
        }, 1, &eventType, nil, &eventHandlerRef)

        // Option+Space: modifier 0x0800 = optionKey, keyCode 49 = Space
        var hotKeyID = EventHotKeyID(signature: OSType(0x4454_484B), id: 1) // "DTHK"
        let modifiers = UInt32(optionKey)
        RegisterEventHotKey(UInt32(49), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.unregister()
        }
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref); eventHandlerRef = nil }
    }

    private func handleHotKey() {
        guard let container else { return }
        DispatchQueue.main.async {
            QuickCaptureWindowController.shared.toggle(with: container)
        }
    }
}
