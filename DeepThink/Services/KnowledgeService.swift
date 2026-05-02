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
}
