import Foundation
import SwiftData
import SwiftUI

enum ReminderPriority: Int, CaseIterable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    var label: String {
        switch self {
        case .none: "No Priority"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var icon: String {
        switch self {
        case .none: "minus"
        case .low: "arrow.down"
        case .medium: "equal"
        case .high: "arrow.up"
        }
    }

    var color: Color {
        switch self {
        case .none: DS.Colors.textTertiary
        case .low: DS.Colors.success
        case .medium: DS.Colors.warning
        case .high: DS.Colors.danger
        }
    }
}

enum ReminderRepeat: String, CaseIterable {
    case none
    case daily
    case weekly
    case monthly
    case yearly

    var label: String {
        switch self {
        case .none: "No Repeat"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    var shortLabel: String {
        switch self {
        case .none: "Repeat"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}

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
    var priorityRaw: Int = 0
    var repeatIntervalRaw: String = "none"

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

    var priority: ReminderPriority {
        get { ReminderPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var repeatInterval: ReminderRepeat {
        get { ReminderRepeat(rawValue: repeatIntervalRaw) ?? .none }
        set { repeatIntervalRaw = newValue.rawValue }
    }
}
