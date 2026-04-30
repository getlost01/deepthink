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
        self.id = UUID()
        self.name = name
        self.summary = summary
        self.color = color
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isArchived = false
    }

    var openTaskCount: Int {
        tasks.filter { $0.status != .done && $0.status != .cancelled }.count
    }

    var completedTaskCount: Int {
        tasks.filter { $0.status == .done }.count
    }

    var totalStoryPoints: Int {
        tasks.compactMap(\.storyPoints).reduce(0, +)
    }

    var completedStoryPoints: Int {
        tasks.filter { $0.status == .done }.compactMap(\.storyPoints).reduce(0, +)
    }
}
