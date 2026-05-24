import CryptoKit
import Foundation
import SwiftData

@Observable
final class MCPService {
    static let shared = MCPService()

    var isRunning = false
    var lastError: String?
    var isGlobalMCPRegistered = false
    var isCheckingGlobalMCP = false
    var isCLIInstalled = false
    var isMCPInstalled = false
    var cliVersion: String?
    var mcpVersion: String?
    var isGlobalSkillInstalled = false

    static let cliInstallPath = DeepThinkPaths.localBin + "/deepthink"
    static let mcpInstallPath = DeepThinkPaths.localBin + "/deepthink-mcp"
    static let globalSkillPath = "\(NSHomeDirectory())/.claude/commands/deepthink.md"

    func checkGlobalMCPStatus() {
        let fm = FileManager.default
        isCLIInstalled = fm.isExecutableFile(atPath: Self.cliInstallPath)
        isMCPInstalled = fm.isExecutableFile(atPath: Self.mcpInstallPath)
        isGlobalSkillInstalled = fm.fileExists(atPath: Self.globalSkillPath)

        if isCLIInstalled { fetchVersion(path: Self.cliInstallPath) { self.cliVersion = $0 } } else { cliVersion = nil }
        if isMCPInstalled { fetchVersion(path: Self.mcpInstallPath) { self.mcpVersion = $0 } } else { mcpVersion = nil }

        let claudePath = ClaudeService.shared.claudePath
        guard !claudePath.isEmpty else {
            isGlobalMCPRegistered = false
            isCheckingGlobalMCP = false
            return
        }

        isCheckingGlobalMCP = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: claudePath)
            process.arguments = ["mcp", "list"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            try? process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let found = output.lowercased().contains("deepthink")

            DispatchQueue.main.async {
                self?.isGlobalMCPRegistered = found
                self?.isCheckingGlobalMCP = false
            }
        }
    }

    private func fetchVersion(path: String, completion: @escaping @Sendable (String?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["--version"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            try? process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async { completion(version?.isEmpty == false ? version : nil) }
        }
    }

    func installGlobalSkill() {
        DispatchQueue.global(qos: .utility).async {
            self._installGlobalSkill()
        }
    }

    private func _installGlobalSkill() {
        let fm = FileManager.default
        let skillURL = URL(fileURLWithPath: Self.globalSkillPath)
        let commandsDir = skillURL.deletingLastPathComponent()
        try? fm.createDirectory(at: commandsDir, withIntermediateDirectories: true)

        let content = """
        ---
        description: DeepThink universal assistant. Single entry point for knowledge, tasks, notes, projects, agents, skills, and rules. Routes any query — search, capture, CRUD, summarize, or reason — to the right tool.
        ---

        Route `$ARGUMENTS` to the best `mcp__deepthink__*` tool. Call directly when intent is clear. When ambiguous, call `mcp__deepthink__workspace_context` first, then decide.

        ## Route map

        All tools called as `mcp__deepthink__<tool>`.

        | Intent signals | Tool |
        |---|---|
        | **Search / retrieve** | |
        | search / find / look for / do I have / any notes on / show me / where is | `unified_search` |
        | what do I know about / context on / brief me on / catch me up | `knowledge_context` |
        | knowledge stats / how much stored / how many items | `knowledge_stats` |
        | **Knowledge** | |
        | save / capture / remember / store / log / keep / record / note this | `knowledge_capture` |
        | load project knowledge / context for project | `knowledge_load_project` |
        | **Workspace** | |
        | summary / overview / digest / status / what's going on | `workspace_summary` |
        | **Tasks** | |
        | tasks / todos / pending / what's next / backlog / in progress | `workspace_list_tasks` |
        | add task / new task / create task | `workspace_create_task` |
        | update task / mark done / complete / change task | `workspace_update_task` |
        | delete task / remove task | `workspace_delete_task` |
        | show task / get task details | `workspace_get_task` |
        | **Notes** | |
        | notes / my notes / show notes / what did I write | `workspace_list_notes` |
        | new note / create note / add note / jot down | `workspace_create_note` |
        | update note / edit note | `workspace_update_note` |
        | delete note / remove note | `workspace_delete_note` |
        | **Projects** | |
        | projects / active projects / project status | `workspace_list_projects` |
        | new project / create project | `workspace_create_project` |
        | update project / rename project | `workspace_update_project` |
        | delete project | `workspace_delete_project` |
        | **Reminders** | |
        | reminders / upcoming / what's scheduled | `workspace_list_reminders` |
        | remind me / set reminder / don't forget | `workspace_create_reminder` |
        | update reminder / reschedule | `workspace_update_reminder` |
        | delete reminder / cancel reminder | `workspace_delete_reminder` |
        | **Agents / Skills / Rules** | |
        | agents / my agents | `agent_list` |
        | create agent / new agent | `agent_create` |
        | skills / my skills | `skill_list` |
        | create skill / new skill | `skill_create` |
        | rules / my rules | `rule_list` |
        | create rule / new rule | `rule_create` |
        | **Reasoning** | |
        | what / why / how / explain / analyze / compare / suggest / help me think / ideas | `smart_query` |
        | **Overview** | |
        | what can you do / help / overview / what is deepthink | `deepthink_overview` |

        ## When intent is unclear
        1. Call `mcp__deepthink__workspace_context` — get current workspace state
        2. Re-evaluate which tool fits
        3. For complex or open-ended queries, call `mcp__deepthink__smart_query` with user input + context

        ## Multi-step
        Chain calls for compound requests:
        - "Search X then summarize" → `unified_search` → `smart_query` with results
        - "Create a task and a reminder" → `workspace_create_task` → `workspace_create_reminder`
        - "Find notes on X and update the project" → `unified_search` → `workspace_update_project`

        ## Output
        Return tool results directly. No preamble. No tool-name explanation.
        """

        let newData = Data(content.utf8)
        let newHash = SHA256.hash(data: newData).description
        let existingHash = (try? Data(contentsOf: skillURL)).map { SHA256.hash(data: $0).description }

        if existingHash != newHash {
            try? newData.write(to: skillURL, options: .atomic)
        }

        InstallationManager.installClaudeCommands()

        let installed = fm.fileExists(atPath: Self.globalSkillPath)
        DispatchQueue.main.async { self.isGlobalSkillInstalled = installed }
    }

    func registerGlobalMCP() {
        let mcpPath = Self.mcpInstallPath
        let claudePath = ClaudeService.shared.claudePath
        guard !claudePath.isEmpty else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: claudePath)
            process.arguments = ["mcp", "add", "--transport", "stdio", "--scope", "user", "deepthink", "--", mcpPath]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()

            DispatchQueue.main.async {
                self?.checkGlobalMCPStatus()
            }
        }
    }

    func generateMCPConfig(servers: [MCPServer]) -> String {
        var config: [String: Any] = [:]
        var mcpServers: [String: Any] = [:]

        for server in servers where server.isEnabled {
            mcpServers[server.name] = server.mcpConfigJSON
        }

        config["mcpServers"] = mcpServers

        guard let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return json
    }

    func writeMCPConfig(servers: [MCPServer]) -> URL? {
        let config = generateMCPConfig(servers: servers)
        let configURL = StorageService.shared.mcpTempConfigFile

        do {
            try config.write(to: configURL, atomically: true, encoding: .utf8)
            return configURL
        } catch {
            lastError = "Failed to write MCP config: \(error.localizedDescription)"
            return nil
        }
    }

    func queryWithMCP(prompt: String, servers: [MCPServer], systemPrompt: String? = nil) async throws -> String {
        let enabledServers = servers.filter(\.isEnabled)

        guard !enabledServers.isEmpty else {
            return try await ClaudeService.shared.query(prompt, systemPrompt: systemPrompt)
        }

        guard ClaudeService.shared.isAvailable else {
            throw ClaudeError.notInstalled
        }

        guard let configURL = writeMCPConfig(servers: enabledServers) else {
            throw ClaudeError.cliError("Failed to generate MCP config")
        }

        await MainActor.run { isRunning = true; lastError = nil }

        do {
            let result = try await runClaudeWithMCP(
                prompt: prompt,
                configPath: configURL.path,
                systemPrompt: systemPrompt
            )
            await MainActor.run { isRunning = false }
            return result
        } catch {
            await MainActor.run { isRunning = false; lastError = error.localizedDescription }
            throw error
        }
    }

    func streamQueryWithMCP(
        prompt: String,
        servers: [MCPServer],
        systemPrompt: String? = nil,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let enabledServers = servers.filter(\.isEnabled)

        guard !enabledServers.isEmpty else {
            return try await ClaudeService.shared.streamQuery(prompt, systemPrompt: systemPrompt, onToken: onToken)
        }

        guard ClaudeService.shared.isAvailable else {
            throw ClaudeError.notInstalled
        }

        guard let configURL = writeMCPConfig(servers: enabledServers) else {
            throw ClaudeError.cliError("Failed to generate MCP config")
        }

        await MainActor.run { isRunning = true; lastError = nil }

        do {
            let result = try await runClaudeWithMCPStreaming(
                prompt: prompt,
                configPath: configURL.path,
                systemPrompt: systemPrompt,
                onToken: onToken
            )
            await MainActor.run { isRunning = false }
            return result
        } catch {
            await MainActor.run { isRunning = false; lastError = error.localizedDescription }
            throw error
        }
    }

    private func runClaudeWithMCPStreaming(
        prompt: String,
        configPath: String,
        systemPrompt: String?,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let claudePath = ClaudeService.shared.claudePath
                let maxTokens = ClaudeService.shared.maxTokens
                guard FileManager.default.isExecutableFile(atPath: claudePath) else {
                    continuation.resume(throwing: ClaudeError.notInstalled)
                    return
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: claudePath)
                process.currentDirectoryURL = StorageService.shared.baseURL

                var args = [
                    "-p",
                    prompt,
                    "--output-format",
                    "stream-json",
                    "--verbose",
                    "--no-session-persistence",
                    "--allowedTools", "mcp__deepthink__*",
                    "--model",
                    ClaudeService.shared.fullModelID,
                    "--mcp-config",
                    configPath
                ]
                if let systemPrompt {
                    args.append(contentsOf: ["--append-system-prompt", systemPrompt])
                }
                process.arguments = args

                var env = ProcessInfo.processInfo.environment
                env["HOME"] = NSHomeDirectory()
                env["PATH"] = "\(NSHomeDirectory())/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\(env["PATH"] ?? "")"
                process.environment = env

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                var fullText = ""

                do {
                    try process.run()

                    // Kill process if it hangs beyond 120 s
                    let timeoutWork = DispatchWorkItem { if process.isRunning { process.terminate() } }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 120, execute: timeoutWork)
                    defer { timeoutWork.cancel() }

                    let handle = outPipe.fileHandleForReading
                    var buffer = Data()

                    // Blocking read — blocks until data arrives or pipe closes (process exit)
                    while true {
                        let chunk = (try? handle.read(upToCount: 65536)) ?? Data()
                        if chunk.isEmpty { break }
                        buffer.append(chunk)

                        while let newlineRange = buffer.range(of: Data("\n".utf8)) {
                            let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                            buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)

                            guard let line = String(data: lineData, encoding: .utf8), !line.isEmpty else { continue }

                            if let jsonData = line.data(using: .utf8),
                               let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                            {
                                let type = obj["type"] as? String
                                if type == "assistant" || type == "content_block_delta" {
                                    if let text = obj["content"] as? String {
                                        fullText += text
                                        onToken(text)
                                    } else if let delta = obj["delta"] as? [String: Any],
                                              let text = delta["text"] as? String
                                    {
                                        fullText += text
                                        onToken(text)
                                    }
                                } else if type == "result" {
                                    if let result = obj["result"] as? String {
                                        fullText = result
                                    }
                                    let cost = obj["total_cost_usd"] as? Double
                                    let duration = obj["duration_ms"] as? Double
                                    let usageDict = obj["usage"] as? [String: Any]
                                    DispatchQueue.main.async {
                                        ClaudeService.shared.totalQueries += 1
                                        if let cost {
                                            ClaudeService.shared.totalCostUSD += cost
                                            ClaudeService.shared.lastQueryCostUSD = cost
                                        }
                                        ClaudeService.shared.lastQueryDurationMs = duration
                                        var tu = TokenUsage()
                                        tu.inputTokens = usageDict?["input_tokens"] as? Int ?? 0
                                        tu.outputTokens = usageDict?["output_tokens"] as? Int ?? 0
                                        tu.cacheReadTokens = usageDict?["cache_read_input_tokens"] as? Int ?? 0
                                        tu.cacheCreationTokens = usageDict?["cache_creation_input_tokens"] as? Int ?? 0
                                        tu.costUSD = cost ?? 0
                                        tu.durationMs = duration ?? 0
                                        ClaudeService.shared.lastTokenUsage = tu
                                        ClaudeService.shared.sessionInputTokens += tu.inputTokens
                                        ClaudeService.shared.sessionOutputTokens += tu.outputTokens
                                        ClaudeService.shared.recordUsage(
                                            queries: 1,
                                            cost: cost ?? 0,
                                            durationMs: tu.durationMs,
                                            inputTokens: tu.inputTokens,
                                            outputTokens: tu.outputTokens,
                                            cacheReadTokens: tu.cacheReadTokens,
                                            cacheCreationTokens: tu.cacheCreationTokens
                                        )
                                    }
                                }
                            }
                        }
                    }

                    process.waitUntilExit()

                    if process.terminationStatus != 0, fullText.isEmpty {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        let stderr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        if let typed = ClaudeService.classifyOutput(stderr) {
                            continuation.resume(throwing: typed)
                        } else {
                            continuation.resume(throwing: ClaudeError.cliError("Exit \(process.terminationStatus): \(stderr)"))
                        }
                    } else {
                        continuation.resume(returning: fullText)
                    }
                } catch {
                    continuation.resume(throwing: ClaudeError.cliError("Failed to launch: \(error.localizedDescription)"))
                }
            }
        }
    }

    private func runClaudeWithMCP(prompt: String, configPath: String, systemPrompt: String?) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let claudePath = ClaudeService.shared.claudePath
                let maxTokens = ClaudeService.shared.maxTokens
                guard FileManager.default.isExecutableFile(atPath: claudePath) else {
                    continuation.resume(throwing: ClaudeError.notInstalled)
                    return
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: claudePath)
                process.currentDirectoryURL = StorageService.shared.baseURL

                var args = [
                    "-p",
                    prompt,
                    "--output-format",
                    "json",
                    "--no-session-persistence",
                    "--allowedTools", "mcp__deepthink__*",
                    "--model",
                    ClaudeService.shared.fullModelID,
                    "--mcp-config",
                    configPath
                ]
                if let systemPrompt {
                    args.append(contentsOf: ["--append-system-prompt", systemPrompt])
                }
                process.arguments = args

                var env = ProcessInfo.processInfo.environment
                env["HOME"] = NSHomeDirectory()
                env["PATH"] = "\(NSHomeDirectory())/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\(env["PATH"] ?? "")"
                process.environment = env

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()

                    let timeoutWork = DispatchWorkItem { if process.isRunning { process.terminate() } }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 120, execute: timeoutWork)
                    defer { timeoutWork.cancel() }

                    process.waitUntilExit()

                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

                    if process.terminationStatus != 0 {
                        let stderr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: ClaudeError.cliError("Exit \(process.terminationStatus): \(stderr)"))
                        return
                    }

                    let output = String(data: outData, encoding: .utf8) ?? ""
                    if let jsonData = output.data(using: .utf8),
                       let response = try? JSONDecoder().decode(ClaudeService.CLIResponse.self, from: jsonData),
                       let result = response.result
                    {
                        let cost = response.total_cost_usd
                        let duration = response.duration_ms
                        DispatchQueue.main.async {
                            ClaudeService.shared.totalQueries += 1
                            if let cost {
                                ClaudeService.shared.totalCostUSD += cost
                                ClaudeService.shared.lastQueryCostUSD = cost
                            }
                            ClaudeService.shared.lastQueryDurationMs = duration
                            ClaudeService.shared.recordUsage(queries: 1, cost: cost ?? 0, durationMs: duration ?? 0)
                        }
                        continuation.resume(returning: result)
                    } else {
                        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(returning: trimmed.isEmpty ? "No response" : trimmed)
                    }
                } catch {
                    continuation.resume(throwing: ClaudeError.cliError("Failed to launch: \(error.localizedDescription)"))
                }
            }
        }
    }

    func discoverFromClaudeConfig() -> [(name: String, command: String, args: String, category: String, description: String)] {
        let configPaths = [
            "\(NSHomeDirectory())/.claude.json",
            "\(NSHomeDirectory())/.claude/claude_desktop_config.json",
            "\(NSHomeDirectory())/Library/Application Support/Claude/claude_desktop_config.json"
        ]

        for path in configPaths {
            guard let data = FileManager.default.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let servers = json["mcpServers"] as? [String: Any]
            else {
                continue
            }

            var discovered: [(name: String, command: String, args: String, category: String, description: String)] = []

            for (name, value) in servers {
                guard let config = value as? [String: Any],
                      let command = config["command"] as? String else { continue }

                let args = (config["args"] as? [String])?.joined(separator: " ") ?? ""
                discovered.append((
                    name: name,
                    command: command,
                    args: args,
                    category: "Discovered",
                    description: "Imported from Claude config"
                ))
            }

            if !discovered.isEmpty { return discovered }
        }

        return []
    }

    static let presetServers: [(name: String, command: String, args: String, category: String, description: String)] = [
        ("DeepThink Workspace", DeepThinkPaths.mcpBinaryPath, "", "Workspace", "Manage tasks, notes, and projects in your DeepThink workspace"),
        ("Filesystem", "npx", "-y @modelcontextprotocol/server-filesystem /Users", "Files", "Read, write, and manage files on your system"),
        ("Web Search", "npx", "-y @anthropic-ai/mcp-server-web-search", "Search", "Search the web using Brave Search API"),
        ("Memory", "npx", "-y @modelcontextprotocol/server-memory", "Knowledge", "Persistent memory for storing and retrieving facts"),
        ("GitHub", "npx", "-y @modelcontextprotocol/server-github", "Dev", "Access GitHub repos, issues, and PRs"),
        ("PostgreSQL", "npx", "-y @modelcontextprotocol/server-postgres", "Data", "Query and manage PostgreSQL databases"),
        ("SQLite", "npx", "-y @modelcontextprotocol/server-sqlite", "Data", "Query and manage SQLite databases"),
        ("Puppeteer", "npx", "-y @modelcontextprotocol/server-puppeteer", "Web", "Browser automation and web scraping"),
        ("Fetch", "npx", "-y @anthropic-ai/mcp-server-fetch", "Web", "Fetch and extract content from URLs"),
        ("Slack", "npx", "-y @modelcontextprotocol/server-slack", "Communication", "Send and read Slack messages"),
        ("Google Drive", "npx", "-y @modelcontextprotocol/server-gdrive", "Files", "Access Google Drive files and folders"),
        ("Linear", "npx", "-y mcp-linear", "Project Management", "Manage Linear issues and projects"),
        ("Sentry", "npx", "-y @modelcontextprotocol/server-sentry", "Dev", "Query Sentry error tracking data")
    ]
}
