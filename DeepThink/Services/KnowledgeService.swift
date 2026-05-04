import Foundation
import CryptoKit

@Observable
final class KnowledgeService {
    static let shared = KnowledgeService()

    var entries: [KnowledgeEntry] = []
    var isLoading = false

    private let fm = FileManager.default

    private init() {}

    // MARK: - Load

    func reload() {
        isLoading = true
        defer { isLoading = false }

        let baseURL = StorageService.shared.knowledgeURL
        entries = scanDirectory(baseURL)
            .sorted { $0.importedAt > $1.importedAt }

        // Rebuild TF-IDF index with snapshot of entries
        let snapshot = entries
        ContextEngine.shared.indexQueue.async {
            ContextEngine.shared.rebuildIndex(with: snapshot)
        }

        // Build semantic embeddings (incremental, background)
        DispatchQueue.global(qos: .utility).async {
            EmbeddingService.shared.indexEntries(snapshot)
            EmbeddingService.shared.pruneStaleEntries(validIDs: Set(snapshot.map(\.id)))
        }
    }

    private func scanDirectory(_ url: URL) -> [KnowledgeEntry] {
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles]) else { return [] }

        var results: [KnowledgeEntry] = []
        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "md" || fileURL.pathExtension == "markdown" else { continue }
            if let entry = parseEntry(at: fileURL) {
                results.append(entry)
            }
        }
        return results
    }

    // MARK: - Parse

    func parseEntry(at url: URL) -> KnowledgeEntry? {
        guard let data = fm.contents(atPath: url.path),
              let text = String(data: data, encoding: .utf8) else { return nil }

        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? data.count
        let createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()

        let (frontmatter, body) = parseFrontmatter(text)

        let title = frontmatter["title"] ?? url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        let source = frontmatter["source"] ?? inferSource(from: url)

        var tags: [String] = []
        if let tagStr = frontmatter["tags"] {
            tags = tagStr
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        let importedAt: Date
        if let dateStr = frontmatter["imported_at"] ?? frontmatter["synced_at"] ?? frontmatter["created_at"] {
            importedAt = ISO8601DateFormatter().date(from: dateStr) ?? createdAt
        } else {
            importedAt = createdAt
        }

        let folder = frontmatter["folder"] ?? inferFolder(from: url)

        return KnowledgeEntry(
            title: title,
            source: source,
            sourceURL: frontmatter["url"],
            tags: tags,
            importedAt: importedAt,
            content: body,
            filePath: url,
            fileSize: fileSize,
            folder: folder
        )
    }

    private func inferFolder(from url: URL) -> String {
        let knowledgePath = StorageService.shared.knowledgeURL.path
        let relativePath = url.deletingLastPathComponent().path.replacingOccurrences(of: knowledgePath, with: "")
        let components = relativePath.split(separator: "/").map(String.init)
        if let first = components.first, !first.isEmpty {
            return first.replacingOccurrences(of: "-", with: " ").capitalized
        }
        return "General"
    }

    private func inferSource(from url: URL) -> String {
        let path = url.path
        if path.contains("/web/") || path.contains("/scraped/") { return "url" }
        if path.contains("/clipboard/") { return "clipboard" }
        if path.contains("/scripts/") { return "script" }
        if path.contains("/integrations/") { return "mcp" }
        if path.contains("/folders/") || path.contains("/imports/") { return "folder" }
        if path.contains("/manual/") { return "manual" }
        return "import"
    }

    // MARK: - Frontmatter

    func parseFrontmatter(_ text: String) -> (frontmatter: [String: String], body: String) {
        let lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return ([:], text)
        }

        var frontmatter: [String: String] = [:]
        var bodyStartIndex = 1

        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line == "---" {
                bodyStartIndex = i + 1
                break
            }
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                frontmatter[key] = value
            }
        }

        let body = lines[bodyStartIndex...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (frontmatter, body)
    }

    // MARK: - CRUD

    func createEntry(title: String, content: String, source: String, tags: [String] = [], sourceURL: String? = nil, folder: String = "General") {
        let dir = StorageService.shared.knowledgeURL.appendingPathComponent(folder.slugified)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let digest = SHA256.hash(data: Data(content.utf8))
        let hash = digest.prefix(4).map { String(format: "%02x", $0) }.joined()
        let slug = title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9\\-]", with: "", options: .regularExpression)
            .prefix(60)
        let filename = "\(slug)-\(hash).md"
        let fileURL = dir.appendingPathComponent(String(filename))

        var md = "---\n"
        md += "title: \(title)\n"
        md += "source: \(source)\n"
        md += "folder: \(folder)\n"
        if let url = sourceURL { md += "url: \(url)\n" }
        if !tags.isEmpty { md += "tags: [\(tags.joined(separator: ", "))]\n" }
        md += "imported_at: \(ISO8601DateFormatter().string(from: Date()))\n"
        md += "---\n\n"
        md += content

        try? md.write(to: fileURL, atomically: true, encoding: .utf8)
        reload()

        if tags.isEmpty {
            Task {
                if let entry = self.entries.first(where: { $0.filePath == fileURL }) {
                    await KnowledgeExtractionService.shared.autoTagAndUpdate(entry: entry)
                }
            }
        }
    }

    // MARK: - Folder Management

    var folders: [String] {
        let allFolders = Set(entries.map(\.folder))
        var result = allFolders.sorted()
        if !result.contains("General") { result.insert("General", at: 0) }
        return result
    }

    func createFolder(named name: String) {
        let dir = StorageService.shared.knowledgeURL.appendingPathComponent(name.slugified)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func moveEntry(_ entry: KnowledgeEntry, to folder: String) {
        let destDir = StorageService.shared.knowledgeURL.appendingPathComponent(folder.slugified)
        try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        let destURL = destDir.appendingPathComponent(entry.filePath.lastPathComponent)
        guard destURL != entry.filePath else { return }

        // Update folder in frontmatter
        guard let data = fm.contents(atPath: entry.filePath.path),
              let text = String(data: data, encoding: .utf8) else { return }

        let (frontmatter, body) = parseFrontmatter(text)
        var updated = frontmatter
        updated["folder"] = folder

        var md = "---\n"
        for (key, value) in updated { md += "\(key): \(value)\n" }
        md += "---\n\n\(body)"

        try? md.write(to: destURL, atomically: true, encoding: .utf8)
        try? fm.removeItem(at: entry.filePath)
        reload()
    }

    func deleteEntry(_ entry: KnowledgeEntry) {
        try? fm.removeItem(at: entry.filePath)
        entries.removeAll { $0.id == entry.id }
    }

    // MARK: - Search

    func search(_ query: String) -> [KnowledgeEntry] {
        guard !query.isEmpty else { return entries }
        let q = query.lowercased()
        return entries.filter {
            $0.title.lowercased().contains(q) ||
            $0.content.lowercased().contains(q) ||
            $0.tags.contains { $0.lowercased().contains(q) }
        }
    }

    func filter(by source: String?) -> [KnowledgeEntry] {
        guard let source, !source.isEmpty else { return entries }
        return entries.filter { $0.source == source }
    }

    // MARK: - RAG: Smart Retrieval via ContextEngine

    func relevantEntries(for query: String, maxResults: Int = 5) -> [KnowledgeEntry] {
        guard !query.isEmpty else { return [] }

        let bundle = ContextEngine.shared.retrieveContext(for: query, maxTokens: maxResults * 800)
        let matchedIDs = Set(bundle.parts.map(\.title))

        return entries
            .filter { matchedIDs.contains($0.title) }
            .prefix(maxResults)
            .map { $0 }
    }

    func ragContext(for query: String, maxTokens: Int = 4000, projectScope: String? = nil, agentScope: [String]? = nil) -> String? {
        let bundle = ContextEngine.shared.retrieveContextHybrid(
            for: query,
            maxTokens: maxTokens,
            projectScope: projectScope,
            agentScope: agentScope
        )
        return ContextEngine.shared.formatForPrompt(bundle)
    }

    // MARK: - Dedup-aware creation

    func createEntryIfNotDuplicate(title: String, content: String, source: String, tags: [String] = [], sourceURL: String? = nil) -> Bool {
        if ContextEngine.shared.isDuplicateOrSimilar(content: content, threshold: 0.75) {
            StorageService.shared.writeLog("Skipped duplicate: \(title)", to: "knowledge")
            return false
        }
        createEntry(title: title, content: content, source: source, tags: tags, sourceURL: sourceURL)
        return true
    }
}
