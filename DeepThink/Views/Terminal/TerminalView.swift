import SwiftUI

// MARK: - Terminal Tab Model

struct TerminalTab: Identifiable {
    let id = UUID()
    var title: String
    var outputLines: [TerminalLine] = []
    var currentDirectory: String = StorageService.shared.baseURL.path
    var commandHistory: [String] = []
    var historyIndex: Int = -1
    var isRunning: Bool = false
    var currentProcess: Process?
}

// MARK: - Terminal View

struct TerminalView: View {
    @State private var tabs: [TerminalTab] = [TerminalTab(title: "Terminal")]
    @State private var activeTabID: UUID?
    @State private var inputText = ""
    @State private var showClaudeMode = false
    @FocusState private var inputFocused: Bool

    private var activeTabIndex: Int? {
        tabs.firstIndex(where: { $0.id == activeTabID })
    }

    private var activeTab: TerminalTab? {
        guard let idx = activeTabIndex else { return nil }
        return tabs[idx]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: tab strip + controls
            HStack(spacing: 0) {
                // Tab strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(tabs) { tab in
                            TerminalTabButton(
                                tab: tab,
                                isActive: tab.id == activeTabID,
                                canClose: tabs.count > 1,
                                onSelect: {
                                    activeTabID = tab.id
                                    inputText = ""
                                },
                                onClose: {
                                    closeTab(tab.id)
                                }
                            )
                        }
                        // Add tab button
                        Button { addTab() } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Colors.textTertiary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                }

                Spacer()

