import Foundation
import SwiftUI

// MARK: - Navigation

enum SidebarSection: String, CaseIterable, Identifiable {
    case workspace = "Workspace"
    case ai = "AI"
    case terminal = "Terminal"
    case intelligence = "Intelligence"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .workspace: "square.grid.2x2"
        case .ai: "sparkles"
        case .terminal: "terminal"
        case .intelligence: "brain"
        case .settings: "gear"
        }
    }
}

enum AutomationTab: String, CaseIterable, Identifiable {
    case knowledge = "Knowledge"
    case agents = "Agents"
    case skillsAndRules = "Skills & Rules"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .knowledge: "book"
        case .agents: "person.2.circle"
        case .skillsAndRules: "sparkles"
        }
    }
}

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case projects = "Projects"
    case notes = "Notes"
    case tasks = "Tasks"
    case knowledge = "Knowledge Base"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: "house"
        case .projects: "folder"
        case .notes: "doc.text"
        case .tasks: "checklist"
        case .knowledge: "brain"
        }
    }
}

enum AIMode: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case search = "Search"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .search: "sparkle.magnifyingglass"
        }
    }
}

// MARK: - Tasks

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case backlog = "Backlog"
    case todo = "To Do"
    case inProgress = "In Progress"
    case done = "Done"
    case cancelled = "Cancelled"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .backlog: "circle.dashed"
        case .todo: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .done: "checkmark.circle.fill"
        case .cancelled: "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .backlog: .secondary
        case .todo: .blue
        case .inProgress: .orange
        case .done: .green
        case .cancelled: .red
        }
    }

    var sortOrder: Int {
        switch self {
        case .inProgress: 0
        case .todo: 1
        case .backlog: 2
        case .done: 3
        case .cancelled: 4
        }
    }
}

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .none: "minus"
        case .low: "arrow.down"
        case .medium: "equal"
        case .high: "arrow.up"
        case .urgent: "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .none: .secondary
        case .low: .blue
        case .medium: .orange
        case .high: .orange
        case .urgent: .red
        }
    }

    var sortOrder: Int {
        switch self {
        case .urgent: 0
        case .high: 1
        case .medium: 2
        case .low: 3
        case .none: 4
        }
    }
}
