import CryptoKit
import Foundation

@Observable
final class KnowledgeService {
    static let shared = KnowledgeService()

    var entries: [KnowledgeEntry] = []
    var isLoading = false

    private let fm = FileManager.default
    private var lastScanAt: Date?

    private init() {}

    // MARK: - Load

    func reload() {
        isLoading = true
        let scanStart = Date()
        let since = lastScanAt

        DispatchQueue.global(qos: .userInitiated).async {
            let knowledgeURL = StorageService.shared.knowledgeURL

            if let since {
                let changed = self.scanDirectory(knowledgeURL, changedSince: since)
                let allPaths = Set(self.allFilePaths(in: knowledgeURL))

                DispatchQueue.main.async {
                    self.entries.removeAll { !allPaths.contains($0.filePath) }
                    for entry in changed {
                        if let idx = self.entries.firstIndex(where: { $0.filePath == entry.filePath }) {
                            self.entries[idx] = entry
                        } else {
                            self.entries.append(entry)
                        }
                    }
                    self.entries.sort { $0.importedAt > $1.importedAt }
                    self.lastScanAt = scanStart
                    let snapshot = self.entries
                    ContextEngine.shared.indexQueue.async { ContextEngine.shared.rebuildIndex(with: snapshot) }
                    EmbeddingService.shared.scheduleIndexEntries(changed)
                    self.isLoading = false
                }
            } else {
                let scanned = self.scanDirectory(knowledgeURL).sorted { $0.importedAt > $1.importedAt }
                ContextEngine.shared.indexQueue.async { ContextEngine.shared.rebuildIndex(with: scanned) }
                EmbeddingService.shared.scheduleIndexEntries(scanned)
                DispatchQueue.main.async {
                    self.entries = scanned
                    self.lastScanAt = scanStart
                    self.isLoading = false
                }
            }
        }
    }

