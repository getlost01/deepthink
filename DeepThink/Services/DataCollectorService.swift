import AppKit
import Foundation
import PDFKit
import SwiftData

@Observable
final class DataCollectorService {
    static let shared = DataCollectorService()

    var isSyncing = false

    private let fm = FileManager.default

    private init() {}

    // MARK: - URL Scraping

    func scrapeURL(_ urlString: String, title: String? = nil) async -> Bool {
        guard let url = URL(string: urlString) else { return false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else { return false }

            let content = extractTextFromHTML(html)
            let pageTitle = title ?? extractTitle(from: html) ?? url.host ?? "Untitled"

            KnowledgeService.shared.createEntry(
                title: pageTitle,
                content: content,
                source: "url",
                tags: ["web"],
                sourceURL: urlString
            )
            return true
        } catch {
            StorageService.shared.writeLog("URL scrape failed: \(error.localizedDescription)", to: "collector")
            return false
        }
    }

    private func extractTextFromHTML(_ html: String) -> String {
        // Cap input before regex to prevent catastrophic backtracking on huge pages
        var text = html.count > 500_000 ? String(html.prefix(500_000)) : html
        // Drop entire head block
        text = text.replacingOccurrences(of: "<head[^>]*>[\\s\\S]*?</head>", with: "", options: .regularExpression)
        // Drop boilerplate structural blocks
        for tag in ["script", "style", "nav", "header", "footer", "aside", "noscript", "svg", "iframe", "form", "figure", "button"] {
            text = text.replacingOccurrences(of: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>", with: "", options: .regularExpression)
        }
        // Block-level spacing
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</?p[^>]*>", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<h[1-6][^>]*>", with: "\n\n## ", options: .regularExpression)
        text = text.replacingOccurrences(of: "</h[1-6]>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<li[^>]*>", with: "\n- ", options: .regularExpression)
        text = text.replacingOccurrences(of: "</?(?:ul|ol|div|section|article|main|td|th)[^>]*>", with: "\n", options: .regularExpression)
        // Strip remaining tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // HTML entities
        let entities: [(String, String)] = [
            ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&apos;", "'"), ("&mdash;", "—"), ("&ndash;", "–"),
            ("&hellip;", "…"), ("&laquo;", "«"), ("&raquo;", "»"), ("&#39;", "'"),
            ("&copy;", "©"), ("&reg;", "®"), ("&trade;", "™")
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        // Decode numeric entities &#NNN; and &#xHH;
        text = text.replacingOccurrences(of: "&#x([0-9a-fA-F]+);", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&#([0-9]+);", with: "", options: .regularExpression)
        // Normalize whitespace
        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        // Drop lines that are pure noise (only whitespace/punctuation, short junk)
        let lines = text.components(separatedBy: "\n")
        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count > 2 else { return false }
            let alphanumCount = trimmed.unicodeScalars.count(where: { CharacterSet.alphanumerics.contains($0) })
            return alphanumCount > 0
        }
        return filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func smartTitle(from content: String, fallback: String) -> String {
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let clean = line
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^[-*>]+\\s*", with: "", options: .regularExpression)
            guard clean.count > 3 else { continue }
            if clean.count <= 80 { return clean }
            let truncated = String(clean.prefix(80))
            if let lastSpace = truncated.lastIndex(of: " ") {
                return String(truncated[..<lastSpace])
            }
            return truncated
        }
        return fallback
    }

    private func extractTitle(from html: String) -> String? {
        guard let range = html.range(of: "<title>(.+?)</title>", options: .regularExpression) else { return nil }
        var title = String(html[range])
        title = title.replacingOccurrences(of: "<title>", with: "")
        title = title.replacingOccurrences(of: "</title>", with: "")
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Clipboard Capture

    @MainActor
    func captureClipboard(title: String? = nil) -> Bool {
        let pb = NSPasteboard.general
        guard let content = pb.string(forType: .string), !content.isEmpty else { return false }

        let entryTitle = title ?? smartTitle(from: content, fallback: "Clipboard — \(Date().formatted(date: .abbreviated, time: .omitted))")
        KnowledgeService.shared.createEntry(
            title: entryTitle,
            content: content,
            source: "clipboard",
            tags: ["clipboard"]
        )
        return true
    }

    // MARK: - PDF Import

    func extractTextFromPDF(at url: URL) -> String? {
        guard let doc = PDFDocument(url: url) else { return nil }
        var pages: [String] = []
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let text = page.string, !text.isEmpty {
                pages.append(text)
            }
        }
        let full = pages.joined(separator: "\n\n")
        return full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : full
    }

    // MARK: - Folder Import

    private static let allImportExtensions: Set<String> = ["md", "markdown", "txt", "pdf"]

    func importFolder(at path: String, folder: String? = nil) -> Int {
        let folderURL = URL(fileURLWithPath: path)
        guard fm.fileExists(atPath: path) else { return 0 }

        let folderName = folder ?? folderURL.lastPathComponent.capitalized
        let destDir = StorageService.shared.knowledgeURL.appendingPathComponent(folderName.slugified)
        try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        var count = 0
        guard let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return 0 }

        while let fileURL = enumerator.nextObject() as? URL {
            guard Self.allImportExtensions.contains(fileURL.pathExtension) else { continue }

            if fileURL.pathExtension == "pdf" {
                let title = fileURL.deletingPathExtension().lastPathComponent
                if let text = extractTextFromPDF(at: fileURL) {
                    _ = KnowledgeService.shared.createEntryIfNotDuplicate(
                        title: title, content: text, source: "pdf", tags: ["pdf", folderName.lowercased()]
                    )
                    count += 1
                }
            } else {
                let stem = fileURL.deletingPathExtension().lastPathComponent
                let ext = fileURL.pathExtension
                let hash = String(abs(fileURL.path.hashValue), radix: 36).prefix(6)
                let destURL = destDir.appendingPathComponent("\(stem)-\(hash).\(ext)")
                if !fm.fileExists(atPath: destURL.path) {
                    try? fm.copyItem(at: fileURL, to: destURL)
                    count += 1
                }
            }
        }

        KnowledgeService.shared.reload()
        return count
    }

