import Foundation
import SwiftData

@Observable
final class MCPService {
    static let shared = MCPService()

    var isRunning = false
    var lastError: String?

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

                var args = ["-p", prompt, "--output-format", "json", "--no-session-persistence", "--dangerously-skip-permissions", "--mcp-config", configPath]
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
        ("DeepThink Workspace", "bun", "run \(DeepThinkPaths.mcpServerPath)", "Workspace", "Manage tasks, notes, and projects in your DeepThink workspace"),
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
