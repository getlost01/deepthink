import Foundation
import SwiftData

@Model
final class Reminder {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var reminderDate: Date?
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var completedAt: Date?
    var notificationScheduled: Bool = false

    var project: Project?

    init(title: String, notes: String = "", reminderDate: Date? = nil) {
        id = UUID()
        self.title = title
        self.notes = notes
        self.reminderDate = reminderDate
        createdAt = Date()
        modifiedAt = Date()
    }

    var isOverdue: Bool {
        guard let reminderDate, !isCompleted else { return false }
        return reminderDate < Date()
    }

    var isPending: Bool {
        guard let reminderDate, !isCompleted else { return false }
        return reminderDate > Date()
    }
}
