import Foundation
import SwiftData

@Model
final class NoteVersion {
    var id: UUID = UUID()
    var noteID: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var createdAt: Date = Date()
    var versionNumber: Int = 1

    init(note: Note, versionNumber: Int) {
        id = UUID()
        noteID = note.id
        title = note.title
        content = note.content
        createdAt = Date()
        self.versionNumber = versionNumber
    }

    var contentPreview: String {
        String(content.prefix(200))
    }

    var wordCount: Int {
        content.split(whereSeparator: \.isWhitespace).count
    }
}
