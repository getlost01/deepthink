import Foundation

struct KnowledgeEntry: Identifiable, Hashable {
    var id: String { filePath.path }
    var title: String
    var source: String
    var sourceURL: String?
    var tags: [String]
    var importedAt: Date
    var content: String
    var filePath: URL
    var fileSize: Int
    var bucket: String

    var sourceIcon: String {
        switch source {
        case "url", "web": return "globe"
        case "folder", "import": return "archivebox"
        case "clipboard": return "doc.on.clipboard"
        case "script": return "terminal"
        case "mcp": return "puzzlepiece.extension"
        case "manual": return "pencil"
        default: return "doc.text"
        }
    }

    var preview: String {
        String(content.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var formattedSize: String {
        if fileSize < 1024 { return "\(fileSize) B" }
        if fileSize < 1024 * 1024 { return "\(fileSize / 1024) KB" }
        return String(format: "%.1f MB", Double(fileSize) / (1024 * 1024))
    }
}
