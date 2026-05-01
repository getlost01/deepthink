import Foundation

@Observable
final class KnowledgeService {
    static let shared = KnowledgeService()

    private let storage = StorageService.shared
    private let fm = FileManager.default

    // MARK: - Project Knowledge

    func saveToProject(_ projectName: String, content: String, type: EntryType = .context) {
        let projectDir = storage.knowledgeProjectURL(name: projectName)
        ensureDir(projectDir)

        let filename: String
        switch type {
        case .context: filename = "context.md"
        case .decision: filename = "decisions.json"
        case .artifact: filename = "artifacts/\(timestamp())_artifact.md"
        }

        let fileURL = projectDir.appendingPathComponent(filename)
        if filename.contains("/") {
            ensureDir(fileURL.deletingLastPathComponent())
        }

        appendOrCreate(at: fileURL, content: content)
        updateIndex(project: projectName, type: type)
        storage.writeLog("Knowledge saved: \(projectName)/\(type)", to: "knowledge")
    }

    func loadProject(_ projectName: String) -> ProjectKnowledge {
        let projectDir = storage.knowledgeProjectURL(name: projectName)

        let context = readIfExists(projectDir.appendingPathComponent("context.md"))
        let decisions = readIfExists(projectDir.appendingPathComponent("decisions.json"))

        let artifactsDir = projectDir.appendingPathComponent("artifacts")
        var artifacts: [String] = []
        if let files = try? fm.contentsOfDirectory(atPath: artifactsDir.path) {
            artifacts = files.sorted()
        }

        return ProjectKnowledge(
            name: projectName,
            context: context,
            decisions: decisions,
            artifactFiles: artifacts
        )
    }

    func listProjects() -> [String] {
        let dir = storage.knowledgeProjectsURL
        guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
        return items.filter { isDirectory(dir.appendingPathComponent($0)) }.sorted()
    }

    // MARK: - Integration Data Capture

    func saveIntegrationData(source: String, channel: String, content: String, metadata: [String: String] = [:]) {
        let sourceDir = storage.knowledgeIntegrationURL(source: source)
        let channelDir = sourceDir.appendingPathComponent(channel.slugified)
        ensureDir(channelDir)

        let filename = "\(timestamp()).md"
        let fileURL = channelDir.appendingPathComponent(filename)

        var fullContent = ""
        if !metadata.isEmpty {
            let meta = metadata.map { "- **\($0.key)**: \($0.value)" }.joined(separator: "\n")
            fullContent = "---\n\(meta)\n---\n\n"
        }
        fullContent += content

        try? fullContent.write(to: fileURL, atomically: true, encoding: .utf8)
        updateIndex(integration: source, channel: channel)
        storage.writeLog("Integration data: \(source)/\(channel)", to: "knowledge")
    }

    func loadIntegrationData(source: String, channel: String? = nil, limit: Int = 20) -> [IntegrationEntry] {
        let sourceDir = storage.knowledgeIntegrationURL(source: source)
        guard fm.fileExists(atPath: sourceDir.path) else { return [] }

        var entries: [IntegrationEntry] = []

        if let channel {
            let channelDir = sourceDir.appendingPathComponent(channel.slugified)
            entries = loadEntriesFrom(channelDir, source: source, channel: channel)
        } else {
            if let channels = try? fm.contentsOfDirectory(atPath: sourceDir.path) {
                for ch in channels where isDirectory(sourceDir.appendingPathComponent(ch)) {
                    let channelDir = sourceDir.appendingPathComponent(ch)
                    entries.append(contentsOf: loadEntriesFrom(channelDir, source: source, channel: ch))
                }
            }
        }

        entries.sort { $0.filename > $1.filename }
        return Array(entries.prefix(limit))
    }

    func listIntegrationSources() -> [String] {
        let dir = storage.knowledgeIntegrationsURL
        guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
        return items.filter { isDirectory(dir.appendingPathComponent($0)) }.sorted()
    }

    func listChannels(for source: String) -> [String] {
        let sourceDir = storage.knowledgeIntegrationURL(source: source)
        guard let items = try? fm.contentsOfDirectory(atPath: sourceDir.path) else { return [] }
        return items.filter { isDirectory(sourceDir.appendingPathComponent($0)) }.sorted()
    }

    // MARK: - Web Search Archive

    func saveWebSearch(query: String, results: String) {
        saveIntegrationData(
            source: "web",
            channel: "searches",
            content: "## Query: \(query)\n\n\(results)",
            metadata: ["query": query, "date": ISO8601DateFormatter().string(from: Date())]
        )
    }

    // MARK: - Archive & Compression

    func archiveProject(_ projectName: String) async {
        let knowledge = loadProject(projectName)
        guard let context = knowledge.context, !context.isEmpty else { return }

        let compressed = await compressWithClaude(context)
        let archiveDir = storage.knowledgeArchiveURL
        let archiveFile = archiveDir.appendingPathComponent("\(projectName.slugified)_\(timestamp()).md")

        var content = "# Archived: \(projectName)\n"
        content += "Archived: \(ISO8601DateFormatter().string(from: Date()))\n\n"
        content += compressed

        try? content.write(to: archiveFile, atomically: true, encoding: .utf8)
        storage.writeLog("Archived project: \(projectName)", to: "knowledge")
    }

