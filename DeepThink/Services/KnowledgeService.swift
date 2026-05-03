import Foundation

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

        return KnowledgeEntry(
            title: title,
            source: source,
            sourceURL: frontmatter["url"],
            tags: tags,
            importedAt: importedAt,
            content: body,
            filePath: url,
            fileSize: fileSize
        )
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

    func createEntry(title: String, content: String, source: String, tags: [String] = [], sourceURL: String? = nil) {
        let dir: URL
        switch source {
        case "url", "web": dir = StorageService.shared.knowledgeURL.appendingPathComponent("web")
        case "clipboard": dir = StorageService.shared.knowledgeURL.appendingPathComponent("clipboard")
        case "manual": dir = StorageService.shared.knowledgeURL.appendingPathComponent("manual")
        default: dir = StorageService.shared.knowledgeURL.appendingPathComponent("imports")
        }

        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let slug = title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9\\-]", with: "", options: .regularExpression)
        let filename = "\(slug).md"
        let fileURL = dir.appendingPathComponent(filename)

        var md = "---\n"
        md += "title: \(title)\n"
        md += "source: \(source)\n"
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

    // MARK: - RAG: Relevance Search

    func relevantEntries(for query: String, maxResults: Int = 5) -> [KnowledgeEntry] {
        guard !query.isEmpty else { return [] }

        let queryWords = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 }

        guard !queryWords.isEmpty else { return [] }

        let scored: [(entry: KnowledgeEntry, score: Double)] = entries.compactMap { entry in
            let titleLower = entry.title.lowercased()
            let contentLower = entry.content.lowercased()
            let tagsLower = entry.tags.map { $0.lowercased() }

            var score: Double = 0

            for word in queryWords {
                if titleLower.contains(word) { score += 3.0 }
                if tagsLower.contains(where: { $0.contains(word) }) { score += 2.5 }
                let contentOccurrences = contentLower.components(separatedBy: word).count - 1
                score += min(Double(contentOccurrences) * 0.5, 3.0)
            }

            let recencyDays = Date().timeIntervalSince(entry.importedAt) / 86400
            if recencyDays < 7 { score *= 1.2 }
            else if recencyDays < 30 { score *= 1.1 }

            return score > 0 ? (entry, score) : nil
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(maxResults)
            .map(\.entry)
    }

    func ragContext(for query: String, maxTokens: Int = 3000) -> String? {
        let relevant = relevantEntries(for: query)
        guard !relevant.isEmpty else { return nil }

        var context = "# Relevant Knowledge\n\n"
        var charBudget = maxTokens * 4

        for entry in relevant {
            let snippet = "## \(entry.title)\n"
                + (entry.tags.isEmpty ? "" : "Tags: \(entry.tags.joined(separator: ", "))\n")
                + "\(String(entry.content.prefix(800)))\n\n"

            if charBudget - snippet.count < 0 { break }
            context += snippet
            charBudget -= snippet.count
        }

        return context
    }
}
