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

    static let cliInstallPath = DeepThinkPaths.localBin + "/deepthink"
    static let mcpInstallPath = DeepThinkPaths.localBin + "/deepthink-mcp"

    func checkGlobalMCPStatus() {
        let fm = FileManager.default
        isCLIInstalled = fm.isExecutableFile(atPath: Self.cliInstallPath)
        isMCPInstalled = fm.isExecutableFile(atPath: Self.mcpInstallPath)

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
              let json = String(data: data, encoding: .utf8) else {
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

    func streamQueryWithMCP(prompt: String, servers: [MCPServer], systemPrompt: String? = nil, onToken: @escaping @Sendable (String) -> Void) async throws -> String {
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

    private func runClaudeWithMCPStreaming(prompt: String, configPath: String, systemPrompt: String?, onToken: @escaping @Sendable (String) -> Void) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let claudePath = ClaudeService.shared.claudePath
                guard FileManager.default.isExecutableFile(atPath: claudePath) else {
                    continuation.resume(throwing: ClaudeError.notInstalled)
                    return
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: claudePath)
                process.currentDirectoryURL = StorageService.shared.baseURL

                var args = ["-p", prompt, "--output-format", "stream-json", "--verbose", "--no-session-persistence", "--dangerously-skip-permissions", "--model", ClaudeService.shared.fullModelID, "--mcp-config", configPath]
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

                    let handle = outPipe.fileHandleForReading
                    var buffer = Data()

                    while process.isRunning || handle.availableData.count > 0 {
                        let chunk = handle.availableData
                        if chunk.isEmpty { break }
                        buffer.append(chunk)

                        while let newlineRange = buffer.range(of: Data("\n".utf8)) {
                            let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                            buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)

                            guard let line = String(data: lineData, encoding: .utf8), !line.isEmpty else { continue }

                            if let jsonData = line.data(using: .utf8),
                               let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                let type = obj["type"] as? String
                                if type == "assistant" || type == "content_block_delta" {
                                    if let text = obj["content"] as? String {
                                        fullText += text
                                        onToken(text)
                                    } else if let delta = obj["delta"] as? [String: Any],
                                              let text = delta["text"] as? String {
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
                                    DispatchQueue.main.sync {
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
                                        ClaudeService.shared.recordUsage(queries: 1, cost: cost ?? 0, durationMs: tu.durationMs, inputTokens: tu.inputTokens, outputTokens: tu.outputTokens, cacheReadTokens: tu.cacheReadTokens, cacheCreationTokens: tu.cacheCreationTokens)
                                    }
                                }
                            }
                        }
                    }

                    process.waitUntilExit()

                    if process.terminationStatus != 0 && fullText.isEmpty {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        let stderr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: ClaudeError.cliError("Exit \(process.terminationStatus): \(stderr)"))
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
                let claudePath = "\(NSHomeDirectory())/.local/bin/claude"
                guard FileManager.default.isExecutableFile(atPath: claudePath) else {
                    continuation.resume(throwing: ClaudeError.notInstalled)
                    return
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: claudePath)
                process.currentDirectoryURL = StorageService.shared.baseURL

                var args = ["-p", prompt, "--output-format", "json", "--no-session-persistence", "--dangerously-skip-permissions", "--model", ClaudeService.shared.fullModelID, "--mcp-config", configPath]
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
                       let result = response.result {
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
            "\(NSHomeDirectory())/Library/Application Support/Claude/claude_desktop_config.json",
        ]

        for path in configPaths {
            guard let data = FileManager.default.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let servers = json["mcpServers"] as? [String: Any] else {
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
        ("Sentry", "npx", "-y @modelcontextprotocol/server-sentry", "Dev", "Query Sentry error tracking data"),
    ]
}