    func compressKnowledge(source: String, channel: String) async {
        let entries = loadIntegrationData(source: source, channel: channel, limit: 50)
        guard !entries.isEmpty else { return }

        let combined = entries.map(\.content).joined(separator: "\n\n---\n\n")
        let compressed = await compressWithClaude(combined)

        let archiveFile = storage.knowledgeArchiveURL
            .appendingPathComponent("\(source)_\(channel)_\(timestamp()).md")

        var content = "# Compressed: \(source)/\(channel)\n"
        content += "Entries: \(entries.count) | Compressed: \(ISO8601DateFormatter().string(from: Date()))\n\n"
        content += compressed

        try? content.write(to: archiveFile, atomically: true, encoding: .utf8)
        storage.writeLog("Compressed: \(source)/\(channel) (\(entries.count) entries)", to: "knowledge")
    }

    // MARK: - Stats

    func stats() -> KnowledgeStats {
        let projects = listProjects()
        let sources = listIntegrationSources()
        var integrationCount = 0
        for source in sources {
            for channel in listChannels(for: source) {
                integrationCount += loadIntegrationData(source: source, channel: channel, limit: 1000).count
            }
        }
        let archiveCount = (try? fm.contentsOfDirectory(atPath: storage.knowledgeArchiveURL.path))?.count ?? 0

        return KnowledgeStats(
            projectCount: projects.count,
            integrationSources: sources.count,
            integrationEntries: integrationCount,
            archivedCount: archiveCount
        )
    }

    // MARK: - Private

    private func compressWithClaude(_ text: String) async -> String {
        do {
            return try await ClaudeService.shared.query(
                "Compress this knowledge into dense, structured bullet points. Keep all facts, dates, names, decisions. Remove filler:\n\n\(text.prefix(8000))",
                systemPrompt: "You compress information. Output structured markdown bullets. Preserve all key data."
            )
        } catch {
            return text
        }
    }

    private func appendOrCreate(at url: URL, content: String) {
        let entry = "\n\n---\n_\(ISO8601DateFormatter().string(from: Date()))_\n\n\(content)"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(entry.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? entry.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func readIfExists(_ url: URL) -> String? {
        guard fm.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func ensureDir(_ url: URL) {
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }

    private func loadEntriesFrom(_ dir: URL, source: String, channel: String) -> [IntegrationEntry] {
        guard let files = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
        return files.filter { $0.hasSuffix(".md") }.compactMap { filename in
            let url = dir.appendingPathComponent(filename)
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return IntegrationEntry(source: source, channel: channel, filename: filename, content: content)
        }
    }

    private func updateIndex(project: String? = nil, type: EntryType? = nil, integration: String? = nil, channel: String? = nil) {
        let indexFile = storage.knowledgeIndexFile
        guard var index = loadIndex() else { return }

        let now = ISO8601DateFormatter().string(from: Date())

        if let project {
            var projects = index["projects"] as? [String: Any] ?? [:]
            var proj = projects[project] as? [String: Any] ?? ["created": now]
            proj["lastUpdated"] = now
            if let type {
                var counts = proj["counts"] as? [String: Int] ?? [:]
                counts[type.rawValue] = (counts[type.rawValue] ?? 0) + 1
                proj["counts"] = counts
            }
            projects[project] = proj
            index["projects"] = projects
        }

        if let integration, let channel {
            var integrations = index["integrations"] as? [String: Any] ?? [:]
            var source = integrations[integration] as? [String: Any] ?? [:]
            var ch = source[channel] as? [String: Int] ?? [:]
            ch["count"] = (ch["count"] ?? 0) + 1
            source[channel] = ch
            integrations[integration] = source
            index["integrations"] = integrations
        }

        var stats = index["stats"] as? [String: Any] ?? [:]
        stats["totalEntries"] = ((stats["totalEntries"] as? Int) ?? 0) + 1
        stats["lastUpdated"] = now
        index["stats"] = stats

        if let data = try? JSONSerialization.data(withJSONObject: index, options: .prettyPrinted) {
            try? data.write(to: indexFile)
        }
    }

    private func loadIndex() -> [String: Any]? {
        let indexFile = storage.knowledgeIndexFile
        guard let data = try? Data(contentsOf: indexFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    // MARK: - Types

    enum EntryType: String {
        case context, decision, artifact
    }

    struct ProjectKnowledge {
        let name: String
        let context: String?
        let decisions: String?
        let artifactFiles: [String]
    }

    struct IntegrationEntry {
        let source: String
        let channel: String
        let filename: String
        let content: String
    }

    struct KnowledgeStats {
        let projectCount: Int
        let integrationSources: Int
        let integrationEntries: Int
        let archivedCount: Int
    }
}

private extension String {
    var slugified: String {
        lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9\\-]", with: "", options: .regularExpression)
    }
}
