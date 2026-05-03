import Foundation
import SwiftUI

// MARK: - Navigation

enum SidebarSection: String, Identifiable {
    case workspace = "Workspace"
    case knowledge = "Knowledge"
    case ai = "AI Chat"
    case integrations = "Connections"
    case agentConfig = "AI Assistants"
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
        case .knowledge: "Save and search anything you learn"
        case .ai: "Ask AI questions about your work"
        case .integrations: "Add tools and services for AI to use"
        case .agentConfig: "Create custom AI helpers for different tasks"
        case .terminal: "Built-in terminal sessions"
        case .settings: "Choose AI model and preferences"
        }
    }

    var subtitle: String {
        switch self {
        case .workspace: "Your projects, notes, and tasks in one place"
        case .knowledge: "Save articles, ideas, and research in one place"
        case .ai: "Ask questions, brainstorm, or get help with your work"
        case .integrations: "Connect tools and services to make AI more powerful"
        case .agentConfig: "Set up specialized AI helpers for different kinds of work"
        case .terminal: "Run commands and scripts"
        case .settings: "Model selection and usage"
        }
    }

    var helpText: String {
        switch self {
        case .workspace: "This is your home base. Create projects to organize your work, write notes to capture ideas, and add tasks to track what needs doing."
        case .knowledge: "Think of this as your second brain. Save web articles, paste text from anywhere, or write things down. Everything here can be used by AI to give you better answers."
        case .ai: "Chat with AI that has access to your notes and knowledge. Pick an assistant suited to your task, or just ask a question."
        case .integrations: "Connections let AI access external tools like web search, databases, or file systems. Enable what you need, disable what you don't."
        case .agentConfig: "Assistants are AI helpers with specific personalities and expertise. Use a template to get started, or build your own from scratch."
        case .terminal: "A built-in command line for running scripts and system commands."
        case .settings: "Choose which AI model to use and track your usage."
        }
    }
}

enum AgentConfigTab: String, CaseIterable, Identifiable {
    case agents = "Assistants"
    case skillsAndRules = "Automations"

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
