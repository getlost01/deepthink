import Foundation
import SwiftUI

// MARK: - Navigation

enum SidebarSection: String, Identifiable {
    case workspace = "Workspace"
    case knowledge = "Knowledge"
    case ai = "AI Bot"
    case integrations = "Integrations"
    case agentConfig = "Agent Config"
    case terminal = "Terminal"
    case settings = "Settings"

    var id: String { rawValue }

    static var mainSections: [SidebarSection] {
        [.workspace, .knowledge, .ai, .integrations, .agentConfig, .terminal]
    }

    var icon: String {
        switch self {
        case .workspace: "square.grid.2x2"
        case .knowledge: "brain"
        case .ai: "sparkles"
        case .integrations: "puzzlepiece.extension"
        case .agentConfig: "person.2.circle"
        case .terminal: "terminal"
        case .settings: "gear"
        }
    }

    var tooltip: String {
        switch self {
        case .workspace: "Projects, notes, and tasks"
        case .knowledge: "Browse, search, and manage your knowledge base"
        case .ai: "Chat with Claude AI using your knowledge"
        case .integrations: "MCP servers and Claude AI settings"
        case .agentConfig: "Custom AI agents, skills, and rules"
        case .terminal: "Built-in terminal sessions"
        case .settings: "Claude model and configuration"
        }
    }

    var subtitle: String {
        switch self {
        case .workspace: "Your projects, notes, and tasks in one place"
        case .knowledge: "Collect, browse, and search your knowledge"
        case .ai: "Chat with AI that knows your workspace"
        case .integrations: "Connect tools and configure Claude"
        case .agentConfig: "Build custom AI workflows"
        case .terminal: "Run commands and scripts"
        case .settings: "Model selection and usage"
        }
    }
}

enum AgentConfigTab: String, CaseIterable, Identifiable {
    case agents = "Agents"
    case skillsAndRules = "Skills & Rules"

    var id: String { rawValue }

    var icon: String {
        switch self {
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

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: "house"
        case .projects: "folder"
        case .notes: "doc.text"
        case .tasks: "checklist"
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
