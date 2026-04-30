import SwiftUI

struct TerminalView: View {
    @State private var outputLines: [TerminalLine] = []
    @State private var inputText = ""
    @State private var currentDirectory = StorageService.shared.baseURL.path
    @State private var isRunning = false
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int = -1
    @State private var currentProcess: Process?
    @State private var showClaudeMode = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer()
                Toggle(isOn: $showClaudeMode) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                        Text("Claude")
                    }
                    .font(.caption)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)

                Button {
                    outputLines.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Clear terminal")

                if isRunning {
                    Button {
                        currentProcess?.terminate()
                        currentProcess = nil
                        isRunning = false
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Stop process")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(outputLines) { line in
                            TerminalLineView(line: line)
                                .id(line.id)
                        }
                    }
                    .padding(12)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: outputLines.count) {
                    if let last = outputLines.last {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Text(shortenPath(currentDirectory))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.green.opacity(0.8))
                    .lineLimit(1)

                Text("❯")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.cyan)

                TextField("Enter command...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($inputFocused)
                    .onSubmit { executeCommand() }
                    .disabled(isRunning)
                    .onKeyPress(.upArrow) {
                        navigateHistory(direction: .up)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        navigateHistory(direction: .down)
                        return .handled
                    }
                    .onKeyPress(characters: CharacterSet(charactersIn: "c"), phases: .down) { press in
                        guard press.modifiers.contains(.control) else { return .ignored }
                        if isRunning {
                            currentProcess?.terminate()
                            currentProcess = nil
                            isRunning = false
                            outputLines.append(TerminalLine(text: "^C", type: .error))
                        }
                        return .handled
                    }

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationTitle("Terminal")
        .onAppear {
            if outputLines.isEmpty {
                outputLines.append(TerminalLine(text: "DeepThink Terminal", type: .info))
                outputLines.append(TerminalLine(text: "↑↓ history • Ctrl+C cancel • Claude toggle for AI-assisted commands", type: .info))
            }
            inputFocused = true
        }
    }

    private enum HistoryDirection { case up, down }

    private func navigateHistory(direction: HistoryDirection) {
        guard !commandHistory.isEmpty else { return }
        switch direction {
        case .up:
            if historyIndex < commandHistory.count - 1 {
                historyIndex += 1
            }
        case .down:
            if historyIndex > 0 {
                historyIndex -= 1
            } else {
                historyIndex = -1
                inputText = ""
                return
            }
        }
        if historyIndex >= 0, historyIndex < commandHistory.count {
            inputText = commandHistory[commandHistory.count - 1 - historyIndex]
        }
    }

    private func executeCommand() {
        let command = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }

        commandHistory.append(command)
        historyIndex = -1
        outputLines.append(TerminalLine(text: "\(shortenPath(currentDirectory)) ❯ \(command)", type: .prompt))
        inputText = ""

        if command.hasPrefix("cd ") {
            handleCd(command)
            return
        }
        if command == "cd" {
            currentDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            return
        }
        if command == "clear" {
            outputLines.removeAll()
            return
        }
        if command == "history" {
            for (i, cmd) in commandHistory.enumerated() {
                outputLines.append(TerminalLine(text: "  \(i + 1)  \(cmd)", type: .output))
            }
            return
        }

        if showClaudeMode {
            executeClaudeAssisted(command)
        } else {
            executeShell(command)
        }
    }

    private func executeShell(_ command: String) {
        isRunning = true
        let dir = currentDirectory

        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", command]
            process.currentDirectoryURL = URL(fileURLWithPath: dir)

            var env = ProcessInfo.processInfo.environment
            env["TERM"] = "xterm-256color"
            process.environment = env

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            await MainActor.run { currentProcess = process }

            do {
                try process.run()
                process.waitUntilExit()

                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: outData, encoding: .utf8) ?? ""
                let stderr = String(data: errData, encoding: .utf8) ?? ""

                await MainActor.run {
                    if !stdout.isEmpty {
                        for line in stdout.split(separator: "\n", omittingEmptySubsequences: false) {
                            outputLines.append(TerminalLine(text: String(line), type: .output))
                        }
                    }
                    if !stderr.isEmpty {
                        for line in stderr.split(separator: "\n", omittingEmptySubsequences: false) {
                            outputLines.append(TerminalLine(text: String(line), type: .error))
                        }
                    }
                    if process.terminationStatus != 0 {
                        outputLines.append(TerminalLine(text: "exit code: \(process.terminationStatus)", type: .error))
                    }
                    isRunning = false
                    currentProcess = nil
                    trimOutput()
                }
            } catch {
                await MainActor.run {
                    outputLines.append(TerminalLine(text: "Error: \(error.localizedDescription)", type: .error))
                    isRunning = false
                    currentProcess = nil
                }
            }
        }
    }

    private func executeClaudeAssisted(_ command: String) {
        isRunning = true
        outputLines.append(TerminalLine(text: "🧠 Sending to Claude...", type: .info))

        Task {
            do {
                let response = try await ClaudeService.shared.query(
                    command,
                    systemPrompt: "You are a terminal assistant. The user's current directory is: \(currentDirectory). Answer questions, suggest commands, or help debug errors. Be concise. If the user asks you to run something, provide the command they should run."
                )
                await MainActor.run {
                    for line in response.split(separator: "\n", omittingEmptySubsequences: false) {
                        outputLines.append(TerminalLine(text: String(line), type: .ai))
                    }
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    outputLines.append(TerminalLine(text: "Claude error: \(error.localizedDescription)", type: .error))
                    isRunning = false
                }
            }
        }
    }

    private func handleCd(_ command: String) {
        let path = String(command.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved: String
        if path.hasPrefix("/") {
            resolved = path
        } else if path.hasPrefix("~") {
            resolved = path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
        } else if path == ".." {
            resolved = (currentDirectory as NSString).deletingLastPathComponent
        } else {
            resolved = (currentDirectory as NSString).appendingPathComponent(path)
        }

        let standardized = (resolved as NSString).standardizingPath
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: standardized, isDirectory: &isDir), isDir.boolValue {
            currentDirectory = standardized
        } else {
            outputLines.append(TerminalLine(text: "cd: no such directory: \(path)", type: .error))
        }
    }

    private func trimOutput() {
        if outputLines.count > 10_000 {
            outputLines.removeFirst(outputLines.count - 10_000)
        }
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let type: LineType

    enum LineType {
        case prompt, output, error, info, ai
    }
}

private struct TerminalLineView: View {
    let line: TerminalLine

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            switch line.type {
            case .prompt:
                Text(line.text)
                    .foregroundStyle(.green)
            case .error:
                Text(line.text)
                    .foregroundStyle(.red)
            case .info:
                Text(line.text)
                    .foregroundStyle(.secondary)
            case .ai:
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text(line.text)
                        .foregroundStyle(.purple)
                }
            case .output:
                Text(line.text)
                    .foregroundStyle(.primary)
            }
        }
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
    }
}
