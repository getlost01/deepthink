import SwiftUI

struct AnalysisView: View {
    @State private var inputMode: InputMode = .command
    @State private var commandText = ""
    @State private var questionText = ""
    @State private var isRunning = false
    @State private var results: [AnalysisResultItem] = []
    @State private var selectedResultID: UUID?
    @State private var droppedFilePath: String?
    @FocusState private var commandFocused: Bool

    enum InputMode: String, CaseIterable {
        case command = "Command"
        case file = "File"
        case url = "URL"
        case data = "Data Analysis"
    }

    struct AnalysisResultItem: Identifiable {
        let id = UUID()
        let source: String
        let rawOutput: String
        let analysis: String
        let timestamp: Date
        let isError: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            // Input area
            VStack(spacing: DS.Spacing.md) {
                // Mode picker
                Picker("Mode", selection: $inputMode) {
                    ForEach(InputMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)

                // Input field
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: inputIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Colors.textTertiary)

                    TextField(inputPlaceholder, text: $commandText)
                        .textFieldStyle(.plain)
                        .font(inputMode == .command ? DS.Font.mono : DS.Font.body)
                        .focused($commandFocused)
                        .onSubmit { runAnalysis() }

                    if isRunning {
                        ProgressView().scaleEffect(0.7)
                    }

                    Button(action: runAnalysis) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(commandText.isEmpty ? Color.secondary.opacity(0.3) : DS.Colors.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(commandText.isEmpty || isRunning)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.Radius.md))

