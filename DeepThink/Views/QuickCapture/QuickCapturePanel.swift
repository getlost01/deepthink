import AppKit
import SwiftUI
import SwiftData

final class QuickCapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.backgroundColor = .clear
    }

    override var isOpaque: Bool { false }
}

final class QuickCaptureWindowController: NSWindowController {
    static let shared = QuickCaptureWindowController()
    private var previousApp: NSRunningApplication?
    private var currentContainer: ModelContainer?

    private init() {
        let panel = QuickCapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        super.init(window: panel)

        if let screen = NSScreen.main {
            let x = (screen.frame.width - 640) / 2
            let y = (screen.frame.height - 520) / 2 + 100
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(with container: ModelContainer) {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmost
        }

        if currentContainer !== container || window?.contentView == nil {
            currentContainer = container
            let view = QuickCaptureView(
                onDismiss: { [weak self] in self?.dismiss() },
                modelContainer: container
            )
            let hostingView = TransparentHostingView(rootView: view)
            hostingView.wantsLayer = true
            hostingView.layer?.cornerRadius = 14
            hostingView.layer?.masksToBounds = true
            window?.contentView = hostingView
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        window?.orderOut(nil)
        NotificationCenter.default.post(name: .quickCaptureReset, object: nil)
        if let prev = previousApp {
            prev.activate()
        }
        previousApp = nil
    }

    func resetAndDismiss() {
        currentContainer = nil
        window?.contentView = nil
        dismiss()
    }

    func toggle(with container: ModelContainer) {
        if window?.isVisible == true {
            dismiss()
        } else {
            show(with: container)
        }
    }
}
