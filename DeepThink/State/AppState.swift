import Foundation
import SwiftUI

struct NavSnapshot: Equatable {
    var selectedSection: SidebarSection?
    var workspaceTab: WorkspaceTab
    var selectedProjectID: UUID?
    var projectDetailMode: AppState.ProjectDetailMode
    var selectedNoteID: UUID?
    var selectedTaskID: UUID?
    var selectedReminderID: UUID?
}

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

    /// Project detail sub-navigation
    enum ProjectDetailMode: Equatable {
        case overview
        case taskDetail(UUID)
        case noteDetail(UUID)
    }

    var projectDetailMode: ProjectDetailMode = .overview

    // Navigation history
    private(set) var navHistory: [NavSnapshot] = []
    private(set) var navForward: [NavSnapshot] = []
    var canGoBack: Bool {
        !navHistory.isEmpty
    }

    var canGoForward: Bool {
        !navForward.isEmpty
    }

    // AI sub-navigation
    var pendingChatMessage: String?
    var selectedAgentPath: String?

    // Chat state (persists across tab switches)
    var chatMessages: [AIMessage] = []
    var isChatProcessing = false
    var chatProcessingStartTime: Date?

    // Terminal state (persists across tab switches)
    var terminalTabs: [TerminalTab] = []
    var activeTerminalTabID: UUID?

    /// Edit branching (keyed by message index where edit happened)
    var editBranchPoints: [Int: BranchPoint] = [:]

    /// Agent Config sub-navigation
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
    var disabledRuleIDs: Set<String>

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: "disabledRuleIDs") ?? []
        disabledRuleIDs = Set(saved)
    }

    func toggleRuleDisabled(_ id: String) {
        if disabledRuleIDs.contains(id) {
            disabledRuleIDs.remove(id)
        } else {
            disabledRuleIDs.insert(id)
        }
        UserDefaults.standard.set(Array(disabledRuleIDs), forKey: "disabledRuleIDs")
    }

    var activeContextDictionary: [String: String] {
        var ctx: [String: String] = [:]
        if let section = selectedSection { ctx["section"] = section.rawValue }
        if let project = currentProjectName { ctx["project"] = project }
        for tag in currentNoteTags {
            ctx["note.tagged.\(tag)"] = tag
        }
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
        let matches = indicators.count(where: { text.contains($0) })
        return matches >= 2
    }

    // MARK: - History

    private func currentSnapshot() -> NavSnapshot {
        NavSnapshot(
            selectedSection: selectedSection,
            workspaceTab: workspaceTab,
            selectedProjectID: selectedProjectID,
            projectDetailMode: projectDetailMode,
            selectedNoteID: selectedNoteID,
            selectedTaskID: selectedTaskID,
            selectedReminderID: selectedReminderID
        )
    }

    private func pushHistory() {
        let snap = currentSnapshot()
        if snap == navHistory.last { return }
        navHistory.append(snap)
        navForward.removeAll()
        if navHistory.count > 30 { navHistory.removeFirst() }
    }

    private func restoreSnapshot(_ snap: NavSnapshot) {
        selectedSection = snap.selectedSection
        workspaceTab = snap.workspaceTab
        selectedProjectID = snap.selectedProjectID
        projectDetailMode = snap.projectDetailMode
        selectedNoteID = snap.selectedNoteID
        selectedTaskID = snap.selectedTaskID
        selectedReminderID = snap.selectedReminderID
    }

    func navigateBack() {
        guard let snap = navHistory.popLast() else { return }
        navForward.append(currentSnapshot())
        if navForward.count > 30 { navForward.removeFirst() }
        restoreSnapshot(snap)
    }

    func navigateForward() {
        guard let snap = navForward.popLast() else { return }
        navHistory.append(currentSnapshot())
        if navHistory.count > 30 { navHistory.removeFirst() }
        restoreSnapshot(snap)
    }

    // MARK: - Deep Links

    func handleDeepLink(_ url: URL) {
        guard url.scheme == "deepthink" else {
            NSWorkspace.shared.open(url)
            return
        }
        let host = url.host ?? ""
        if host == "knowledge" {
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let entryID = comps.queryItems?.first(where: { $0.name == "id" })?.value
            {
                navigateToKnowledgeEntry(entryID)
            }
            return
        }
        let pathParts = url.pathComponents.filter { $0 != "/" }
        guard let uuidStr = pathParts.first, let id = UUID(uuidString: uuidStr) else { return }
        switch host {
        case "task": navigateToTask(id)
        case "note": navigateToNote(id)
        case "reminder": navigateToReminder(id)
        case "project": navigateToProject(id)
        default: break
        }
    }

    // MARK: - Navigation

    func navigate(to section: SidebarSection) {
        pushHistory()
        selectedSection = section
    }

    func navigateToContext(source: String? = nil, channel: String? = nil) {
        pushHistory()
        selectedSection = .knowledge
        selectedContextSource = source
        selectedContextChannel = channel
    }

    func navigateToKnowledgeEntry(_ entryID: String) {
        pushHistory()
        selectedSection = .knowledge
        selectedKnowledgeEntryID = entryID
    }

    func navigateToNote(_ id: UUID) {
        pushHistory()
        selectedSection = .workspace
        workspaceTab = .notes
        selectedNoteID = id
    }

    func navigateToTask(_ id: UUID) {
        pushHistory()
        selectedSection = .workspace
        workspaceTab = .tasks
        selectedTaskID = id
    }

    func navigateToReminder(_ id: UUID) {
        pushHistory()
        selectedSection = .reminders
        selectedReminderID = id
    }

    func navigateToProject(_ id: UUID) {
        pushHistory()
        selectedSection = .workspace
        workspaceTab = .projects
        selectedProjectID = id
    }

    func navigateToNoteInProject(_ noteID: UUID) {
        pushHistory()
        projectDetailMode = .noteDetail(noteID)
    }

    func navigateToTaskInProject(_ taskID: UUID) {
        pushHistory()
        projectDetailMode = .taskDetail(taskID)
    }

    func backToProjectOverview() {
        navHistory.removeAll { $0 == currentSnapshot() }
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
