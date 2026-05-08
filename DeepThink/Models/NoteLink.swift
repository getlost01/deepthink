import Foundation
import SwiftData

@Model
final class NoteLink {
    var id: UUID = UUID()
    var sourceNoteID: UUID = UUID()
    var targetNoteID: UUID = UUID()
    var createdAt: Date = Date()

    init(sourceNoteID: UUID, targetNoteID: UUID) {
        id = UUID()
        self.sourceNoteID = sourceNoteID
        self.targetNoteID = targetNoteID
        createdAt = Date()
    }
}
