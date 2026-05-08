import Foundation

@Observable
final class ObsidianImportService {
    static let shared = ObsidianImportService()

    var isImporting = false
    var importProgress: Double = 0
    var importedCount = 0
    var skippedCount = 0
    var totalCount = 0
    var lastImportError: String?

    private let fm = FileManager.default
    private init() {}

    // MARK: - Options & Result

    struct ImportOptions {
        var folderName: String = "obsidian"
        var preserveStructure: Bool = true
        var convertWikiLinks: Bool = true
        var extractTags: Bool = true
        var skipDuplicates: Bool = true
        var skipBinaryFiles: Bool = true
    }

    struct ImportResult {
        var imported: Int
        var skipped: Int
        var duplicates: Int
        var errors: Int
        var totalFound: Int
    }

    // MARK: - Scan

    func scanVault(at vaultURL: URL) -> (fileCount: Int, totalSize: Int64) {
        guard let enumerator = fm.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return (0, 0) }

        var count = 0
        var size: Int64 = 0
        while let url = enumerator.nextObject() as? URL {
            let ext = url.pathExtension.lowercased()
            guard ext == "md" || ext == "markdown" else { continue }
            count += 1
            if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = values.fileSize {
                size += Int64(fileSize)
            }
        }
        return (count, size)
    }

    // MARK: - Import

    @MainActor
    func importVault(at vaultURL: URL, options: ImportOptions) async -> ImportResult {
        isImporting = true
        importProgress = 0
        importedCount = 0
        skippedCount = 0
        lastImportError = nil

        defer {
            isImporting = false
            KnowledgeService.shared.reload()
        }

        // 1. Collect all markdown files
        let mdFiles = collectMarkdownFiles(at: vaultURL)
        totalCount = mdFiles.count

        guard totalCount > 0 else {
            return ImportResult(imported: 0, skipped: 0, duplicates: 0, errors: 0, totalFound: 0)
        }

        var imported = 0
        var skipped = 0
        var duplicates = 0
        var errors = 0

        let destBase = StorageService.shared.knowledgeURL.appendingPathComponent(options.folderName.slugified)
        try? fm.createDirectory(at: destBase, withIntermediateDirectories: true)

        // 2. Process each file
        for (index, fileURL) in mdFiles.enumerated() {
            autoreleasepool {
                do {
                    let result = try processFile(
                        fileURL,
                        vaultRoot: vaultURL,
                        destBase: destBase,
                        options: options
                    )
                    switch result {
                    case .imported:
                        imported += 1
                    case .skippedDuplicate:
                        duplicates += 1
                        skipped += 1
                    case .skippedOther:
                        skipped += 1
                    }
                } catch {
                    errors += 1
                    lastImportError = error.localizedDescription
                }
            }

            importedCount = imported
            skippedCount = skipped + duplicates
            importProgress = Double(index + 1) / Double(totalCount)

            // Yield to main actor periodically for UI updates
            if index % 50 == 0 {
                await Task.yield()
            }
        }

        return ImportResult(
            imported: imported,
            skipped: skipped,
            duplicates: duplicates,
            errors: errors,
            totalFound: totalCount
        )
    }

    // MARK: - File Collection

    private func collectMarkdownFiles(at vaultURL: URL) -> [URL] {
        guard let enumerator = fm.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            let ext = url.pathExtension.lowercased()
            guard ext == "md" || ext == "markdown" else { continue }
            files.append(url)
        }
        return files
    }

    // MARK: - Single File Processing

    private enum ProcessResult {
        case imported
        case skippedDuplicate
        case skippedOther
    }

    private func processFile(
        _ fileURL: URL,
        vaultRoot: URL,
        destBase: URL,
        options: ImportOptions
    ) throws -> ProcessResult {
        guard let data = fm.contents(atPath: fileURL.path),
              let text = String(data: data, encoding: .utf8)
        else {
            throw ImportError.unreadable(fileURL.lastPathComponent)
        }

        // Parse existing frontmatter
        let (existingFM, rawBody) = KnowledgeService.shared.parseFrontmatter(text)

        // Convert Obsidian syntax
        var body = rawBody
        if options.convertWikiLinks {
            body = convertObsidianSyntax(body)
        }

        // Extract tags from body
        var tags: [String] = []
        if let tagStr = existingFM["tags"] {
            tags = tagStr
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#")) }
                .filter { !$0.isEmpty }
        }

        if options.extractTags {
            let extracted = extractInlineTags(from: body)
            let newTags = extracted.filter { !tags.contains($0) }
            tags.append(contentsOf: newTags)
        }

        // Title: from frontmatter or filename
        let title = existingFM["title"]
            ?? fileURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        // Dedup check
        if options.skipDuplicates {
            if ContextEngine.shared.isDuplicateOrSimilar(content: body, threshold: 0.75) {
                return .skippedDuplicate
            }
        }

        // Determine destination path
        let relativePath: String
        if options.preserveStructure {
            let rel = fileURL.deletingLastPathComponent().path
                .replacingOccurrences(of: vaultRoot.path, with: "")
            relativePath = rel.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            relativePath = ""
        }

        let destDir: URL = if relativePath.isEmpty {
            destBase
        } else {
            destBase.appendingPathComponent(relativePath)
        }
        try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Build folder name for frontmatter
        let folderComponents = [options.folderName, relativePath].filter { !$0.isEmpty }
        let folder = folderComponents.joined(separator: "/")

        // Build DeepThink frontmatter
        let isoFormatter = ISO8601DateFormatter()
        var md = "---\n"
        md += "title: \(title)\n"
        md += "source: obsidian\n"
        md += "folder: \(folder)\n"
        if !tags.isEmpty { md += "tags: [\(tags.joined(separator: ", "))]\n" }
        if let aliases = existingFM["aliases"] { md += "aliases: \(aliases)\n" }
        md += "imported_at: \(isoFormatter.string(from: Date()))\n"
        md += "---\n\n"
        md += body

        // Write file
        let filename = fileURL.lastPathComponent
        let destFile = destDir.appendingPathComponent(filename)

        // Skip if already exists at destination
        if fm.fileExists(atPath: destFile.path) {
            return .skippedOther
        }

        try md.write(to: destFile, atomically: true, encoding: .utf8)
        return .imported
    }

    // MARK: - Obsidian Syntax Conversion

    func convertObsidianSyntax(_ text: String) -> String {
        var result = text

        // Remove Obsidian comments %%comment%%
        result = result.replacingOccurrences(
            of: "%%[\\s\\S]*?%%",
            with: "",
            options: .regularExpression
        )

        // Convert embeds ![[image.png]] -> [Embedded: image.png]
        result = result.replacingOccurrences(
            of: "!\\[\\[([^\\]]+)\\]\\]",
            with: "[Embedded: $1]",
            options: .regularExpression
        )

        // Convert wiki-links with alias [[note|alias]] -> [alias](note)
        result = result.replacingOccurrences(
            of: "\\[\\[([^\\]|]+)\\|([^\\]]+)\\]\\]",
            with: "[$2]($1)",
            options: .regularExpression
        )

        // Convert plain wiki-links [[note name]] -> [note name](note-name)
        let wikiLinkPattern = try! NSRegularExpression(pattern: "\\[\\[([^\\]]+)\\]\\]")
        let nsResult = result as NSString
        let matches = wikiLinkPattern.matches(in: result, range: NSRange(location: 0, length: nsResult.length))

        // Process in reverse to preserve indices
        for match in matches.reversed() {
            let noteNameRange = match.range(at: 1)
            let noteName = nsResult.substring(with: noteNameRange)
            let slug = noteName.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9\\-]", with: "", options: .regularExpression)
            let replacement = "[\(noteName)](\(slug))"
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }

        // Convert callout syntax > [!type] -> > **Type:**
        result = convertCallouts(result)

        return result
    }

    private func convertCallouts(_ text: String) -> String {
        let calloutPattern = try! NSRegularExpression(
            pattern: "> \\[!(\\w+)\\]\\s*(.*)",
            options: .caseInsensitive
        )

        let lines = text.components(separatedBy: "\n")
        var resultLines: [String] = []

        for line in lines {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            if let match = calloutPattern.firstMatch(in: line, range: range) {
                let typeRange = match.range(at: 1)
                let restRange = match.range(at: 2)
                let calloutType = nsLine.substring(with: typeRange).capitalized
                let rest = nsLine.substring(with: restRange).trimmingCharacters(in: .whitespaces)
                if rest.isEmpty {
                    resultLines.append("> **\(calloutType):**")
                } else {
                    resultLines.append("> **\(calloutType):** \(rest)")
                }
            } else {
                resultLines.append(line)
            }
        }

        return resultLines.joined(separator: "\n")
    }

    // MARK: - Tag Extraction

    func extractInlineTags(from text: String) -> [String] {
        // Extract #tags but skip code blocks and headings
        var tags: Set<String> = []
        var inCodeBlock = false

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Toggle code block state
            if trimmed.hasPrefix("```") {
                inCodeBlock = !inCodeBlock
                continue
            }
            if inCodeBlock { continue }

            // Skip headings (# Title)
            if trimmed.hasPrefix("#"), trimmed.contains(" ") {
                // Could be a heading, only extract tags that aren't at the start
                let afterHeading = trimmed.drop(while: { $0 == "#" || $0 == " " })
                extractTagsFromLine(String(afterHeading), into: &tags)
                continue
            }

            extractTagsFromLine(trimmed, into: &tags)
        }

        return Array(tags).sorted()
    }

    private func extractTagsFromLine(_ line: String, into tags: inout Set<String>) {
        // Match #tag patterns (not inside links or at line start as heading)
        let pattern = try! NSRegularExpression(pattern: "(?:^|\\s)#([a-zA-Z][a-zA-Z0-9_/-]*)")
        let nsLine = line as NSString
        let matches = pattern.matches(in: line, range: NSRange(location: 0, length: nsLine.length))

        for match in matches {
            let tagRange = match.range(at: 1)
            let tag = nsLine.substring(with: tagRange)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if tag.count >= 2 {
                tags.insert(tag)
            }
        }
    }

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case let .unreadable(name): "Could not read file: \(name)"
            }
        }
    }
}