                // Controls: analyze, explain error, Claude toggle, clear, stop
                HStack(spacing: DS.Spacing.sm) {
                    Button {
                        analyzeLastOutput()
                    } label: {
                        Image(systemName: "wand.and.rays")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Analyze last output with AI")
                    .disabled(activeTab?.outputLines.isEmpty ?? true)

                    Button {
                        explainLastError()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Explain last error")
                    .disabled(!(activeTab?.outputLines.contains(where: { $0.type == .error }) ?? false))

                    Toggle(isOn: $showClaudeMode) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "brain.head.profile")
                            Text("Claude")
                        }
                        .font(DS.Font.caption)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                    Button {
                        guard let idx = activeTabIndex else { return }
                        tabs[idx].outputLines.removeAll()
                    } label: {
                        Image(systemName: "trash")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear terminal")

                    if activeTab?.isRunning == true {
                        Button {
                            guard let idx = activeTabIndex else { return }
                            tabs[idx].currentProcess?.terminate()
                            tabs[idx].currentProcess = nil
                            tabs[idx].isRunning = false
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .foregroundStyle(.red)
                                .font(DS.Font.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Stop process")
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
            }
            .padding(.vertical, DS.Spacing.sm)
            .background(.bar)

            Divider()

            // Terminal output for active tab
            if let idx = activeTabIndex {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(tabs[idx].outputLines) { line in
                                TerminalLineView(line: line)
                                    .id(line.id)
                            }
                        }
                        .padding(DS.Spacing.md)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .onChange(of: tabs[idx].outputLines.count) {
                        if let last = tabs[idx].outputLines.last {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input area
                HStack(spacing: DS.Spacing.sm) {
                    Text(shortenPath(tabs[idx].currentDirectory))
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(.green.opacity(0.7))
                        .lineLimit(1)

                    Text("❯")
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(.cyan.opacity(0.8))

                    TextField("Enter command...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .focused($inputFocused)
                        .onSubmit { executeCommand() }
                        .disabled(tabs[idx].isRunning)
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
                            guard let i = activeTabIndex, tabs[i].isRunning else { return .ignored }
                            tabs[i].currentProcess?.terminate()
                            tabs[i].currentProcess = nil
                            tabs[i].isRunning = false
                            tabs[i].outputLines.append(TerminalLine(text: "^C", type: .error))
                            return .handled
                        }

                    if tabs[idx].isRunning {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(.bar)
            }
        }
        .navigationTitle("Terminal")
        .onAppear {
            if activeTabID == nil, let first = tabs.first {
                activeTabID = first.id
            }
            if let idx = activeTabIndex, tabs[idx].outputLines.isEmpty {
                tabs[idx].outputLines.append(TerminalLine(text: "DeepThink Terminal", type: .info))
                tabs[idx].outputLines.append(TerminalLine(text: "↑↓ history • Ctrl+C cancel • Claude toggle for AI-assisted commands", type: .info))
                tabs[idx].outputLines.append(TerminalLine(text: "Type 'dt <command>' for DeepThink CLI (dt recall, dt remember, dt ask, dt status)", type: .info))
            }
            inputFocused = true
        }
    }

    // MARK: - Tab Management

    private func addTab() {
        let newTab = TerminalTab(title: "Terminal \(tabs.count + 1)")
        tabs.append(newTab)
        activeTabID = newTab.id
        inputText = ""

        if let idx = tabs.firstIndex(where: { $0.id == newTab.id }) {
            tabs[idx].outputLines.append(TerminalLine(text: "DeepThink Terminal", type: .info))
            tabs[idx].outputLines.append(TerminalLine(text: "↑↓ history • Ctrl+C cancel • Claude toggle for AI-assisted commands", type: .info))
            tabs[idx].outputLines.append(TerminalLine(text: "Type 'dt <command>' for DeepThink CLI", type: .info))
        }
        inputFocused = true
    }

    private func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return }
        guard let closingIndex = tabs.firstIndex(where: { $0.id == id }) else { return }

        // Terminate any running process
        tabs[closingIndex].currentProcess?.terminate()

        let wasActive = (id == activeTabID)
        tabs.remove(at: closingIndex)

        if wasActive {
            // Switch to next tab, or previous if we closed the last one
            let newIndex = min(closingIndex, tabs.count - 1)
            activeTabID = tabs[newIndex].id
            inputText = ""
        }
    }

    private func tabTitle(for tab: TerminalTab) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if tab.currentDirectory == home {
            return "Terminal"
        }
        return (tab.currentDirectory as NSString).lastPathComponent
    }

    // MARK: - History Navigation

    private enum HistoryDirection { case up, down }

    private func navigateHistory(direction: HistoryDirection) {
        guard let idx = activeTabIndex else { return }
        guard !tabs[idx].commandHistory.isEmpty else { return }
        switch direction {
        case .up:
            if tabs[idx].historyIndex < tabs[idx].commandHistory.count - 1 {
                tabs[idx].historyIndex += 1
            }
        case .down:
            if tabs[idx].historyIndex > 0 {
                tabs[idx].historyIndex -= 1
            } else {
                tabs[idx].historyIndex = -1
                inputText = ""
                return
            }
        }
        let hi = tabs[idx].historyIndex
        if hi >= 0, hi < tabs[idx].commandHistory.count {
            inputText = tabs[idx].commandHistory[tabs[idx].commandHistory.count - 1 - hi]
        }
    }

    // MARK: - Command Execution

    private func executeCommand() {
        guard let idx = activeTabIndex else { return }
        let command = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }

        tabs[idx].commandHistory.append(command)
        tabs[idx].historyIndex = -1
        tabs[idx].outputLines.append(TerminalLine(text: "\(shortenPath(tabs[idx].currentDirectory)) ❯ \(command)", type: .prompt))
        inputText = ""

        if command.hasPrefix("cd ") {
            handleCd(command, tabIndex: idx)
            return
        }
        if command == "cd" {
            tabs[idx].currentDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            return
        }
        if command == "clear" {
            tabs[idx].outputLines.removeAll()
            return
        }
        if command == "history" {
            for (i, cmd) in tabs[idx].commandHistory.enumerated() {
                tabs[idx].outputLines.append(TerminalLine(text: "  \(i + 1)  \(cmd)", type: .output))
            }
            return
        }
        if command.hasPrefix("dt ") || command == "dt" {
            executeDeepThink(command, tabIndex: idx)
            return
        }

        if showClaudeMode {
            executeClaudeAssisted(command, tabIndex: idx)
        } else {
            executeShell(command, tabIndex: idx)
        }
    }

    private func executeShell(_ command: String, tabIndex idx: Int) {
        let tabID = tabs[idx].id
        tabs[idx].isRunning = true
        let dir = tabs[idx].currentDirectory

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

            await MainActor.run {
                guard let i = tabs.firstIndex(where: { $0.id == tabID }) else { return }
                tabs[i].currentProcess = process
            }

            do {
                try process.run()
                process.waitUntilExit()

                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: outData, encoding: .utf8) ?? ""
                let stderr = String(data: errData, encoding: .utf8) ?? ""

                await MainActor.run {
                    guard let i = tabs.firstIndex(where: { $0.id == tabID }) else { return }
                    if !stdout.isEmpty {
                        for line in stdout.split(separator: "\n", omittingEmptySubsequences: false) {
                            tabs[i].outputLines.append(TerminalLine(text: String(line), type: .output))
                        }
                    }
                    if !stderr.isEmpty {
                        for line in stderr.split(separator: "\n", omittingEmptySubsequences: false) {
                            tabs[i].outputLines.append(TerminalLine(text: String(line), type: .error))
                        }
                    }
                    if process.terminationStatus != 0 {
                        tabs[i].outputLines.append(TerminalLine(text: "exit code: \(process.terminationStatus)", type: .error))
                    }
                    tabs[i].isRunning = false
                    tabs[i].currentProcess = nil
                    trimOutput(tabIndex: i)
                }
            } catch {
                await MainActor.run {
                    guard let i = tabs.firstIndex(where: { $0.id == tabID }) else { return }
                    tabs[i].outputLines.append(TerminalLine(text: "Error: \(error.localizedDescription)", type: .error))
                    tabs[i].isRunning = false
                    tabs[i].currentProcess = nil
                }
            }
        }
    }

    private func executeClaudeAssisted(_ command: String, tabIndex idx: Int) {
        let tabID = tabs[idx].id
        tabs[idx].isRunning = true
        tabs[idx].outputLines.append(TerminalLine(text: "🧠 Sending to Claude...", type: .info))

        Task {
            do {
                let dir = tabs[idx].currentDirectory
                let response = try await ClaudeService.shared.query(
                    command,
                    systemPrompt: "You are a terminal assistant. The user's current directory is: \(dir). Answer questions, suggest commands, or help debug errors. Be concise. If the user asks you to run something, provide the command they should run."
                )
                await MainActor.run {
                    guard let i = tabs.firstIndex(where: { $0.id == tabID }) else { return }
                    for line in response.split(separator: "\n", omittingEmptySubsequences: false) {
                        tabs[i].outputLines.append(TerminalLine(text: String(line), type: .ai))
                    }
                    tabs[i].isRunning = false
                }
            } catch {
                await MainActor.run {
                    guard let i = tabs.firstIndex(where: { $0.id == tabID }) else { return }
                    tabs[i].outputLines.append(TerminalLine(text: "Claude error: \(error.localizedDescription)", type: .error))
                    tabs[i].isRunning = false
                }
            }
        }
    }

    private func executeDeepThink(_ command: String, tabIndex idx: Int) {
        let tabID = tabs[idx].id
        tabs[idx].isRunning = true
        tabs[idx].outputLines.append(TerminalLine(text: "⚡ DeepThink CLI...", type: .info))

        let args: [String]
        if command == "dt" {
            args = ["--help"]
        } else {
            args = Array(command.dropFirst(3).split(separator: " ").map(String.init))
        }

        Task {
            let result = await DeepThinkCLIService.shared.run(args)
            await MainActor.run {
                guard let i = tabs.firstIndex(where: { $0.id == tabID }) else { return }
                if result.success {
                    for line in result.output.split(separator: "\n", omittingEmptySubsequences: false) {
                        tabs[i].outputLines.append(TerminalLine(text: String(line), type: .ai))
                    }
                } else {
                    tabs[i].outputLines.append(TerminalLine(text: result.error, type: .error))
                }
                tabs[i].isRunning = false
            }
        }
    }

    private func handleCd(_ command: String, tabIndex idx: Int) {
        let path = String(command.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved: String
        if path.hasPrefix("/") {
            resolved = path
        } else if path.hasPrefix("~") {
            resolved = path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
        } else if path == ".." {
            resolved = (tabs[idx].currentDirectory as NSString).deletingLastPathComponent
        } else {
            resolved = (tabs[idx].currentDirectory as NSString).appendingPathComponent(path)
        }

        let standardized = (resolved as NSString).standardizingPath
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: standardized, isDirectory: &isDir), isDir.boolValue {
            tabs[idx].currentDirectory = standardized
        } else {
            tabs[idx].outputLines.append(TerminalLine(text: "cd: no such directory: \(path)", type: .error))
        }
    }

    private func trimOutput(tabIndex idx: Int) {
        if tabs[idx].outputLines.count > 10_000 {
            tabs[idx].outputLines.removeFirst(tabs[idx].outputLines.count - 10_000)
        }
    }

    private func analyzeLastOutput() {
        guard let tabIndex = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        let output = tabs[tabIndex].outputLines
            .filter { $0.type == .output || $0.type == .prompt }
            .suffix(50)
            .map(\.text)
            .joined(separator: "\n")
        guard !output.isEmpty else { return }

        tabs[tabIndex].outputLines.append(TerminalLine(text: "Analyzing output...", type: .info))

        Task {
            do {
                let analysis = try await ClaudeService.shared.analyzeCLIOutput(output)
                await MainActor.run {
                    guard let idx = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
                    tabs[idx].outputLines.append(TerminalLine(text: "── AI Analysis ──", type: .info))
                    for line in analysis.split(separator: "\n", omittingEmptySubsequences: false) {
                        tabs[idx].outputLines.append(TerminalLine(text: String(line), type: .ai))
                    }
                }
            } catch {
                await MainActor.run {
                    guard let idx = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
                    tabs[idx].outputLines.append(TerminalLine(text: "Analysis error: \(error.localizedDescription)", type: .error))
                }
            }
        }
    }

    private func explainLastError() {
        guard let tabIndex = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        let errorLines = tabs[tabIndex].outputLines
            .filter { $0.type == .error }
            .suffix(20)
            .map(\.text)
            .joined(separator: "\n")
        guard !errorLines.isEmpty else { return }

        // Find the last command
        let lastCommand = tabs[tabIndex].outputLines
            .last(where: { $0.type == .prompt })?.text ?? "unknown"

        tabs[tabIndex].outputLines.append(TerminalLine(text: "Explaining error...", type: .info))

        Task {
            do {
                let explanation = try await ClaudeService.shared.explainError(
                    lastCommand, stderr: errorLines, exitCode: 1
                )
                await MainActor.run {
                    guard let idx = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
                    tabs[idx].outputLines.append(TerminalLine(text: "── Error Explanation ──", type: .info))
                    for line in explanation.split(separator: "\n", omittingEmptySubsequences: false) {
                        tabs[idx].outputLines.append(TerminalLine(text: String(line), type: .ai))
                    }
                }
            } catch {
                await MainActor.run {
                    guard let idx = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
                    tabs[idx].outputLines.append(TerminalLine(text: "Error: \(error.localizedDescription)", type: .error))
                }
            }
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

// MARK: - Terminal Tab Button

private struct TerminalTabButton: View {
    let tab: TerminalTab
    let isActive: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "terminal")
                    .font(.system(size: 10))
                Text(displayTitle)
                    .font(DS.Font.caption)
                    .lineLimit(1)
                if canClose && (isActive || isHovered) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isActive
                    ? DS.Colors.accent.opacity(0.1)
                    : (isHovered ? Color.primary.opacity(0.04) : .clear),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
            .foregroundStyle(isActive ? DS.Colors.textPrimary : DS.Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var displayTitle: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if tab.currentDirectory == home {
            return tab.title
        }
        return (tab.currentDirectory as NSString).lastPathComponent
    }
}

// MARK: - Terminal Line Model

struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let type: LineType

    enum LineType {
        case prompt, output, error, info, ai
    }
}

// MARK: - Terminal Line View

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
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                        .foregroundStyle(DS.Colors.accent)
                    Text(line.text)
                        .foregroundStyle(DS.Colors.accent)
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
