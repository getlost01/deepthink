import Foundation

final class StorageService {
    static let shared = StorageService()

    let baseURL: URL

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        baseURL = documents.appendingPathComponent("DeepThink")
    }

    // MARK: - Directory Paths

    var dataURL: URL { baseURL.appendingPathComponent("data") }
    var storeURL: URL { dataURL.appendingPathComponent("deepthink.store") }
    var configsURL: URL { baseURL.appendingPathComponent("configs") }
    var mcpConfigURL: URL { configsURL.appendingPathComponent("mcp") }
    var claudeConfigURL: URL { configsURL.appendingPathComponent("claude") }
    var logsURL: URL { baseURL.appendingPathComponent("logs") }
    var toolsURL: URL { baseURL.appendingPathComponent("tools") }
    var contextURL: URL { baseURL.appendingPathComponent("context") }
    var embeddingsURL: URL { contextURL.appendingPathComponent("embeddings") }
    var summariesURL: URL { contextURL.appendingPathComponent("summaries") }
    var workspaceURL: URL { baseURL.appendingPathComponent("workspace") }
    var notesExportURL: URL { workspaceURL.appendingPathComponent("notes") }
    var projectsExportURL: URL { workspaceURL.appendingPathComponent("projects") }
    var terminalLogsURL: URL { logsURL.appendingPathComponent("terminal") }

    // MARK: - MCP

    var mcpServerConfigFile: URL { mcpConfigURL.appendingPathComponent("servers.json") }
    var mcpTempConfigFile: URL { mcpConfigURL.appendingPathComponent("active-config.json") }

    // MARK: - Setup

    func ensureDirectoryStructure() {
        let fm = FileManager.default
        let dirs = [
            dataURL,
            configsURL,
            mcpConfigURL,
            claudeConfigURL,
            logsURL,
            terminalLogsURL,
            toolsURL,
            contextURL,
            embeddingsURL,
            summariesURL,
            workspaceURL,
            notesExportURL,
            projectsExportURL,
        ]

        for url in dirs {
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }

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

    private func createReadmeIfNeeded() {
        let readme = baseURL.appendingPathComponent("README.md")
        guard !FileManager.default.fileExists(atPath: readme.path) else { return }
        let content = """
        # DeepThink Workspace

        This folder is managed by the DeepThink app.

        ## Structure

        ```
        DeepThink/
        ├── data/              # SwiftData database
        ├── configs/
        │   ├── mcp/           # MCP server configurations
        │   └── claude/        # Claude CLI settings
        ├── context/
        │   ├── embeddings/    # Vector embeddings
        │   └── summaries/     # AI-generated summaries
        ├── workspace/
        │   ├── notes/         # Exported notes
        │   └── projects/      # Project files
        ├── tools/             # Custom tools & scripts
        └── logs/              # App & terminal logs
        ```

        All app data lives here. Back up this folder to preserve your workspace.
        """
        try? content.write(to: readme, atomically: true, encoding: .utf8)
    }
}