    // MARK: - Script Runner

    func runScript(command: String) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                        continuation.resume(returning: false)
                        return
                    }

                    DispatchQueue.main.async {
                        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        KnowledgeService.shared.createEntry(
                            title: self.smartTitle(from: trimmed, fallback: "Script Output — \(Date().formatted(date: .abbreviated, time: .omitted))"),
                            content: "```\n\(trimmed)\n```",
                            source: "script",
                            tags: ["script"]
                        )
                    }
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    // MARK: - Import File

    func importFile(at url: URL, folder: String = "General") -> Bool {
        if url.pathExtension.lowercased() == "pdf" {
            guard let text = extractTextFromPDF(at: url) else { return false }
            let title = url.deletingPathExtension().lastPathComponent
            return KnowledgeService.shared.createEntryIfNotDuplicate(
                title: title, content: text, source: "pdf", tags: ["pdf"]
            )
        }

        let destDir = StorageService.shared.knowledgeURL.appendingPathComponent(folder.slugified)
        try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let hash = String(abs(url.path.hashValue), radix: 36).prefix(6)
        let destURL = destDir.appendingPathComponent("\(stem)-\(hash).\(ext)")

        do {
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: url, to: destURL)
            KnowledgeService.shared.reload()
            return true
        } catch {
            return false
        }
    }

    // MARK: - RSS/Atom Feed Ingestion

    func ingestFeed(_ feedURL: String, maxItems: Int = 10) async -> Int {
        guard let url = URL(string: feedURL) else { return 0 }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let xml = String(data: data, encoding: .utf8) else { return 0 }

            let items = parseRSSItems(xml, maxItems: maxItems)
            var ingested = 0

            for item in items {
                if ContextEngine.shared.isDuplicateOrSimilar(content: item.content, threshold: 0.7) { continue }

                if let itemURL = item.url {
                    let success = await scrapeURL(itemURL, title: item.title)
                    if success { ingested += 1 }
                } else {
                    KnowledgeService.shared.createEntry(
                        title: item.title,
                        content: item.content,
                        source: "url",
                        tags: ["rss", "feed"],
                        sourceURL: feedURL
                    )
                    ingested += 1
                }
            }

            StorageService.shared.writeLog("RSS feed ingested \(ingested) items from \(feedURL)", to: "collector")
            return ingested
        } catch {
            StorageService.shared.writeLog("RSS feed failed: \(error.localizedDescription)", to: "collector")
            return 0
        }
    }

    private struct FeedItem {
        let title: String
        let content: String
        let url: String?
    }

    private func parseRSSItems(_ xml: String, maxItems: Int) -> [FeedItem] {
        var items: [FeedItem] = []
        let itemPattern = "<item[^>]*>([\\s\\S]*?)</item>"
        let entryPattern = "<entry[^>]*>([\\s\\S]*?)</entry>"

        let pattern = xml.contains("<entry") ? entryPattern : itemPattern
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }

        let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))

        for match in matches.prefix(maxItems) {
            guard let range = Range(match.range(at: 1), in: xml) else { continue }
            let itemXML = String(xml[range])

            let title = extractXMLTag("title", from: itemXML) ?? "Untitled"
            let description = extractXMLTag("description", from: itemXML) ?? extractXMLTag("content", from: itemXML) ?? extractXMLTag(
                "summary",
                from: itemXML
            ) ??
                ""
            let link = extractXMLTag("link", from: itemXML) ?? extractXMLAttribute("href", tag: "link", from: itemXML)

            let cleanContent = extractTextFromHTML(description)
            items.append(FeedItem(title: title, content: cleanContent, url: link))
        }

        return items
    }

    private func extractXMLTag(_ tag: String, from xml: String) -> String? {
        let pattern = "<\(tag)[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]></\(tag)>|<\(tag)[^>]*>([\\s\\S]*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)) else { return nil }

        for i in 1...2 {
            if let range = Range(match.range(at: i), in: xml) {
                let result = String(xml[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !result.isEmpty { return result }
            }
        }
        return nil
    }

    private func extractXMLAttribute(_ attr: String, tag: String, from xml: String) -> String? {
        let pattern = "<\(tag)[^>]*\(attr)=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
              let range = Range(match.range(at: 1), in: xml) else { return nil }
        return String(xml[range])
    }

    // MARK: - Watch Folder (detect changes)

    func syncFolderIncremental(at path: String, folder: String? = nil) -> Int {
        let folderURL = URL(fileURLWithPath: path)
        guard fm.fileExists(atPath: path) else { return 0 }

        let folderName = folder ?? folderURL.lastPathComponent.capitalized
        let destDir = StorageService.shared.knowledgeURL.appendingPathComponent(folderName.slugified)
        try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        var count = 0
        guard let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        else { return 0 }

        while let fileURL = enumerator.nextObject() as? URL {
            guard Self.allImportExtensions.contains(fileURL.pathExtension) else { continue }

            if fileURL.pathExtension == "pdf" {
                let sourceDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let title = fileURL.deletingPathExtension().lastPathComponent
                let sentinelURL = destDir.appendingPathComponent("\(title)-\(String(abs(fileURL.path.hashValue), radix: 36).prefix(6)).pdf.imported")
                let sentinelDate = (try? sentinelURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                if !fm.fileExists(atPath: sentinelURL.path) || sourceDate > sentinelDate {
                    if let text = extractTextFromPDF(at: fileURL) {
                        _ = KnowledgeService.shared.createEntryIfNotDuplicate(
                            title: title, content: text, source: "pdf", tags: ["pdf", folderName.lowercased()]
                        )
                        try? "".write(to: sentinelURL, atomically: true, encoding: .utf8)
                        count += 1
                    }
                }
            } else {
                let stem = fileURL.deletingPathExtension().lastPathComponent
                let ext = fileURL.pathExtension
                let hash = String(abs(fileURL.path.hashValue), radix: 36).prefix(6)
                let destURL = destDir.appendingPathComponent("\(stem)-\(hash).\(ext)")
                let sourceDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let destDate = (try? destURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                if !fm.fileExists(atPath: destURL.path) || sourceDate > destDate {
                    try? fm.removeItem(at: destURL)
                    try? fm.copyItem(at: fileURL, to: destURL)
                    count += 1
                }
            }
        }

        if count > 0 { KnowledgeService.shared.reload() }
        return count
    }

    // MARK: - Batch URL Scraping

    func scrapeURLs(_ urls: [String]) async -> Int {
        var success = 0
        // swiftlint:disable for_where
        for url in urls {
            if await scrapeURL(url) { success += 1 }
        }
        // swiftlint:enable for_where
        return success
    }

    // MARK: - Plain Text Capture (API-friendly)

    func captureText(title: String, content: String, source: String = "manual", tags: [String] = []) -> Bool {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return KnowledgeService.shared.createEntryIfNotDuplicate(
            title: title, content: content, source: source, tags: tags
        )
    }

    // MARK: - Sync Data Source

    func sync(source: DataSource, container: ModelContainer) async {
        isSyncing = true
        defer { isSyncing = false }

        switch source.type {
        case .folder:
            if let path = source.path {
                let count = syncFolderIncremental(at: path)
                await MainActor.run {
                    source.itemCount += count
                    source.lastSyncAt = Date()
                }
            }
        case .url:
            if let urlStr = source.url {
                let success = await scrapeURL(urlStr, title: source.name)
                await MainActor.run {
                    if success { source.itemCount += 1 }
                    source.lastSyncAt = Date()
                }
            }
        case .script:
            if let cmd = source.scriptCommand {
                let success = await runScript(command: cmd)
                await MainActor.run {
                    if success { source.itemCount += 1 }
                    source.lastSyncAt = Date()
                }
            }
        case .clipboard:
            await MainActor.run {
                if captureClipboard() { source.itemCount += 1 }
                source.lastSyncAt = Date()
            }
        case .mcp:
            break
        case .rssFeed:
            if let urlStr = source.url {
                let count = await ingestFeed(urlStr)
                await MainActor.run {
                    source.itemCount += count
                    source.lastSyncAt = Date()
                }
            }
        }
    }
}