                // Optional question
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                    TextField("Ask a specific question about the output (optional)", text: $questionText)
                        .textFieldStyle(.plain)
                        .font(DS.Font.caption)
                }
                .padding(.horizontal, DS.Spacing.md)
            }
            .padding(DS.Spacing.xl)
            .background(.bar)

            Divider()

            if results.isEmpty {
                // Empty state with preset commands
                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        DSEmptyState(
                            icon: "wand.and.rays",
                            title: "Run Analysis",
                            subtitle: "Execute a command, open a file, or fetch a URL — then get AI insights"
                        )
                        .frame(height: 160)

                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            Text("Quick Analysis")
                                .font(DS.Font.heading)
                                .padding(.horizontal, DS.Spacing.xl)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                                ForEach(presetCommands, id: \.name) { preset in
                                    Button {
                                        commandText = preset.command
                                        inputMode = .command
                                        runAnalysis()
                                    } label: {
                                        HStack(spacing: DS.Spacing.sm) {
                                            Image(systemName: preset.icon)
                                                .font(.system(size: 12))
                                                .foregroundStyle(DS.Colors.accent)
                                                .frame(width: 24, height: 24)
                                                .background(DS.Colors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(preset.name)
                                                    .font(DS.Font.caption)
                                                    .fontWeight(.medium)
                                                Text(preset.description)
                                                    .font(DS.Font.tiny)
                                                    .foregroundStyle(DS.Colors.textTertiary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                        .padding(DS.Spacing.md)
                                        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, DS.Spacing.xl)
                        }
                    }
                    .padding(.top, DS.Spacing.xl)
                }
            } else {
                // Results list
                HSplitView {
                    // Left: result list
                    List(selection: $selectedResultID) {
                        ForEach(results) { result in
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text(result.source)
                                    .font(DS.Font.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text(result.timestamp, style: .time)
                                    .font(DS.Font.tiny)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            .tag(result.id)
                            .padding(.vertical, DS.Spacing.xs)
                        }
                    }
                    .listStyle(.inset)
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)

                    // Right: detail
                    if let result = results.first(where: { $0.id == selectedResultID }) {
                        AnalysisDetailView(result: result)
                    } else if let first = results.first {
                        AnalysisDetailView(result: first)
                    }
                }
            }
        }
        .onAppear { commandFocused = true }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers)
            return true
        }
    }

    private var inputIcon: String {
        switch inputMode {
        case .command: "terminal"
        case .file: "doc"
        case .url: "globe"
        case .data: "chart.bar"
        }
    }

    private var inputPlaceholder: String {
        switch inputMode {
        case .command: "Enter command to run and analyze..."
        case .file: "Enter file path to analyze..."
        case .url: "Enter URL to fetch and analyze..."
        case .data: "Enter CSV/JSON file path for data analysis..."
        }
    }

    private let presetCommands: [(name: String, command: String, icon: String, description: String)] = [
        ("Git Status", "git status && git log --oneline -10", "arrow.triangle.branch", "Repository status and recent commits"),
        ("Disk Usage", "df -h && du -sh * 2>/dev/null | sort -rh | head -20", "internaldrive", "Disk space overview"),
        ("Top Processes", "ps aux --sort=-%mem | head -20", "cpu", "Processes by memory usage"),
        ("Network", "lsof -i -P -n 2>/dev/null | head -30", "network", "Active network connections"),
        ("Docker", "docker ps -a 2>/dev/null && docker images 2>/dev/null | head -20", "shippingbox", "Docker containers and images"),
        ("System Info", "sw_vers && sysctl -n machdep.cpu.brand_string", "desktopcomputer", "macOS version and hardware"),
        ("Brew Health", "brew outdated 2>/dev/null && brew doctor 2>/dev/null | head -20", "mug", "Homebrew package status"),
        ("npm Audit", "npm audit 2>/dev/null || echo 'No package.json'", "shield", "Dependency vulnerabilities"),
        ("DeepThink Status", "deepthink status 2>/dev/null || echo 'CLI not set up'", "brain", "DeepThink CLI system status"),
        ("Memory Stats", "deepthink memory 2>/dev/null || echo 'CLI not set up'", "brain.head.profile", "Memory bank statistics"),
    ]

    private func runAnalysis() {
        guard !commandText.isEmpty else { return }
        isRunning = true
        let cmd = commandText
        let question = questionText.isEmpty ? nil : questionText
        let mode = inputMode

        Task {
            do {
                let rawOutput: String
                let source: String

                switch mode {
                case .command:
                    rawOutput = try await shellRun(cmd)
                    source = cmd
                case .file:
                    let url = URL(fileURLWithPath: cmd)
                    rawOutput = try String(contentsOf: url, encoding: .utf8)
                    source = "File: \(url.lastPathComponent)"
                case .url:
                    rawOutput = try await shellRun("curl -sL '\(cmd)' | head -500")
                    source = "URL: \(cmd)"
                case .data:
                    let cliResult = await DeepThinkCLIService.shared.analyze(
                        file: cmd,
                        withReport: true,
                        title: question ?? "Analysis"
                    )
                    rawOutput = cliResult.output
                    source = "Data: \((cmd as NSString).lastPathComponent)"
                }

                let analysis = try await ClaudeService.shared.analyzeCLIOutput(
                    rawOutput,
                    question: question
                )

                let item = AnalysisResultItem(
                    source: source,
                    rawOutput: String(rawOutput.prefix(5000)),
                    analysis: analysis,
                    timestamp: Date(),
                    isError: false
                )

                await MainActor.run {
                    results.insert(item, at: 0)
                    selectedResultID = item.id
                    isRunning = false
                    commandText = ""
                    questionText = ""
                }
            } catch {
                let item = AnalysisResultItem(
                    source: cmd,
                    rawOutput: "",
                    analysis: "Error: \(error.localizedDescription)",
                    timestamp: Date(),
                    isError: true
                )
                await MainActor.run {
                    results.insert(item, at: 0)
                    selectedResultID = item.id
                    isRunning = false
                }
            }
        }
    }

    private func shellRun(_ command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", command]

                var env = ProcessInfo.processInfo.environment
                env["TERM"] = "xterm-256color"
                process.environment = env

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    continuation.resume(returning: out + (err.isEmpty ? "" : "\nSTDERR:\n\(err)"))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    commandText = url.path
                    inputMode = .file
                }
            }
        }
    }
}

private struct AnalysisDetailView: View {
    let result: AnalysisView.AnalysisResultItem
    @State private var showRaw = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Text(result.source)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()

                Picker("", selection: $showRaw) {
                    Text("Analysis").tag(false)
                    Text("Raw Output").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Button {
                    let text = showRaw ? result.rawOutput : result.analysis
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)
            .background(.bar)

            Divider()

            ScrollView {
                if showRaw {
                    Text(result.rawOutput)
                        .font(DS.Font.mono)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.lg)
                } else {
                    if let attributed = try? AttributedString(markdown: result.analysis, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                        Text(attributed)
                            .font(DS.Font.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.Spacing.lg)
                    } else {
                        Text(result.analysis)
                            .font(DS.Font.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.Spacing.lg)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
