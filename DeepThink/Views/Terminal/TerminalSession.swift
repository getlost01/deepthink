import Foundation
import SwiftUI
import SwiftTerm

@Observable
final class TerminalSession: Identifiable {
    let id = UUID()
    var title: String
    var currentDirectory: String
    var isRunning: Bool = false
    var terminalView: LocalProcessTerminalView?
    var fontSize: CGFloat = 13
    var onProcessExit: (() -> Void)?

    init(title: String, directory: String? = nil) {
        self.title = title
        self.currentDirectory = directory ?? NSHomeDirectory() + "/deepthink"
    }

    func start() {
        guard let terminalView, !isRunning else { return }

        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append("LANG=en_US.UTF-8")

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        terminalView.startProcess(
            executable: shell,
            args: ["-l"],
            environment: env,
            execName: "-" + (shell as NSString).lastPathComponent,
            currentDirectory: currentDirectory
        )
        isRunning = true
    }

    func terminate() {
        terminalView?.terminate()
        isRunning = false
    }

    func updateFontSize(_ newSize: CGFloat) {
        fontSize = max(9, min(24, newSize))
        if let tv = terminalView {
            let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            tv.font = font
        }
    }

    func getTextBuffer(lastLines: Int = 50) -> String {
        guard let terminal = terminalView?.getTerminal() else { return "" }
        var lines: [String] = []
        let totalRows = terminal.rows
        let start = max(0, totalRows - lastLines)
        for row in start..<totalRows {
            if let line = terminal.getLine(row: row) {
                lines.append(line.translateToString(trimRight: true))
            }
        }
        return lines.joined(separator: "\n")
    }

    func getAllText() -> String {
        guard let terminal = terminalView?.getTerminal() else { return "" }
        var lines: [String] = []
        let totalRows = terminal.rows
        for row in 0..<totalRows {
            if let line = terminal.getLine(row: row) {
                lines.append(line.translateToString(trimRight: true))
            }
        }
        return lines.joined(separator: "\n")
    }
}
