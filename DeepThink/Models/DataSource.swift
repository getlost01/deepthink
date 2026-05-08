import Foundation
import SwiftData

@Model
final class DataSource {
    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = "folder"
    var path: String?
    var url: String?
    var scriptCommand: String?
    var scheduleInterval: Int?
    var icon: String = "folder"
    var isEnabled: Bool = true
    var lastSyncAt: Date?
    var itemCount: Int = 0
    var createdAt: Date = Date()

    init(
        name: String = "",
        type: DataSourceType = .folder,
        path: String? = nil,
        url: String? = nil,
        scriptCommand: String? = nil,
        icon: String? = nil
    ) {
        self.name = name
        typeRaw = type.rawValue
        self.path = path
        self.url = url
        self.scriptCommand = scriptCommand
        self.icon = icon ?? type.icon
    }

    var type: DataSourceType {
        get { DataSourceType(rawValue: typeRaw) ?? .folder }
        set { typeRaw = newValue.rawValue; icon = newValue.icon }
    }
}

enum DataSourceType: String, CaseIterable, Identifiable, Codable {
    case folder
    case url
    case script
    case mcp
    case clipboard
    case rssFeed

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .folder: "Folder"
        case .url: "Web Page"
        case .script: "Script"
        case .mcp: "MCP Server"
        case .clipboard: "Clipboard"
        case .rssFeed: "RSS/Atom Feed"
        }
    }

    var icon: String {
        switch self {
        case .folder: "folder"
        case .url: "globe"
        case .script: "terminal"
        case .mcp: "puzzlepiece.extension"
        case .clipboard: "doc.on.clipboard"
        case .rssFeed: "dot.radiowaves.up.forward"
        }
    }

    var description: String {
        switch self {
        case .folder: "Watch a folder for new or changed files"
        case .url: "Scrape web pages into knowledge"
        case .script: "Run a shell script that outputs text"
        case .mcp: "Connect via Model Context Protocol"
        case .clipboard: "Capture clipboard content"
        case .rssFeed: "Auto-import articles from RSS or Atom feeds"
        }
    }
}
