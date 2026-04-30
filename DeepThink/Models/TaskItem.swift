import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var detail: String = ""
    var statusRaw: String = TaskStatus.todo.rawValue
    var priorityRaw: String = TaskPriority.none.rawValue
    var storyPoints: Int?
    var dueDate: Date?
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var completedAt: Date?

    var project: Project?
    var tags: [Tag] = []

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set {
            statusRaw = newValue.rawValue
            if newValue == .done { completedAt = Date() }
            else { completedAt = nil }
        }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    init(title: String, detail: String = "", status: TaskStatus = .todo, priority: TaskPriority = .none) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.statusRaw = status.rawValue
        self.priorityRaw = priority.rawValue
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    var isOverdue: Bool {
        guard let dueDate, status != .done, status != .cancelled else { return false }
        return dueDate < Date()
    }
}
