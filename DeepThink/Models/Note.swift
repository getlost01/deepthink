import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var isPinned: Bool = false
    var isArchived: Bool = false

    var project: Project?
    var tags: [Tag] = []

    init(title: String, content: String = "") {
        id = UUID()
        self.title = title
        self.content = content
        createdAt = Date()
        modifiedAt = Date()
        isPinned = false
    }

    var wordCount: Int {
        content.split(whereSeparator: \.isWhitespace).count
    }

    var characterCount: Int {
        content.count
    }

    var firstLine: String {
        let line = content.prefix(while: { $0 != "\n" })
        return line.isEmpty ? "No content" : String(line.prefix(100))
    }
}
