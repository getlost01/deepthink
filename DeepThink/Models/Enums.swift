import Foundation
import SwiftUI

// MARK: - Navigation

enum SidebarSection: String, Identifiable {
    case recent = "Recent"
    case workspace = "Workspace"
    case knowledge = "Knowledge"
    case aiAssistant = "AI Assistant"
    case reminders = "Reminders"
    case integrations = "Integrations"
    case terminal = "Terminal"
    case contextGraph = "Context Graph"
    case settings = "Settings"

    var id: String {
        rawValue
    }

    static var topSections: [SidebarSection] {
        [.recent]
    }

    static var mainSections: [SidebarSection] {
        [.workspace, .knowledge, .contextGraph, .aiAssistant, .reminders]
    }

    static var toolSections: [SidebarSection] {
        [.integrations, .terminal]
    }

    var icon: String {
        switch self {
        case .recent: "clock.arrow.circlepath"
        case .workspace: "square.grid.2x2"
        case .knowledge: "brain"
        case .aiAssistant: "message.and.waveform"
        case .reminders: "bell"
        case .integrations: "puzzlepiece.extension"
        case .terminal: "terminal"
        case .contextGraph: "point.3.connected.trianglepath.dotted"
        case .settings: "gear"
        }
    }

    var tooltip: String {
        switch self {
        case .recent: "Recent activity across your workspace"
        case .workspace: "Projects, notes, and tasks"
        case .knowledge: "Save and search anything you learn"
        case .aiAssistant: "Chat, assistants, and automations"
        case .reminders: "Set reminders with optional times"
        case .integrations: "Add tools and services for AI to use"
        case .terminal: "Built-in terminal sessions"
        case .contextGraph: "Semantic similarity graph of your knowledge"
        case .settings: "Choose AI model and preferences"
        }
    }

    var subtitle: String {
        switch self {
        case .recent: "See what happened recently across your workspace"
        case .workspace: "Your projects, notes, and tasks in one place"
        case .knowledge: "Save articles, ideas, and research in one place"
        case .aiAssistant: "Chat with AI, manage assistants and automations"
        case .reminders: "Things to remember, with optional time alerts"
        case .integrations: "Connect tools and services to make AI more powerful"
        case .terminal: "Run commands and scripts"
        case .contextGraph: "Visualize how your knowledge connects semantically"
        case .settings: "Model selection and usage"
        }
    }

    var helpText: String {
        switch self {
        case .recent: "See all recent activity — notes edited, tasks completed, knowledge added — in one timeline."
        case .workspace: "This is your home base. Create projects to organize your work, write notes to capture ideas, and add tasks to track what needs doing."
        case .knowledge:
            "Think of this as your second brain. Save web articles, paste text from anywhere, or write things down. " +
                "Everything here can be used by AI to give you better answers."
        case .aiAssistant: "Chat with AI that has access to your notes and knowledge. Manage assistants and automations from the tabs."
        case .reminders: "Keep track of things you need to remember. Optionally set a date and time to get notified."
        case .integrations:
            "Connections let AI access external tools like web search, databases, or file systems. " +
                "Enable what you need, disable what you don't."
        case .terminal: "A built-in command line for running scripts and system commands."
        case .contextGraph:
            "See which knowledge entries are semantically related. Nodes are entries, edges are similarity. " +
                "Search to highlight relevant clusters."
        case .settings: "Choose which AI model to use and track your usage."
        }
    }
}

enum AgentConfigTab: String, CaseIterable, Identifiable {
    case agents = "Assistants"
    case skills = "Skills"
    case rules = "Rules"

    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .agents: "person.2.circle"
        case .skills: "sparkles"
        case .rules: "bolt"
        }
    }
}

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case projects = "Projects"
    case notes = "Notes"
    case tasks = "Tasks"

    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
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

    var id: String {
        rawValue
    }

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
        case .backlog: DS.Colors.slate
        case .todo: DS.Colors.accent
        case .inProgress: DS.Colors.warning
        case .done: DS.Colors.success
        case .cancelled: DS.Colors.danger
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

    var id: String {
        rawValue
    }

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
        case .none: DS.Colors.slate
        case .low: DS.Colors.info
        case .medium: DS.Colors.amber
        case .high: DS.Colors.warning
        case .urgent: DS.Colors.danger
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
