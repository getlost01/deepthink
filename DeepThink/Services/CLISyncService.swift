import Foundation

extension Notification.Name {
    static let cliWorkspaceChanged = Notification.Name("com.deepthink.cliWorkspaceChanged")
}

final class CLISyncService {
    static let shared = CLISyncService()
    private var isRegistered = false

    deinit {
        if isRegistered {
            CFNotificationCenterRemoveObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                Unmanaged.passUnretained(self).toOpaque(),
                CFNotificationName("com.deepthink.workspace.changed" as CFString),
                nil
            )
        }
    }

    func start() {
        guard !isRegistered else { return }
        isRegistered = true
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CLISyncService.onChanged,
            "com.deepthink.workspace.changed" as CFString,
            nil,
            .deliverImmediately
        )
    }

    private static let onChanged: CFNotificationCallback = { _, _, _, _, _ in
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .cliWorkspaceChanged, object: nil)
        }
    }
}
