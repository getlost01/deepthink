import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    var summary: String = ""
    var color: String = "#007AFF"
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var isArchived: Bool = false

    @Relationship(inverse: \Note.project) var notes: [Note] = []
    @Relationship(inverse: \TaskItem.project) var tasks: [TaskItem] = []

    init(name: String, summary: String = "", color: String = "#007AFF") {
        id = UUID()
        self.name = name
        self.summary = summary
        self.color = color
        createdAt = Date()
        modifiedAt = Date()
        isArchived = false
    }

    var openTaskCount: Int {
        tasks.count(where: { !$0.isArchived && $0.status != .done && $0.status != .cancelled })
    }

    var completedTaskCount: Int {
        tasks.count(where: { $0.status == .done })
    }

    var totalStoryPoints: Int {
        tasks.compactMap(\.storyPoints).reduce(0, +)
    }

    var completedStoryPoints: Int {
        tasks.filter { $0.status == .done }.compactMap(\.storyPoints).reduce(0, +)
    }
}
