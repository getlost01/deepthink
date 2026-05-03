import Foundation
import SwiftUI

@Observable
final class AppState {
    var selectedSection: SidebarSection? = .workspace
    var showCommandPalette: Bool = false
    var searchQuery: String = ""

    // Workspace sub-navigation
    var workspaceTab: WorkspaceTab = .overview
    var selectedNoteID: UUID?
    var selectedTaskID: UUID?
    var selectedProjectID: UUID?
    var filterProjectID: UUID?

    // Project detail sub-navigation
    enum ProjectDetailMode: Equatable {
        case overview
        case taskDetail(UUID)
        case noteDetail(UUID)
    }
    var projectDetailMode: ProjectDetailMode = .overview

    // AI sub-navigation
    var pendingChatMessage: String?
    var selectedAgentPath: String?

    // Chat state (persists across tab switches)
    var chatMessages: [AIMessage] = []
    var isChatProcessing = false
    var chatProcessingStartTime: Date?

    // Agent Config sub-navigation
    var agentConfigTab: AgentConfigTab = .agents

    // Context sub-navigation
    var selectedContextSource: String?
    var selectedContextChannel: String?
    var selectedContextItemPath: String?
    var contextSearchQuery: String = ""

    func navigate(to section: SidebarSection) {
        selectedSection = section
    }

    func navigateToContext(source: String? = nil, channel: String? = nil) {
        selectedSection = .knowledge
        selectedContextSource = source
        selectedContextChannel = channel
    }

    func navigateToNote(_ id: UUID) {
        selectedSection = .workspace
        workspaceTab = .notes
        selectedNoteID = id
    }

    func navigateToTask(_ id: UUID) {
        selectedSection = .workspace
        workspaceTab = .tasks
        selectedTaskID = id
    }

    func navigateToProject(_ id: UUID) {
        selectedSection = .workspace
        workspaceTab = .projects
        selectedProjectID = id
    }

    func navigateToNoteInProject(_ noteID: UUID) {
        projectDetailMode = .noteDetail(noteID)
    }

    func navigateToTaskInProject(_ taskID: UUID) {
        projectDetailMode = .taskDetail(taskID)
    }

    func backToProjectOverview() {
        projectDetailMode = .overview
    }

    func filterByProject(_ projectID: UUID?) {
        filterProjectID = projectID
    }

    func toggleCommandPalette() {
        withAnimation(.spring(duration: 0.25)) {
            showCommandPalette.toggle()
        }
    }
}
