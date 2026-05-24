import AppKit
import SwiftUI

@MainActor
enum QuickCapturePresenter {
    static func toggle(appState: AppState) {
        NSApp.activate(ignoringOtherApps: true)
        appState.toggleQuickCapture()
    }

    static func showPrefilled(appState: AppState, content: String) {
        NSApp.activate(ignoringOtherApps: true)
        appState.presentQuickCapture(prefill: content)
    }
}
