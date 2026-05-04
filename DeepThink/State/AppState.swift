import Foundation
import SwiftUI

@Observable
final class AppState {
    var selectedSection: SidebarSection? = .recent
    var showCommandPalette: Bool = false
    var searchQuery: String = ""

    // Workspace sub-navigation
    var workspaceTab: WorkspaceTab = .projects
    var selectedNoteID: UUID?
    var selectedTaskID: UUID?
    var selectedProjectID: UUID?
    var selectedReminderID: UUID?
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
    var selectedKnowledgeEntryID: String?

    // Active context for skills/rules
    var currentNoteContent: String?
    var currentNoteTitle: String?
    var currentNoteTags: [String] = []
    var currentProjectName: String?
    var selectedText: String?
    var pendingSkillExecution: SkillFile?
    var disabledRuleIDs: Set<String> = []

    var activeContextDictionary: [String: String] {
        var ctx: [String: String] = [:]
        if let section = selectedSection { ctx["section"] = section.rawValue }
        if let project = currentProjectName { ctx["project"] = project }
        for tag in currentNoteTags { ctx["note.tagged.\(tag)"] = tag }
        if let content = currentNoteContent, looksLikeCode(content) {
            ctx["content_type"] = "code"
        }
        if let agentPath = selectedAgentPath {
            let agentName = AgentFileService.shared.agents.first { $0.filePath.path == agentPath }?.name
            if let name = agentName { ctx["agent"] = name }
        }
        return ctx
    }

    var activeRules: [RuleFile] {
        RuleFileService.shared.matchingRules(for: activeContextDictionary)
            .filter { !disabledRuleIDs.contains($0.id) }
    }

    private func looksLikeCode(_ text: String) -> Bool {
        let indicators = ["```", "func ", "def ", "class ", "import ", "const ", "let ", "var ", "return "]
        let matches = indicators.filter { text.contains($0) }.count
        return matches >= 2
    }

    func navigate(to section: SidebarSection) {
        selectedSection = section
    }

    func navigateToContext(source: String? = nil, channel: String? = nil) {
        selectedSection = .knowledge
        selectedContextSource = source
        selectedContextChannel = channel
    }

    func navigateToKnowledgeEntry(_ entryID: String) {
        selectedSection = .knowledge
        selectedKnowledgeEntryID = entryID
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

    func navigateToReminder(_ id: UUID) {
        selectedSection = .reminders
        selectedReminderID = id
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
