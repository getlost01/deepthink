import Foundation
import SwiftData
import AppKit

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
        var text = html
        text = text.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<p[^>]*>", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<h[1-6][^>]*>", with: "\n\n# ", options: .regularExpression)
        text = text.replacingOccurrences(of: "<li[^>]*>", with: "\n- ", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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

        let entryTitle = title ?? "Clipboard \(Date().formatted(date: .abbreviated, time: .shortened))"
        KnowledgeService.shared.createEntry(
            title: entryTitle,
            content: content,
            source: "clipboard",
            tags: ["clipboard"]
        )
        return true
    }

    // MARK: - Folder Import

    func importFolder(at path: String) -> Int {
        let folderURL = URL(fileURLWithPath: path)
        guard fm.fileExists(atPath: path) else { return 0 }

        let destDir = StorageService.shared.knowledgeURL.appendingPathComponent("folders").appendingPathComponent(folderURL.lastPathComponent)
        try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        var count = 0
        guard let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return 0 }

        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "md" || fileURL.pathExtension == "markdown" || fileURL.pathExtension == "txt" else { continue }

            let destURL = destDir.appendingPathComponent(fileURL.lastPathComponent)
            if !fm.fileExists(atPath: destURL.path) {
                try? fm.copyItem(at: fileURL, to: destURL)
                count += 1
            }
        }

        KnowledgeService.shared.reload()
        return count
    }

    // MARK: - Script Runner

    func runScript(command: String) async -> Bool {
        return await withCheckedContinuation { continuation in
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
                        KnowledgeService.shared.createEntry(
                            title: "Script Output \(Date().formatted(date: .abbreviated, time: .shortened))",
                            content: output,
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

    func importFile(at url: URL) -> Bool {
        let destDir = StorageService.shared.knowledgeURL.appendingPathComponent("imports")
        try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        let destURL = destDir.appendingPathComponent(url.lastPathComponent)
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

    // MARK: - Sync Data Source

    func sync(source: DataSource, container: ModelContainer) async {
        isSyncing = true
        defer { isSyncing = false }

        switch source.type {
        case .folder:
            if let path = source.path {
                let count = importFolder(at: path)
                await MainActor.run {
                    source.itemCount = count
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
        }
    }
}
