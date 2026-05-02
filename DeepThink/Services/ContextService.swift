import Foundation
import SwiftUI

// MARK: - Models

struct ContextItem: Identifiable {
    var id: String { filePath }
    let source: String
    let channel: String
    let filename: String
    let timestamp: Date
    let content: String
    let metadata: [String: String]
    let filePath: String
}

struct ContextSource: Identifiable {
    let id: String
    let name: String
    let channels: [ContextChannel]
    let icon: String
    let color: Color
    let totalItems: Int
    let lastUpdated: Date?
}

struct ContextChannel: Identifiable {
    var id: String { "\(source)/\(name)" }
    let name: String
    let source: String
    let itemCount: Int
    let lastUpdated: Date?
}

// MARK: - Service

@Observable
final class ContextService {
    static let shared = ContextService()

    var sources: [ContextSource] = []
    var allItems: [ContextItem] = []
    var isLoading: Bool = false

    private let fm = FileManager.default
    private let integrationsURL = StorageService.shared.knowledgeIntegrationsURL
    private let projectsURL = StorageService.shared.knowledgeProjectsURL

    private init() {}

    // MARK: - Public

    func loadSources() {
        isLoading = true
        defer { isLoading = false }

        var result: [ContextSource] = []

        // Scan integrations directory
        guard let sourceDirs = try? fm.contentsOfDirectory(
            at: integrationsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            sources = []
            return
        }

        for sourceDir in sourceDirs {
            guard isDirectory(sourceDir) else { continue }
            let sourceName = sourceDir.lastPathComponent

            var channels: [ContextChannel] = []
            var totalItems = 0
            var latestDate: Date?

            if let channelDirs = try? fm.contentsOfDirectory(
                at: sourceDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for channelDir in channelDirs {
                    guard isDirectory(channelDir) else { continue }
                    let channelName = channelDir.lastPathComponent

                    let mdFiles = (try? fm.contentsOfDirectory(
                        at: channelDir,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    ))?.filter { $0.pathExtension == "md" } ?? []

                    let channelLatest = mdFiles.compactMap { parseTimestamp($0.deletingPathExtension().lastPathComponent) }.max()

                    channels.append(ContextChannel(
                        name: channelName,
                        source: sourceName,
                        itemCount: mdFiles.count,
                        lastUpdated: channelLatest
                    ))

                    totalItems += mdFiles.count
                    if let cl = channelLatest {
                        latestDate = latestDate.map { max($0, cl) } ?? cl
                    }
                }
            }

            channels.sort { ($0.lastUpdated ?? .distantPast) > ($1.lastUpdated ?? .distantPast) }

            result.append(ContextSource(
                id: sourceName,
                name: sourceName.capitalized,
                channels: channels,
                icon: Self.iconForSource(sourceName),
                color: Self.colorForSource(sourceName),
                totalItems: totalItems,
                lastUpdated: latestDate
            ))
        }

        result.sort { $0.totalItems > $1.totalItems }
        sources = result
    }

    func loadItems(source: String, channel: String? = nil) -> [ContextItem] {
        var items: [ContextItem] = []
        let sourceURL = integrationsURL.appendingPathComponent(source)

        let channelDirs: [URL]
        if let channel {
            channelDirs = [sourceURL.appendingPathComponent(channel)]
        } else {
            channelDirs = (try? fm.contentsOfDirectory(
                at: sourceURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ))?.filter { isDirectory($0) } ?? []
        }

        for channelDir in channelDirs {
            let channelName = channelDir.lastPathComponent
            let mdFiles = (try? fm.contentsOfDirectory(
                at: channelDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ))?.filter { $0.pathExtension == "md" } ?? []

            for file in mdFiles {
                if let item = readItem(at: file.path, source: source, channel: channelName) {
                    items.append(item)
                }
            }
        }

        return items.sorted { $0.timestamp > $1.timestamp }
    }

    func loadItem(at path: String) -> ContextItem? {
        let url = URL(fileURLWithPath: path)
        // Derive source/channel from path structure: .../integrations/{source}/{channel}/{file}.md
        let components = url.pathComponents
        guard components.count >= 3 else { return nil }
        let channel = components[components.count - 2]
        let source = components[components.count - 3]
        return readItem(at: path, source: source, channel: channel)
    }

    func search(query: String) -> [ContextItem] {
        let q = query.lowercased()
        guard !q.isEmpty else { return allItems }

        // Load all items if not cached
        if allItems.isEmpty {
            var items: [ContextItem] = []
            for source in sources {
                items.append(contentsOf: loadItems(source: source.id))
            }
            allItems = items
        }

        return allItems.filter { item in
            item.content.localizedCaseInsensitiveContains(q) ||
            item.channel.localizedCaseInsensitiveContains(q) ||
            item.source.localizedCaseInsensitiveContains(q) ||
            item.metadata.values.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    // MARK: - Static Helpers

    static func iconForSource(_ source: String) -> String {
        switch source.lowercased() {
        case "slack": return "number"
        case "github": return "arrow.triangle.branch"
        case "linear": return "chart.bar.xaxis"
        case "web": return "globe"
        case "jira": return "ticket"
        case "google-docs", "gdocs": return "doc.text"
        default: return "folder"
        }
    }

    static func colorForSource(_ source: String) -> Color {
        switch source.lowercased() {
        case "slack": return .blue
        case "github": return .gray
        case "linear": return .blue
        case "web": return .orange
        case "jira": return .blue
        default: return .teal
        }
    }

    // MARK: - Private

    private func readItem(at path: String, source: String, channel: String) -> ContextItem? {
        guard let data = fm.contents(atPath: path),
              let rawContent = String(data: data, encoding: .utf8) else { return nil }

        let url = URL(fileURLWithPath: path)
        let filename = url.deletingPathExtension().lastPathComponent
        let timestamp = parseTimestamp(filename) ?? (try? fm.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? Date()
        let (metadata, content) = parseFrontmatter(rawContent)

        return ContextItem(
            source: source,
            channel: channel,
            filename: filename,
            timestamp: timestamp,
            content: content,
            metadata: metadata,
            filePath: path
        )
    }

    private func parseFrontmatter(_ content: String) -> ([String: String], String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return ([:], content) }

        let lines = trimmed.components(separatedBy: "\n")
        guard lines.count > 1 else { return ([:], content) }

        var metadata: [String: String] = [:]
        var endIndex = -1

        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line == "---" {
                endIndex = i
                break
            }
            // Parse "- **key**: value" format
            if line.hasPrefix("- **"),
               let keyEnd = line.range(of: "**:"),
               let keyStart = line.range(of: "- **") {
                let key = String(line[keyStart.upperBound..<keyEnd.lowerBound])
                let value = String(line[keyEnd.upperBound...]).trimmingCharacters(in: .whitespaces)
                metadata[key] = value
            }
        }

        if endIndex > 0 {
            let bodyLines = Array(lines[(endIndex + 1)...])
            let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return (metadata, body)
        }

        return ([:], content)
    }

    private func parseTimestamp(_ filename: String) -> Date? {
        // Format: 20260501T053133
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: filename)
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
