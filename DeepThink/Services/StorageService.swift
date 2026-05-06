import Foundation

final class StorageService {
    static let shared = StorageService()

    let baseURL: URL

    private init() {
        baseURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("DeepThink")
    }

    // MARK: - Core Data

    var dataURL: URL { baseURL.appendingPathComponent("data") }
    var storeURL: URL { dataURL.appendingPathComponent("deepthink.store") }

    // MARK: - .claude (single source of truth for CLI + app)

    var claudeDir: URL { baseURL.appendingPathComponent(".claude") }
    var commandsURL: URL { claudeDir.appendingPathComponent("commands") }
    var rulesConfigURL: URL { claudeDir.appendingPathComponent("rules") }
    var claudeSettingsFile: URL { claudeDir.appendingPathComponent("settings.json") }
    var claudeCacheURL: URL { claudeDir.appendingPathComponent("cache") }
    var agentsURL: URL { claudeDir.appendingPathComponent("agents") }

    var skillsConfigURL: URL { commandsURL }
    var mcpTempConfigFile: URL { claudeCacheURL.appendingPathComponent("mcp-active.json") }
    var mcpServerConfigFile: URL { claudeCacheURL.appendingPathComponent("servers.json") }

    // MARK: - Knowledge Base

    var knowledgeURL: URL { baseURL.appendingPathComponent("knowledge") }
    var knowledgeProjectsURL: URL { knowledgeURL.appendingPathComponent("projects") }
    var knowledgeIntegrationsURL: URL { knowledgeURL.appendingPathComponent("integrations") }
    var knowledgeArchiveURL: URL { knowledgeURL.appendingPathComponent("archive") }
    var knowledgeIndexFile: URL { knowledgeURL.appendingPathComponent("index.json") }
    var knowledgeWebURL: URL { knowledgeURL.appendingPathComponent("web") }
    var knowledgeClipboardURL: URL { knowledgeURL.appendingPathComponent("clipboard") }
    var knowledgeScriptsURL: URL { knowledgeURL.appendingPathComponent("scripts") }
    var knowledgeFoldersURL: URL { knowledgeURL.appendingPathComponent("folders") }
    var knowledgeImportsURL: URL { knowledgeURL.appendingPathComponent("imports") }
    var knowledgeManualURL: URL { knowledgeURL.appendingPathComponent("manual") }

    func knowledgeProjectURL(name: String) -> URL {
        knowledgeProjectsURL.appendingPathComponent(name.slugified)
    }

    func knowledgeIntegrationURL(source: String) -> URL {
        knowledgeIntegrationsURL.appendingPathComponent(source.lowercased())
    }

    func knowledgePath(for provider: String, channel: String) -> String {
        knowledgeIntegrationsURL
            .appendingPathComponent(provider.lowercased())
            .appendingPathComponent(channel.slugified)
            .path
    }

    // MARK: - Memory

    var memoryURL: URL { baseURL.appendingPathComponent("memory") }

    // MARK: - Sandbox

    var sandboxURL: URL { baseURL.appendingPathComponent("sandbox") }
    var sandboxDocsURL: URL { sandboxURL.appendingPathComponent("docs") }
    var sandboxOutputsURL: URL { sandboxURL.appendingPathComponent("outputs") }
    var sandboxAnalysisURL: URL { sandboxURL.appendingPathComponent("analysis") }
    var sandboxInsightsURL: URL { sandboxURL.appendingPathComponent("insights") }

    // MARK: - Tools & Logs & Workspace

    var toolsURL: URL { baseURL.appendingPathComponent("tools") }
    var logsURL: URL { baseURL.appendingPathComponent("logs") }
    var terminalLogsURL: URL { logsURL.appendingPathComponent("terminal") }
    var workspaceURL: URL { baseURL.appendingPathComponent("workspace") }
    var notesExportURL: URL { workspaceURL.appendingPathComponent("notes") }
    var projectsExportURL: URL { workspaceURL.appendingPathComponent("exports") }

    // MARK: - Setup

    func ensureDirectoryStructure() {
        let fm = FileManager.default
        let dirs = [
            dataURL,
            // Configs
            claudeDir, commandsURL, rulesConfigURL, claudeCacheURL, agentsURL,
            // Knowledge
            knowledgeURL, knowledgeProjectsURL, knowledgeIntegrationsURL, knowledgeArchiveURL,
            knowledgeWebURL, knowledgeClipboardURL, knowledgeScriptsURL,
            knowledgeFoldersURL, knowledgeImportsURL, knowledgeManualURL,
            // Memory
            memoryURL,
            // Sandbox
            sandboxURL, sandboxDocsURL, sandboxOutputsURL, sandboxAnalysisURL, sandboxInsightsURL,
            // Tools, Logs, Workspace
            toolsURL, logsURL, terminalLogsURL,
            workspaceURL, notesExportURL, projectsExportURL,
        ]

        for url in dirs {
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }

        ensureKnowledgeIndex()
        createReadmeIfNeeded()
    }

    var isFirstLaunch: Bool {
        !FileManager.default.fileExists(atPath: dataURL.path)
    }

    // MARK: - Helpers

    func logFile(named name: String) -> URL {
        logsURL.appendingPathComponent("\(name).log")
    }

    func writeLog(_ message: String, to name: String) {
        let url = logFile(named: name)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func ensureKnowledgeIndex() {
        let indexFile = knowledgeIndexFile
        guard !FileManager.default.fileExists(atPath: indexFile.path) else { return }
        let initial: [String: Any] = [
            "version": 1,
            "created": ISO8601DateFormatter().string(from: Date()),
            "projects": [String: Any](),
            "integrations": [String: Any](),
            "stats": ["totalEntries": 0, "lastUpdated": ISO8601DateFormatter().string(from: Date())]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: initial, options: .prettyPrinted) {
            try? data.write(to: indexFile)
        }
    }

    private func createReadmeIfNeeded() {
        let readme = baseURL.appendingPathComponent("README.md")
        guard !FileManager.default.fileExists(atPath: readme.path) else { return }
        let content = """
        # DeepThink Workspace

        Self-contained AI workspace managed by DeepThink.

        ## Structure

        ```
        DeepThink/
        ├── data/                # App database
        ├── .claude/             # Shared config (CLI + app)
        │   ├── commands/        # Skills as slash commands
        │   ├── rules/           # System prompts & rules
        │   ├── settings.json    # MCP servers, permissions
        │   └── cache/           # Catalog cache, temp configs
        ├── knowledge/
        │   ├── projects/        # Per-project knowledge base
        │   ├── integrations/    # MCP data (Slack, GitHub, etc.)
        │   ├── archive/         # Compressed old knowledge
        │   └── index.json       # Master index
        ├── memory/              # Short & long-term memory
        ├── sandbox/
        │   ├── docs/            # Generated documents
        │   ├── outputs/         # Tool outputs
        │   ├── analysis/        # Analysis results
        │   └── insights/        # AI insights
        ├── tools/               # Custom CLI tools
        ├── logs/                # App & terminal logs
        └── workspace/
            ├── notes/           # Exported notes
            └── exports/         # Project exports
        ```

        All data lives here. Back up this folder to preserve everything.
        """
        try? content.write(to: readme, atomically: true, encoding: .utf8)
    }
}

extension String {
    var slugified: String {
        lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9\\-]", with: "", options: .regularExpression)
    }
}
