import SwiftUI
import SwiftTerm

struct TerminalHostView: NSViewRepresentable {
    let session: TerminalSession
    var fontSize: CGFloat = 13

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let termView = LocalProcessTerminalView(frame: .zero)
        termView.processDelegate = context.coordinator

        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        termView.font = font
        termView.nativeForegroundColor = .white
        termView.nativeBackgroundColor = DS.Colors.terminalNS
        termView.optionAsMetaKey = true

        session.terminalView = termView
        session.start()

        return termView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Font or appearance updates can go here
    }

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
            }
        }
    }
}
