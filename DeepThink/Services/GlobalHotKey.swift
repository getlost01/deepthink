import AppKit
import Carbon
import SwiftData

final class GlobalHotKey {
    static let shared = GlobalHotKey()
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var container: ModelContainer?
    private var appState: AppState?

    private init() {}

    func register(container: ModelContainer, appState: AppState) {
        self.container = container
        self.appState = appState

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            GlobalHotKey.shared.handleHotKey()
            return noErr
        }, 1, &eventType, nil, &eventHandlerRef)

        // Option+Space: modifier 0x0800 = optionKey, keyCode 49 = Space
        let hotKeyID = EventHotKeyID(signature: OSType(0x4454_484B), id: 1)
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
        guard let container, let appState else { return }
        DispatchQueue.main.async {
            QuickCaptureWindowController.shared.toggle(with: container, appState: appState)
        }
    }
}
