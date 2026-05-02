import Foundation
import SwiftUI

@Observable
final class AppState {
    var selectedSection: SidebarSection? = .workspace
    var showCommandPalette: Bool = false
    var searchQuery: String = ""

    // AI Side Panel
    var showAIPanel: Bool = false
    var aiPanelContext: String = ""

    // Workspace sub-navigation
    var workspaceTab: WorkspaceTab = .projects
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
    var aiMode: AIMode = .chat
    var pendingChatMessage: String?

    func navigate(to section: SidebarSection) {
        selectedSection = section
    }

    func navigateToNote(_ id: UUID) {
        selectedSection = .workspace
        workspaceTab = .projects
        selectedNoteID = id
    }

    func navigateToTask(_ id: UUID) {
        selectedSection = .workspace
        workspaceTab = .projects
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

    func toggleAIPanel() {
        withAnimation(.spring(duration: 0.25)) {
            showAIPanel.toggle()
        }
    }

    func openAIPanelWith(context: String) {
        aiPanelContext = context
        withAnimation(.spring(duration: 0.25)) {
            showAIPanel = true
        }
    }

    func toggleCommandPalette() {
        withAnimation(.spring(duration: 0.25)) {
            showCommandPalette.toggle()
        }
    }
}
