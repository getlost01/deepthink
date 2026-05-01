import Foundation
import SwiftUI

@Observable
final class AppState {
    var selectedSection: SidebarSection? = .workspace
    var showCommandPalette: Bool = false
    var searchQuery: String = ""

    // Workspace sub-navigation
    var workspaceTab: WorkspaceTab = .notes
    var selectedNoteID: UUID?
    var selectedTaskID: UUID?
    var selectedProjectID: UUID?

    // AI sub-navigation
    var aiMode: AIMode = .chat
    var pendingChatMessage: String?

    // AI side panel (Phase 4)
    var showAIPanel: Bool = false

    func navigate(to section: SidebarSection) {
        selectedSection = section
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

    func toggleCommandPalette() {
        withAnimation(.spring(duration: 0.25)) {
            showCommandPalette.toggle()
        }
    }
}
