import Foundation
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case chat = "AI Chat"
    case deepSearch = "Deep Search"
    case analysis = "Analysis"
    case memory = "Memory"
    case notes = "Notes"
    case tasks = "Tasks"
    case projects = "Projects"
    case tools = "Tools & MCP"
    case graph = "Knowledge Graph"
    case terminal = "Terminal"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: "house"
        case .chat: "bubble.left.and.bubble.right"
        case .deepSearch: "sparkle.magnifyingglass"
        case .analysis: "wand.and.rays"
        case .memory: "brain"
        case .notes: "doc.text"
        case .tasks: "checklist"
        case .projects: "folder"
        case .tools: "wrench.and.screwdriver"
        case .graph: "point.3.connected.trianglepath.dotted"
        case .terminal: "terminal"
        }
    }

    var color: Color {
        switch self {
        case .home: .blue
        case .chat: .blue
        case .deepSearch: .orange
        case .analysis: .green
        case .memory: .purple
        case .notes: .blue
        case .tasks: .green
        case .projects: .teal
        case .tools: .teal
        case .graph: .cyan
        case .terminal: .gray
        }
    }
}

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
        case .low: "chevron.down"
        case .medium: "chevron.up.chevron.down"
        case .high: "chevron.up"
        case .urgent: "exclamationmark"
        }
    }

    var color: Color {
        switch self {
        case .none: .secondary
        case .low: .blue
        case .medium: .yellow
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