    private func scanDirectory(_ url: URL, changedSince since: Date? = nil) -> [KnowledgeEntry] {
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let boundary = since.map { $0.addingTimeInterval(-1) }
        var results: [KnowledgeEntry] = []
        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "md" || fileURL.pathExtension == "markdown" else { continue }
            if fileURL.path.contains("/integrations/agent/") { continue }
            if let boundary {
                let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                if modDate < boundary { continue }
            }
            if let entry = parseEntry(at: fileURL) {
                results.append(entry)
            }
        }
        return results
    }

    private func allFilePaths(in url: URL) -> [URL] {
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
        else { return [] }
        var paths: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "md" || fileURL.pathExtension == "markdown" else { continue }
            if fileURL.path.contains("/integrations/agent/") { continue }
            paths.append(fileURL)
        }
        return paths
    }

    // MARK: - Parse

    func parseEntry(at url: URL) -> KnowledgeEntry? {
        guard let data = fm.contents(atPath: url.path),
              let text = String(data: data, encoding: .utf8) else { return nil }

        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? data.count
        let createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()

        let (frontmatter, body) = parseFrontmatter(text)

        let title = frontmatter["title"] ?? url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ").replacingOccurrences(
            of: "-",
            with: " "
        )
        let source = frontmatter["source"] ?? inferSource(from: url)

        var tags: [String] = []
        if let tagStr = frontmatter["tags"] {
            tags = tagStr
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        let importedAt: Date = if let dateStr = frontmatter["imported_at"] ?? frontmatter["synced_at"] ?? frontmatter["created_at"] {
            ISO8601DateFormatter().date(from: dateStr) ?? createdAt
        } else {
            createdAt
        }

        let bucket = frontmatter["bucket"] ?? frontmatter["folder"] ?? inferBucket(from: url)

        return KnowledgeEntry(
            title: title,
            source: source,
            sourceURL: frontmatter["url"],
            tags: tags,
            importedAt: importedAt,
            content: body,
            filePath: url,
            fileSize: fileSize,
            bucket: bucket
        )
    }

    private func inferBucket(from url: URL) -> String {
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
        var currentListKey: String? = nil
        var currentListItems: [String] = []

        func flushList() {
            if let key = currentListKey, !currentListItems.isEmpty {
                frontmatter[key] = "[\(currentListItems.joined(separator: ", "))]"
            }
            currentListKey = nil
            currentListItems = []
        }

        for i in 1..<lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                flushList()
                bodyStartIndex = i + 1
                break
            }
            // Collect multi-line list items (e.g. "  - tag1")
            if trimmed.hasPrefix("- "), currentListKey != nil {
                currentListItems.append(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                continue
            }
            flushList()
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                if value.isEmpty {
                    currentListKey = key
                } else {
                    frontmatter[key] = value
                }
            }
        }
        flushList()

        let body = lines[bodyStartIndex...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (frontmatter, body)
    }

    // MARK: - CRUD

    func createEntry(title: String, content: String, source: String, tags: [String] = [], sourceURL: String? = nil, bucket: String = "General") {
        let dir = StorageService.shared.knowledgeURL.appendingPathComponent(bucket.slugified)
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
        md += "bucket: \(bucket)\n"
        if let url = sourceURL { md += "url: \(url)\n" }
        if !tags.isEmpty { md += "tags: [\(tags.joined(separator: ", "))]\n" }
        md += "imported_at: \(ISO8601DateFormatter().string(from: Date()))\n"
        md += "---\n\n"
        md += content

        try? md.write(to: fileURL, atomically: true, encoding: .utf8)
        reload()

        if tags.isEmpty, let entry = parseEntry(at: fileURL) {
            Task {
                await KnowledgeExtractionService.shared.autoTagAndUpdate(entry: entry)
            }
        }
    }

    // MARK: - Bucket Management

    var buckets: [String] {
        var all = Set(entries.map(\.bucket))
        // Include empty bucket directories so newly created buckets appear immediately
        let base = StorageService.shared.knowledgeURL
        if let dirs = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for dir in dirs {
                let isDir = (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                if isDir { all.insert(dir.lastPathComponent.capitalized) }
            }
        }
        var result = all.sorted()
        if !result.contains("General") { result.insert("General", at: 0) }
        return result
    }

    func createBucket(named name: String) {
        let dir = StorageService.shared.knowledgeURL.appendingPathComponent(name.slugified)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        reload()
    }

    func moveEntry(_ entry: KnowledgeEntry, to bucket: String) {
        let destDir = StorageService.shared.knowledgeURL.appendingPathComponent(bucket.slugified)
        try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        let destURL = destDir.appendingPathComponent(entry.filePath.lastPathComponent)
        guard destURL != entry.filePath else { return }

        guard let data = fm.contents(atPath: entry.filePath.path),
              let text = String(data: data, encoding: .utf8) else { return }

        let (frontmatter, body) = parseFrontmatter(text)

        let orderedKeys = ["title", "source", "bucket", "url", "tags", "imported_at"]
        var updated = frontmatter
        updated.removeValue(forKey: "folder")
        updated["bucket"] = bucket

        var md = "---\n"
        for key in orderedKeys {
            if let value = updated[key] { md += "\(key): \(value)\n" }
        }
        for (key, value) in updated where !orderedKeys.contains(key) {
            md += "\(key): \(value)\n"
        }
        md += "---\n\n\(body)"

        var finalDestURL = destURL
        if fm.fileExists(atPath: finalDestURL.path) {
            let base = destURL.deletingPathExtension().lastPathComponent
            let ext = destURL.pathExtension
            var counter = 2
            repeat {
                finalDestURL = destDir.appendingPathComponent("\(base)-\(counter).\(ext)")
                counter += 1
            } while fm.fileExists(atPath: finalDestURL.path)
        }
        try? md.write(to: finalDestURL, atomically: true, encoding: .utf8)
        try? fm.removeItem(at: entry.filePath)
        reload()
    }

    func renameEntry(_ entry: KnowledgeEntry, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let text = try? String(contentsOf: entry.filePath, encoding: .utf8) else { return }
        let (frontmatter, body) = parseFrontmatter(text)
        let orderedKeys = ["title", "source", "bucket", "url", "tags", "imported_at"]
        var updated = frontmatter
        updated["title"] = trimmed
        var md = "---\n"
        for key in orderedKeys {
            if let value = updated[key] { md += "\(key): \(value)\n" }
        }
        for (key, value) in updated where !orderedKeys.contains(key) {
            md += "\(key): \(value)\n"
        }
        md += "---\n\n\(body)"
        try? md.write(to: entry.filePath, atomically: true, encoding: .utf8)
        reload()
    }

    func deleteEntry(_ entry: KnowledgeEntry) {
        try? fm.removeItem(at: entry.filePath)
        entries.removeAll { $0.id == entry.id }
        EmbeddingService.shared.removeEntry(entry.id)
        let snapshot = entries
        ContextEngine.shared.indexQueue.async {
            ContextEngine.shared.rebuildIndex(with: snapshot)
        }
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
        let matchedIDs = Set(bundle.parts.map(\.id))

        return entries
            .filter { matchedIDs.contains($0.id) }
            .prefix(maxResults)
            .map(\.self)
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
