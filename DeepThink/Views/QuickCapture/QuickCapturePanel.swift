import AppKit
import SwiftData
import SwiftUI

final class QuickCapturePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.backgroundColor = .clear
    }

    override var isOpaque: Bool {
        false
    }
}

final class QuickCaptureWindowController: NSWindowController {
    static let shared = QuickCaptureWindowController()
    private var currentContainer: ModelContainer?
    private var currentAppState: AppState?
    private var lastThemeRevision = -1
    private var themeObserver: NSObjectProtocol?

    private init() {
        let panel = QuickCapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 620),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.fullScreenAuxiliary]

        super.init(window: panel)

        if let screen = NSScreen.main {
            let x = (screen.frame.width - 720) / 2
            let y = (screen.frame.height - 620) / 2 + 100
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        themeObserver = NotificationCenter.default.addObserver(
            forName: .dsThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildContentIfVisible()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func show(with container: ModelContainer, appState: AppState) {
        guard NSApp.isActive else { return }

        let revision = DSThemeManager.shared.themeRevision
        let needsRebuild = currentContainer !== container
            || currentAppState !== appState
            || window?.contentView == nil
            || revision != lastThemeRevision

        if needsRebuild {
            currentContainer = container
            currentAppState = appState
            lastThemeRevision = revision
            installContent(container: container, appState: appState)
        }

        window?.makeKeyAndOrderFront(nil)
    }

    private func installContent(container: ModelContainer, appState: AppState) {
        let view = DSThemeRoot {
            QuickCaptureView(
                onDismiss: { [weak self] in self?.dismiss() },
                modelContainer: container
            )
            .environment(appState)
        }
        let hostingView = TransparentHostingView(rootView: view)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = DS.Radius.xl
        hostingView.layer?.masksToBounds = true
        window?.contentView = hostingView
        window?.appearance = NSApp.appearance
    }

    private func rebuildContentIfVisible() {
        guard window?.isVisible == true,
              let container = currentContainer,
              let appState = currentAppState else { return }
        lastThemeRevision = DSThemeManager.shared.themeRevision
        installContent(container: container, appState: appState)
    }

    func showPrefilled(with container: ModelContainer, appState: AppState, content: String) {
        guard NSApp.isActive else { return }
        show(with: container, appState: appState)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: .quickCapturePrefill,
                object: nil,
                userInfo: ["content": content]
            )
        }
    }

    func dismiss() {
        window?.orderOut(nil)
        NotificationCenter.default.post(name: .quickCaptureReset, object: nil)
    }

    func resetAndDismiss() {
        currentContainer = nil
        window?.contentView = nil
        dismiss()
    }

    func toggle(with container: ModelContainer, appState: AppState) {
        if window?.isVisible == true {
            dismiss()
        } else {
            show(with: container, appState: appState)
        }
    }
}
