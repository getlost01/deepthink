import CryptoKit
import Foundation

@Observable
final class InstallationManager {
    static let shared = InstallationManager()

    enum StepState {
        case pending
        case running
        case done
        case skipped
        case failed(String)

        var isDone: Bool {
            if case .done = self { return true }
            if case .skipped = self { return true }
            return false
        }
    }

    var cliState: StepState = .pending
    var mcpState: StepState = .pending
    var pathState: StepState = .pending
    var mcpRegisterState: StepState = .pending
    var commandsState: StepState = .pending

    var isComplete: Bool {
        cliState.isDone && mcpState.isDone && pathState.isDone && mcpRegisterState.isDone && commandsState.isDone
    }

    private var didRun = false

    private init() {}

    func install() {
        guard !didRun else { return }
        didRun = true

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let installDir = DeepThinkPaths.localBin

            if !fm.fileExists(atPath: installDir) {
                try? fm.createDirectory(atPath: installDir, withIntermediateDirectories: true)
            }

            // ── CLI ──────────────────────────────────────────────────────────
            self.setState(\.cliState, .running)
            let cliOK = Self.installBinary(named: "deepthink-cli", as: "deepthink", fm: fm, installDir: installDir)
            self.setState(\.cliState, cliOK ? .done : .failed("Binary not found in app bundle"))

            // ── MCP ──────────────────────────────────────────────────────────
            self.setState(\.mcpState, .running)
            let mcpOK = Self.installBinary(named: "deepthink-mcp", as: "deepthink-mcp", fm: fm, installDir: installDir)
            self.setState(\.mcpState, mcpOK ? .done : .failed("Binary not found in app bundle"))

            // ── MCP config + global register ─────────────────────────────────
            let mcpBinPath = installDir + "/deepthink-mcp"
            Self.installMCPConfig(mcpBinaryPath: mcpBinPath)

            self.setState(\.mcpRegisterState, .running)
            let registered = Self.registerGlobalMCP(mcpBinaryPath: mcpBinPath)
            self.setState(\.mcpRegisterState, registered ? .done : .skipped)

            // ── PATH ─────────────────────────────────────────────────────────
            self.setState(\.pathState, .running)
            Self.ensureLocalBinInPath()
            self.setState(\.pathState, .done)

            // ── Claude Code slash commands ────────────────────────────────────
            self.setState(\.commandsState, .running)
            Self.installClaudeCommands()
            self.setState(\.commandsState, .done)

            StorageService.shared.writeLog("Installation complete", to: "app")
        }
    }

    private func setState<T>(_ keyPath: ReferenceWritableKeyPath<InstallationManager, T>, _ value: T) {
        DispatchQueue.main.async { self[keyPath: keyPath] = value }
    }

    // MARK: - Binary install

    @discardableResult
    private static func installBinary(named bundleName: String, as installName: String, fm: FileManager, installDir: String) -> Bool {
        let installPath = installDir + "/" + installName

        var sourcePath: String?
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent(bundleName).path,
           fm.isExecutableFile(atPath: bundled) {
            sourcePath = bundled
        } else {
            let devBase = Bundle.main.bundlePath
                .components(separatedBy: "/DeepThink.app").first ?? ""
            let devCandidates = [
                devBase + "/cli/out/" + installName,
                devBase + "/cli/" + installName
            ]
            sourcePath = devCandidates.first { fm.isExecutableFile(atPath: $0) }
        }

        guard let source = sourcePath else { return false }

        let sourceSize = (try? fm.attributesOfItem(atPath: source)[.size] as? Int) ?? -1
        let destSize = (try? fm.attributesOfItem(atPath: installPath)[.size] as? Int) ?? -2

        if sourceSize == destSize,
           let srcData = try? Data(contentsOf: URL(fileURLWithPath: source)),
           let dstData = try? Data(contentsOf: URL(fileURLWithPath: installPath)),
           SHA256.hash(data: srcData) == SHA256.hash(data: dstData) {
            return true
        }

        try? fm.removeItem(atPath: installPath)
        guard (try? fm.copyItem(atPath: source, toPath: installPath)) != nil else { return false }
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installPath)
        StorageService.shared.writeLog("\(installName) installed → \(installPath)", to: "app")
        return true
    }

    // MARK: - MCP config

    private static func installMCPConfig(mcpBinaryPath: String) {
        let configURL = StorageService.shared.baseURL.appendingPathComponent(".mcp.json")
        let config: [String: Any] = [
            "mcpServers": [
                "deepthink": ["command": mcpBinaryPath, "args": [] as [String]]
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) else { return }
        try? data.write(to: configURL)
    }

    @discardableResult
    private static func registerGlobalMCP(mcpBinaryPath: String) -> Bool {
        guard let claudePath = [
            DeepThinkPaths.localBin + "/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude"
        ].first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["mcp", "add", "--transport", "stdio", "--scope", "user", "deepthink", "--", mcpBinaryPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        let deadline = DispatchTime.now() + .seconds(10)
        DispatchQueue.global().asyncAfter(deadline: deadline) {
            if process.isRunning { process.terminate() }
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    // MARK: - Claude Code slash commands

    static func installClaudeCommands() {
        let commandsDir = NSHomeDirectory() + "/.claude/commands/deepthink"
        try? FileManager.default.createDirectory(atPath: commandsDir, withIntermediateDirectories: true)

        let commands: [(filename: String, content: String)] = [
            ("sync-session.md", syncSessionCommandContent)
        ]

        for command in commands {
            let path = commandsDir + "/" + command.filename
            let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            guard existing != command.content else { continue }
            try? command.content.write(toFile: path, atomically: true, encoding: .utf8)
        }

        StorageService.shared.writeLog("Claude Code commands installed → \(commandsDir)", to: "app")
    }

    private static let syncSessionCommandContent = #"""
    ---
    description: Capture the current Claude Code session to DeepThink — what was worked on, decisions made, files changed, and open items.
    ---

    Synthesize this Claude Code session and persist it to the DeepThink knowledge base.

    ## Step 1 — Gather context

    Run these shell commands to ground the summary in facts:

    ```bash
    git rev-parse --show-toplevel 2>/dev/null || pwd          # repo root
    git branch --show-current 2>/dev/null                     # current branch
    git log --oneline -10 2>/dev/null                         # recent commits
    git diff --stat HEAD 2>/dev/null                          # changed files
    date +%Y-%m-%d                                            # today's date
    ```

    Derive:
    - **project**: `basename` of the repo root (override with `$ARGUMENTS` if provided)
    - **branch**: current git branch (omit if not in a git repo)
    - **date**: from `date` command above

    ## Step 2 — Build the summary

    Use conversation history as the primary source; use git output to fill gaps or verify file names.
    Include only what actually happened — do not pad or invent.

    ```
    # Session: <date> — <one-line topic>

    **Project:** <project>
    **Branch:** <branch>
    **Date:** <date>

    ## What was worked on
    <bullet list — features, bugs, refactors, investigations>

    ## Key decisions
    <bullet list — architectural, approach, or design choices made>

    ## Files changed
    <bullet list — notable files created or modified with a short reason>

    ## Outcomes
    <what was completed, fixed, or shipped>

    ## Open items / follow-ups
    <unresolved work, deferred items, or follow-ups — "none" if clean>
    ```

    Omit any section with no content.

    ## Step 3 — Capture to DeepThink

    Call `mcp__deepthink__knowledge_capture` with:
    - `source`: `"claude-code"`
    - `channel`: project slug (lowercase, spaces as hyphens)
    - `content`: full markdown from Step 2
    - `title`: `"Session <date>: <one-line topic>"`
    - `tags`: `["session-log", "<project-slug>", "<date>", "<branch>"]` (omit branch tag if not in a git repo)

    ## Step 4 — Confirm

    On success, output one line:

    ```
    Saved → DeepThink / <channel>: "<title>"
    ```

    If the MCP tool is unavailable, print the full summary so nothing is lost:

    ```
    DeepThink MCP not connected. Session summary:

    <markdown from Step 2>
    ```
    """#

    // MARK: - PATH setup

    private static func ensureLocalBinInPath() {
        let localBin = DeepThinkPaths.localBin
        let exportLine = "\nexport PATH=\"\(localBin):$PATH\"\n"
        let marker = "# Added by DeepThink"
        let block = "\(marker)\n\(exportLine.trimmingCharacters(in: .newlines))\n"

        let shellFiles = [
            NSHomeDirectory() + "/.zshrc",
            NSHomeDirectory() + "/.bash_profile",
            NSHomeDirectory() + "/.bashrc"
        ]

        for filePath in shellFiles {
            let existing = (try? String(contentsOfFile: filePath, encoding: .utf8)) ?? ""
            guard !existing.contains(localBin) else { continue }
            let updated = existing + "\n" + block
            try? updated.write(toFile: filePath, atomically: true, encoding: .utf8)
        }
    }
}
