import Carbon
import AppKit
import SwiftData

final class GlobalHotKey {
    static let shared = GlobalHotKey()
    private var hotKeyRef: EventHotKeyRef?
    private var container: ModelContainer?

    private init() {}

    func register(container: ModelContainer) {
        self.container = container

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            GlobalHotKey.shared.handleHotKey()
            return noErr
        }, 1, &eventType, nil, nil)

        // Option+Space: modifier 0x0800 = optionKey, keyCode 49 = Space
        var hotKeyID = EventHotKeyID(signature: OSType(0x4454_484B), id: 1) // "DTHK"
        let modifiers: UInt32 = UInt32(optionKey)
        RegisterEventHotKey(UInt32(49), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func handleHotKey() {
        guard let container else { return }
        DispatchQueue.main.async {
            QuickCaptureWindowController.shared.toggle(with: container)
        }
    }
}
