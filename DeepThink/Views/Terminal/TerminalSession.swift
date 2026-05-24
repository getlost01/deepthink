import Foundation
import SwiftTerm
import SwiftUI

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
        let home = NSHomeDirectory()
        let candidate = directory ?? (home + "/deepthink")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: candidate, isDirectory: &isDir), isDir.boolValue {
            currentDirectory = candidate
        } else {
            currentDirectory = home
        }
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
        extractAllLines().suffix(lastLines).joined(separator: "\n")
    }

    func getAllText() -> String {
        extractAllLines().joined(separator: "\n")
    }

    /// Reads all available buffer lines including scrollback.
    /// Uses getScrollInvariantLine with an estimated range anchor derived from
    /// the current display position. Works correctly when the user hasn't scrolled;
    /// for deeply-scrolled views in very long sessions it falls back to visible rows.
    private func extractAllLines() -> [String] {
        guard let terminal = terminalView?.getTerminal() else { return [] }
        let scrollback = terminal.options.scrollback
        let rows = terminal.rows
        // yDisp is the first visible line's index in the internal buffer.
        // When the scrollback is full: linesTop ≈ yDisp - scrollback.
        // The scroll-invariant start ≈ max(0, yDisp - scrollback).
        let estimatedStart = max(0, terminal.getTopVisibleRow() - scrollback)
        let capacity = scrollback + rows
        var lines: [String] = []
        lines.reserveCapacity(capacity)
        for row in estimatedStart..<(estimatedStart + capacity) {
            if let line = terminal.getScrollInvariantLine(row: row) {
                lines.append(line.translateToString(trimRight: true))
            }
        }
        // Fallback for very long sessions where the user has scrolled far up,
        // causing our estimate to miss the valid range entirely.
        if lines.isEmpty {
            for row in 0..<rows {
                if let line = terminal.getLine(row: row) {
                    lines.append(line.translateToString(trimRight: true))
                }
            }
        }
        return lines
    }
}
