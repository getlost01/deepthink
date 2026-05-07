import SwiftTerm
import SwiftUI

struct TerminalHostView: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> NSView {
        let wrapper = NSView(frame: .zero)

        let termView: LocalProcessTerminalView
        if let existing = session.terminalView {
            termView = existing
        } else {
            termView = LocalProcessTerminalView(frame: .zero)
            termView.processDelegate = context.coordinator
            let font = NSFont.monospacedSystemFont(ofSize: session.fontSize, weight: .regular)
            termView.font = font
            termView.nativeForegroundColor = .white
            termView.nativeBackgroundColor = DS.Colors.terminalNS
            termView.optionAsMetaKey = true
            session.terminalView = termView
            session.start()
        }

        termView.removeFromSuperview()
        termView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(termView)
        NSLayoutConstraint.activate([
            termView.topAnchor.constraint(equalTo: wrapper.topAnchor),
            termView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            termView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            termView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor)
        ])

        return wrapper
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let session: TerminalSession

        init(session: TerminalSession) {
            self.session = session
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            Task { @MainActor in
                self.session.title = title.isEmpty ? "Terminal" : String(title.prefix(30))
            }
        }

        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
            if let dir = directory {
                Task { @MainActor in
                    self.session.currentDirectory = dir
                }
            }
        }

        func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
            Task { @MainActor in
                self.session.isRunning = false
                self.session.onProcessExit?()
            }
        }
    }
}
