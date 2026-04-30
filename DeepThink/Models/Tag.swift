import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "#808080"

    @Relationship(inverse: \Note.tags) var notes: [Note] = []
    @Relationship(inverse: \TaskItem.tags) var tasks: [TaskItem] = []

    init(name: String, color: String = "#808080") {
        self.id = UUID()
        self.name = name
        self.color = color
    }
}
