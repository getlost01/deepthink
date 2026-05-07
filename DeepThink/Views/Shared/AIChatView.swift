import SwiftData
import SwiftUI

struct AIChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<MCPServer> { $0.isEnabled }) private var activeServers: [MCPServer]
    @Query private var notes: [Note]
    @Query private var tasks: [TaskItem]
    @Query private var projects: [Project]
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    @State private var knowledgeService = KnowledgeService.shared

    var onShowConfig: ((AgentConfigTab) -> Void)?

    @State private var inputText = ""
    @State private var useMCP = true
    @State private var showSaveToKnowledge = false
    @State private var isSavingKnowledge = false
    @State private var currentConversation: Conversation?
    @State private var chatTask: Task<Void, Never>?
    @State private var lastFailedMessage: String?
    @State private var showHistory = false
    @State private var isScrolledUp = false
    @FocusState private var inputFocused: Bool

    @State private var showSlashMenu = false
    @State private var slashFilter = ""
    @State private var slashSelectedIndex = 0
    @State private var suggestedFollowUps: [String] = []
    @State private var followUpTask: Task<Void, Never>?

    private var skillService: SkillFileService {
        SkillFileService.shared
    }

    private var agentService: AgentFileService {
        AgentFileService.shared
    }

    private var selectedAgent: AgentFile? {
        guard let path = appState.selectedAgentPath else { return nil }
        return agentService.agents.first { $0.filePath.path == path }
    }

    private func smartWorkspaceContext(for query: String) -> String {
        let recentNotes: [any WorkspaceItem] = notes.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(15).map(\.self)
        let activeTasks: [any WorkspaceItem] = tasks.filter { $0.status == .inProgress || $0.status == .todo }.prefix(10).map(\.self)
        return ContextEngine.shared.buildWorkspaceContext(notes: recentNotes, tasks: activeTasks, query: query, maxTokens: 600)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                chatToolbar
                Divider()
                chatMessages
                chatInput
            }

            if showHistory {
                Divider()
                ChatHistorySidebar(
                    conversations: conversations.filter { !$0.isArchived },
                    currentID: currentConversation?.id,
                    onSelect: { loadConversation($0) },
                    onDelete: { deleteConversation($0) },
                    onNewChat: {
                        appState.chatMessages.removeAll()
                        appState.editBranchPoints.removeAll()
                        currentConversation = nil
                    },
                    onClose: {
                        withAnimation(DS.Animation.standard) { showHistory = false }
                    }
                )
                .frame(width: 240)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onAppear {
            inputFocused = true
            if let pending = appState.pendingChatMessage {
                inputText = pending
                appState.pendingChatMessage = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { sendMessage() }
            }
            if let skill = appState.pendingSkillExecution {
                appState.pendingSkillExecution = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    executeSkill(skill, input: "")
                }
            }
        }
        .alert("Saved to Knowledge", isPresented: $showSaveToKnowledge) {
            Button("OK") {}
        } message: {
            Text("Key insights from this conversation have been extracted and saved to your knowledge base.")
        }
    }

    // MARK: - Toolbar

    private var chatToolbar: some View {
        HStack(spacing: DS.Spacing.md) {
            Menu {
                Button {
                    appState.selectedAgentPath = nil
                    appState.chatMessages.removeAll()
                    appState.editBranchPoints.removeAll()
                } label: {
                    Label("Default Assistant", systemImage: "brain.head.profile")
                }
                Divider()
                ForEach(agentService.agents) { agent in
                    Button {
                        appState.selectedAgentPath = agent.filePath.path
                        appState.chatMessages.removeAll()
                        appState.editBranchPoints.removeAll()
                    } label: {
                        Label(agent.name, systemImage: agent.icon)
                    }
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: selectedAgent?.icon ?? "brain.head.profile")
                        .font(.system(size: DS.IconSize.sm, weight: .semibold))
                        .foregroundStyle(DS.Colors.accent)
                    Text(selectedAgent?.name ?? "Default Assistant")
                        .font(DS.Font.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs + 1)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .pointerOnHover()

            ActiveRulesBar(
                rules: RuleFileService.shared.matchingRules(for: appState.activeContextDictionary),
                disabledRuleIDs: Bindable(appState).disabledRuleIDs,
                onToggle: { ruleID in appState.toggleRuleDisabled(ruleID) }
            )

            Spacer()

            HStack(spacing: DS.Spacing.sm) {
                if !appState.chatMessages.isEmpty {
                    Button {
                        saveConversationToKnowledge()
                    } label: {
                        if isSavingKnowledge {
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.mini)
                                Text("Summarizing...")
                                    .font(DS.Font.buttonSmall)
                            }
                            .foregroundStyle(DS.Colors.textTertiary)
                        } else {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "brain")
                                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
                                Text("Summarize & Save")
                                    .font(DS.Font.buttonSmall)
                            }
                            .foregroundStyle(DS.Colors.accent)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.accent.opacity(0.2), lineWidth: 1))
                    .buttonStyle(.plainPointer)
                    .disabled(isSavingKnowledge)
                    .help("Summarize this conversation and save key insights to knowledge base")
                }

                if let onShowConfig {
                    Menu {
                        Button {
                            onShowConfig(.agents)
                        } label: {
                            Label("Assistants", systemImage: "person.2.circle")
                        }
                        Button {
                            onShowConfig(.skills)
                        } label: {
                            Label("Skills", systemImage: "sparkles")
                        }
                        Button {
                            onShowConfig(.rules)
                        } label: {
                            Label("Rules", systemImage: "bolt")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: DS.IconSize.sm, weight: .medium))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .frame(width: 28, height: 28)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                    .pointerOnHover()
                    .help("Assistants & Automations")
                }

                DSToolbarButton(icon: "square.and.pencil", color: DS.Colors.textSecondary, size: DS.IconSize.sm) {
                    appState.chatMessages.removeAll()
                    appState.editBranchPoints.removeAll()
                    currentConversation = nil
                }
                .help("New conversation")

                DSToolbarButton(
                    icon: "clock.arrow.circlepath",
                    color: showHistory ? DS.Colors.accent : DS.Colors.textSecondary,
                    size: DS.IconSize.sm
                ) {
                    withAnimation(DS.Animation.standard) { showHistory.toggle() }
                }
                .help(showHistory ? "Hide history" : "Show history")
            }
        }
        .frame(height: DS.Layout.toolbarHeight)
        .padding(.horizontal, DS.Spacing.lg)
        .background(DS.Colors.surfaceElevated)
    }

    // MARK: - Messages

    private var chatMessages: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if appState.chatMessages.isEmpty, !appState.isChatProcessing {
                            WelcomePrompts(
                                onSelect: { prompt in
                                    inputText = prompt
                                    sendMessage()
                                },
                                noteCount: notes.count,
                                taskCount: tasks.count,
                                pendingTaskCount: tasks.count(where: { $0.status == .todo || $0.status == .inProgress }),
                                projectCount: projects.count,
                                knowledgeCount: knowledgeService.entries.count
                            )
                            .padding(.top, 80)
                        }

                        LazyVStack(spacing: 0) {
                            ForEach(Array(appState.chatMessages.enumerated()), id: \.element.id) { index, message in
                                ChatBubble(
                                    message: message,
                                    onRetry: message.role == .error ? retryLastMessage : nil,
                                    onEdit: message.role == .user ? { newText in
                                        editAndResend(at: index, newText: newText)
                                    } : nil,
                                    onSaveResponse: message.role == .assistant ? { content in
                                        saveResponseToQuickCapture(content)
                                    } : nil,
                                    branchInfo: branchInfo(for: index),
                                    onSwitchBranch: appState.editBranchPoints[index] != nil ? { newIndex in
                                        switchBranch(at: index, to: newIndex)
                                    } : nil
                                )
                                .id(message.id)
                                .padding(.top, index == 0 ? DS.Spacing.xl : 0)
                            }

                            if !suggestedFollowUps.isEmpty, !appState.isChatProcessing {
                                FollowUpChipsView(suggestions: suggestedFollowUps) { prompt in
                                    suggestedFollowUps = []
                                    inputText = prompt
                                    sendMessage()
                                }
                                .padding(.horizontal, DS.Spacing.xl)
                                .padding(.vertical, DS.Spacing.sm)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            if appState.isChatProcessing {
                                ThinkingIndicator(
                                    startTime: appState.chatProcessingStartTime ?? Date(),
                                    useMCP: useMCP && !activeServers.isEmpty
                                )
                                .id("thinking")
                                .padding(.horizontal, DS.Spacing.xl)
                                .padding(.vertical, DS.Spacing.md)
                            }

                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .frame(maxWidth: 860)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, DS.Spacing.lg)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetKey.self,
                                value: geo.frame(in: .named("chatScroll")).maxY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "chatScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { maxY in
                    isScrolledUp = maxY > 800
                }
                .onChange(of: appState.chatMessages.count) {
                    scrollChatToEnd(proxy, preferAnimated: true)
                }
                .onChange(of: appState.isChatProcessing) {
                    scrollChatToEnd(proxy, preferAnimated: true)
                }
                .onChange(of: appState.chatMessages.last?.content) {
                    // Streaming updates fire every token; animating each scroll stacks animations
                    // and fights LazyVStack layout, which jumps the viewport toward older messages.
                    if appState.chatMessages.last?.isStreaming == true {
                        scrollChatToEnd(proxy, preferAnimated: false)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if isScrolledUp, !appState.chatMessages.isEmpty {
                        Button {
                            scrollChatToEnd(proxy, preferAnimated: true)
                        } label: {
                            Image(systemName: "arrow.down")
                                .font(.system(size: DS.IconSize.sm, weight: .semibold))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(DS.Colors.border, lineWidth: 1))
                                .shadow(color: DS.Colors.subtleShadow, radius: 4, y: 2)
                        }
                        .buttonStyle(.plainPointer)
                        .padding(DS.Spacing.lg)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
    }

    // MARK: - Input

    private var contextIndicator: some View {
        let hasContext = appState.currentNoteTitle != nil || appState.currentProjectName != nil
        return Group {
            if hasContext {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "paperclip")
                        .font(.system(size: DS.IconSize.xs, weight: .medium))
                        .foregroundStyle(DS.Colors.accent)

                    if let project = appState.currentProjectName {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "folder")
                                .font(.system(size: DS.IconSize.xs))
                            Text(project)
                                .font(DS.Font.small)
                        }
                        .foregroundStyle(DS.Colors.textSecondary)
                    }

                    if let noteTitle = appState.currentNoteTitle, !noteTitle.isEmpty {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "doc.text")
                                .font(.system(size: DS.IconSize.xs))
                            Text(noteTitle)
                                .font(DS.Font.small)
                                .lineLimit(1)
                        }
                        .foregroundStyle(DS.Colors.textSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
            }
        }
    }

    private var chatInput: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                contextIndicator

                TextField("Ask DeepThink anything...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...3)
                    .font(DS.Font.body)
                    .focused($inputFocused)
                    .frame(minHeight: 36, alignment: .topLeading)
                    .scrollIndicators(.hidden)
                    .onSubmit {
                        if showSlashMenu {
                            let filtered = filteredSlashSkills
                            if !filtered.isEmpty {
                                let idx = min(slashSelectedIndex, filtered.count - 1)
                                showSlashMenu = false
                                inputText = "/\(filtered[idx].commandName) "
                                return
                            }
                        }
                        sendMessage()
                    }
                    .onChange(of: inputText) { _, newValue in
                        updateSlashMenu(newValue)
                    }

                HStack(spacing: DS.Spacing.sm) {
                    Text("Type **/** for skills")
                        .font(DS.Font.micro)
                        .fontWeight(.regular)
                        .foregroundStyle(DS.Colors.textTertiary)

                    if !activeServers.isEmpty {
                        Toggle(isOn: $useMCP) {
                            HStack(spacing: DS.Spacing.xxs) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.system(size: DS.IconSize.xs))
                                Text("MCP")
                                    .font(DS.Font.micro)
                                Text("(\(activeServers.count))")
                                    .font(DS.Font.micro)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            .foregroundStyle(useMCP ? DS.Colors.accent : DS.Colors.textTertiary)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .pointerOnHover()
                    }

                    Spacer()

                    Text("⏎ Send")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Colors.textTertiary.opacity(0.6))

                    if appState.isChatProcessing {
                        Button {
                            chatTask?.cancel()
                            appState.isChatProcessing = false
                            appState.chatProcessingStartTime = nil
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: DS.IconSize.xl))
                                .foregroundStyle(DS.Colors.danger)
                        }
                        .buttonStyle(.plainPointer)
                        .help("Stop generating")
                    } else {
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: DS.IconSize.xl))
                                .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? DS.Colors.textTertiary
                                    .opacity(DS.Opacity.disabled) : DS.Colors.accent)
                        }
                        .buttonStyle(.plainPointer)
                        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(inputFocused ? DS.Colors.borderFocused : DS.Colors.border, lineWidth: 1)
            )
            .popover(isPresented: $showSlashMenu, attachmentAnchor: .point(.topLeading), arrowEdge: .bottom) {
                SlashCommandMenu(
                    skills: skillService.skills,
                    filter: slashFilter,
                    selectedIndex: $slashSelectedIndex
                ) { skill in
                    showSlashMenu = false
                    inputText = "/\(skill.commandName) "
                }
                .frame(width: 280)
            }
        }
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.surfaceElevated)
    }

    // MARK: - Actions

    private func saveResponseToQuickCapture(_ content: String) {
        QuickCaptureWindowController.shared.showPrefilled(
            with: modelContext.container,
            content: content
        )
    }

    /// Scrolls so the newest content stays in view. Uses the last bubble id (not a 1pt spacer)
    /// so LazyVStack + streaming layout stays stable; defers to the next run loop for correct heights.
    private func scrollChatToEnd(_ proxy: ScrollViewProxy, preferAnimated: Bool) {
        let streaming = appState.chatMessages.last?.isStreaming == true
        let animate = preferAnimated && !streaming

        DispatchQueue.main.async {
            if animate {
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollChatToEndImpl(proxy)
                }
            } else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    scrollChatToEndImpl(proxy)
                }
            }
        }
    }

    private func beginStreamSlot() async -> Int {
        await MainActor.run {
            appState.chatMessages.append(AIMessage(role: .assistant, content: "", isStreaming: true))
            appState.isChatProcessing = false
            appState.chatProcessingStartTime = nil
            return appState.chatMessages.count - 1
        }
    }

    private func endStreamSlot(_ idx: Int, response: String) async {
        await MainActor.run {
            guard idx < appState.chatMessages.count else { return }
            appState.chatMessages[idx].content = response
            appState.chatMessages[idx].isStreaming = false
            appState.chatMessages[idx].tokenUsage = ClaudeService.shared.lastTokenUsage
        }
    }

    private func scrollChatToEndImpl(_ proxy: ScrollViewProxy) {
        if appState.isChatProcessing {
            proxy.scrollTo("thinking", anchor: .bottom)
        } else if let last = appState.chatMessages.last {
            proxy.scrollTo(last.id, anchor: .bottom)
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // MARK: - Slash Commands

    private var filteredSlashSkills: [SkillFile] {
        if slashFilter.isEmpty { return skillService.skills }
        return skillService.skills.filter {
            $0.commandName.contains(slashFilter.lowercased()) || $0.name.lowercased().contains(slashFilter.lowercased())
        }
    }

    private func updateSlashMenu(_ text: String) {
        if text.hasPrefix("/"), !text.contains(" "), !text.isEmpty {
            slashFilter = String(text.dropFirst())
            withAnimation(DS.Animation.quick) { showSlashMenu = true }
        } else {
            if showSlashMenu { withAnimation(DS.Animation.quick) { showSlashMenu = false } }
        }
    }

    private func parseSlashCommand(_ text: String) -> (skill: SkillFile, input: String)? {
        guard text.hasPrefix("/") else { return nil }
        let parts = text.dropFirst().split(separator: " ", maxSplits: 1)
        guard let commandPart = parts.first else { return nil }
        let command = String(commandPart)
        guard let skill = skillService.skill(forCommand: command) else { return nil }
        let input = parts.count > 1 ? String(parts[1]) : ""
        return (skill, input)
    }

    private func executeSkill(_ skill: SkillFile, input: String) {
        let resolvedInput: String = if !input.isEmpty {
            input
        } else if let selected = appState.selectedText, !selected.isEmpty {
            selected
        } else if let noteContent = appState.currentNoteContent, !noteContent.isEmpty {
            noteContent
        } else {
            ""
        }

        appState.chatMessages.append(AIMessage(role: .user, content: "/\(skill.commandName) \(resolvedInput.prefix(100))..."))
        persistMessage(role: "user", content: "/\(skill.commandName)")
        appState.isChatProcessing = true
        appState.chatProcessingStartTime = Date()

        chatTask = Task {
            var context: [String: String] = ["input": resolvedInput]
            if let note = appState.currentNoteContent { context["note_content"] = note }
            if let sel = appState.selectedText { context["selected_text"] = sel }
            if let proj = appState.currentProjectName { context["project_name"] = proj }
            if let noteTitle = appState.currentNoteTitle { context["note_title"] = noteTitle }
            context["current_date"] = Date().formatted(date: .complete, time: .omitted)
            context["current_time"] = Date().formatted(date: .omitted, time: .shortened)
            if !appState.currentNoteTags.isEmpty { context["note_tags"] = appState.currentNoteTags.joined(separator: ", ") }

            let result = await skillService.execute(skill: skill, context: context)
            await MainActor.run {
                appState.chatMessages.append(AIMessage(role: .assistant, content: result))
                persistMessage(role: "assistant", content: result)
                appState.isChatProcessing = false
                appState.chatProcessingStartTime = nil
            }
        }
    }

    // MARK: - Conversation History

    private func buildConversationHistory(currentMessage: String) -> String {
        let messages = appState.chatMessages.filter { $0.role != .error }
        let prior = Array(messages.dropLast())
        guard !prior.isEmpty else { return "" }

        let total = prior.count

        if total > 8, let convID = currentConversation?.id,
           let summary = ContextEngine.shared.getCachedSummary(for: convID)
        {
            let recent = Array(prior.suffix(4))
            return "# Conversation summary\n\(summary)\n\n# Recent\n\(compactMessages(recent))"
        }

        if total > 4 {
            let older = Array(prior.prefix(total - 4))
            let recent = Array(prior.suffix(4))
            return "# Earlier\n\(compactMessages(older))\n\n# Recent\n\(formatMessages(recent))"
        }

        return "# Conversation\n\(formatMessages(prior))"
    }

    private func formatMessages(_ messages: [AIMessage]) -> String {
        messages.map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            if msg.role == .assistant {
                return "\(role): \(compactText(msg.content, maxLen: 400))"
            }
            return "\(role): \(msg.content)"
        }.joined(separator: "\n\n")
    }

    private func compactMessages(_ messages: [AIMessage]) -> String {
        messages.map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            let limit = msg.role == .user ? 200 : 120
            return "\(role): \(compactText(msg.content, maxLen: limit))"
        }.joined(separator: "\n")
    }

    private func compactText(_ text: String, maxLen: Int) -> String {
        if text.count <= maxLen { return text }
        let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var result = ""
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") { continue }
            if result.count + trimmed.count + 1 > maxLen {
                result += "..."
                break
            }
            if !result.isEmpty { result += " " }
            result += trimmed
        }
        return result
    }

    private func activeRulesSystemPrompt() -> String? {
        let rules = appState.activeRules
        guard !rules.isEmpty else { return nil }
        return rules.map { "## Rule: \($0.name)\n\($0.instruction)" }.joined(separator: "\n\n")
    }

    // MARK: - Send

    private static let workspaceKeywords = [
        "create", "add", "make", "new", "delete", "remove", "update", "edit", "change",
        "task", "note", "project", "assign", "move", "set status", "mark done", "archive",
        "list tasks", "list notes", "list projects", "show tasks", "workspace", "summary",
        "knowledge", "tally", "count", "how many", "list all"
    ]

    private func isWorkspaceRequest(_ text: String) -> Bool {
        let lower = text.lowercased()
        return Self.workspaceKeywords.contains { lower.contains($0) }
    }

    private func ensureWorkspaceServer(in servers: [MCPServer]) -> [MCPServer] {
        if servers.contains(where: { $0.name == "DeepThink Workspace" }) { return servers }
        let wsServer = MCPServer(
            name: "DeepThink Workspace",
            command: DeepThinkPaths.mcpBinaryPath,
            args: "",
            category: "Workspace",
            description: "Manage tasks, notes, and projects"
        )
        wsServer.isEnabled = true
        return [wsServer] + servers
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if let (skill, input) = parseSlashCommand(text) {
            inputText = ""
            showSlashMenu = false
            executeSkill(skill, input: input)
            return
        }

        suggestedFollowUps = []
        followUpTask?.cancel()
        appState.chatMessages.append(AIMessage(role: .user, content: text))
        persistMessage(role: "user", content: text)
        inputText = ""
        lastFailedMessage = text
        appState.isChatProcessing = true
        appState.chatProcessingStartTime = Date()

        let isWorkspace = isWorkspaceRequest(text)
        var servers = useMCP ? Array(activeServers) : []
        if isWorkspace { servers = ensureWorkspaceServer(in: servers) }

        let ctx = smartWorkspaceContext(for: text)
        let projectScope = notes.first { $0.id == appState.selectedNoteID }?.project?.name
        let agentScope = selectedAgent?.knowledgeScope
        let ragContext = KnowledgeService.shared.ragContext(for: text, projectScope: projectScope, agentScope: agentScope)
        let conversationHistory = buildConversationHistory(currentMessage: text)

        chatTask = Task {
            if appState.chatMessages.count >= 8, let convID = currentConversation?.id {
                let existing = ContextEngine.shared.getCachedSummary(for: convID)
                let shouldUpdate = existing == nil || appState.chatMessages.count % 6 == 0
                if shouldUpdate {
                    let toSummarize = Array(appState.chatMessages.prefix(appState.chatMessages.count - 4))
                    var prompt = toSummarize.map(\.self)
                    if let prev = existing {
                        prompt.insert(AIMessage(role: .assistant, content: "[Previous summary: \(prev)]"), at: 0)
                    }
                    if let summary = await ContextEngine.shared.summarizeConversation(messages: prompt, maxTokens: 300) {
                        ContextEngine.shared.cacheSummary(summary, for: convID)
                    }
                }
            }

            do {
                let response: String

                var contextParts: [String] = []
                if let rag = ragContext { contextParts.append(rag) }
                if !ctx.isEmpty { contextParts.append("# Workspace Context\n\n\(ctx)") }
                if !conversationHistory.isEmpty { contextParts.append(conversationHistory) }

                let fullPrompt: String = if contextParts.isEmpty {
                    text
                } else {
                    contextParts.joined(separator: "\n\n") + "\n\nUser: \(text)"
                }

                var systemPrompt: String = if let agent = selectedAgent {
                    AgentFileService.shared.buildSystemPrompt(for: agent, query: text)
                } else if isWorkspace {
                    "You are DeepThink AI, a workspace assistant with tools to create, update, delete, and list tasks, notes, and projects. When the user asks to create or modify workspace items, USE the workspace tools to do it — don't just describe what you would do. After using a tool, confirm what was done. Be concise. Use markdown formatting."
                } else {
                    "You are DeepThink AI, a powerful knowledge assistant. You have access to the user's knowledge base which is automatically searched for relevant context. You help with analysis, research, writing, coding, and organization. Be concise and helpful. Use markdown formatting. When your answer draws on knowledge base entries, mention which sources informed it."
                }

                if selectedAgent == nil, let rulesPrompt = activeRulesSystemPrompt() {
                    systemPrompt += "\n\n# Active Rules\n\n" + rulesPrompt
                }

                try Task.checkCancellation()

                let streamIdx = await beginStreamSlot()
                if servers.isEmpty {
                    response = try await ClaudeService.shared.streamQuery(fullPrompt, systemPrompt: systemPrompt) { token in
                        DispatchQueue.main.async {
                            if streamIdx < appState.chatMessages.count {
                                appState.chatMessages[streamIdx].content += token
                            }
                        }
                    }
                } else {
                    response = try await MCPService.shared.streamQueryWithMCP(
                        prompt: fullPrompt, servers: servers, systemPrompt: systemPrompt
                    ) { token in
                        DispatchQueue.main.async {
                            if streamIdx < appState.chatMessages.count {
                                appState.chatMessages[streamIdx].content += token
                            }
                        }
                    }
                }
                await endStreamSlot(streamIdx, response: response)

                try Task.checkCancellation()

                await MainActor.run {
                    let lastUsage = appState.chatMessages.last?.tokenUsage
                    persistMessage(role: "assistant", content: response, tokenUsage: lastUsage)
                    lastFailedMessage = nil
                    updateActiveBranchSnapshot()
                    generateFollowUps(userMessage: text, assistantMessage: response)
                }

                if appState.chatMessages.count == 2, let conv = currentConversation {
                    Task.detached(priority: .background) {
                        await autoTitleConversation(conv, userMessage: text, assistantMessage: response)
                    }
                }

                if !appState.chatMessages.isEmpty, appState.chatMessages.count % 6 == 0 {
                    let msgs = appState.chatMessages
                    Task.detached(priority: .background) {
                        _ = await KnowledgeExtractionService.shared.extractFromConversation(messages: msgs)
                        await MainActor.run {
                            ContextEngine.shared.rebuildIndex()
                        }
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    appState.isChatProcessing = false
                    appState.chatProcessingStartTime = nil
                }
            } catch {
                await MainActor.run {
                    appState.chatMessages.append(AIMessage(role: .error, content: error.localizedDescription))
                    persistMessage(role: "error", content: error.localizedDescription)
                    appState.isChatProcessing = false
                    appState.chatProcessingStartTime = nil
                }
            }
        }
    }

    private func editAndResend(at index: Int, newText: String) {
        guard index >= 0, index < appState.chatMessages.count else { return }

        chatTask?.cancel()
        appState.isChatProcessing = false
        appState.chatProcessingStartTime = nil

        let oldBranch = EditBranch(messages: Array(appState.chatMessages[index...]))

        if var branchPoint = appState.editBranchPoints[index] {
            branchPoint.branches[branchPoint.activeBranchIndex] = oldBranch
            let newIndex = branchPoint.branches.count
            branchPoint.branches.append(EditBranch(messages: []))
            branchPoint.activeBranchIndex = newIndex
            appState.editBranchPoints[index] = branchPoint
        } else {
            appState.editBranchPoints[index] = BranchPoint(
                branches: [oldBranch, EditBranch(messages: [])],
                activeBranchIndex: 1
            )
        }

        deletePersistedMessages(fromIndex: index)
        appState.chatMessages.removeSubrange(index...)
        persistBranches()
        inputText = newText
        sendMessage()
    }

    private func branchInfo(for index: Int) -> (current: Int, total: Int)? {
        guard let bp = appState.editBranchPoints[index] else { return nil }
        return (bp.activeBranchIndex, bp.branches.count)
    }

    private func switchBranch(at index: Int, to branchIndex: Int) {
        guard index >= 0, index < appState.chatMessages.count else { return }
        guard var bp = appState.editBranchPoints[index] else { return }
        guard branchIndex >= 0, branchIndex < bp.branches.count else { return }

        let currentSuffix = Array(appState.chatMessages[index...])
        bp.branches[bp.activeBranchIndex] = EditBranch(messages: currentSuffix)

        let target = bp.branches[branchIndex]
        bp.activeBranchIndex = branchIndex
        appState.editBranchPoints[index] = bp

        deletePersistedMessages(fromIndex: index)
        appState.chatMessages.removeSubrange(index...)
        appState.chatMessages.append(contentsOf: target.messages)

        for msg in target.messages {
            let role = msg.role == .user ? "user" : (msg.role == .error ? "error" : "assistant")
            let chatMsg = ChatMessage(role: role, content: msg.content)
            chatMsg.timestamp = msg.timestamp
            chatMsg.conversation = currentConversation
            modelContext.insert(chatMsg)
        }
        try? modelContext.save()

        for key in appState.editBranchPoints.keys where key > index {
            appState.editBranchPoints.removeValue(forKey: key)
        }
        persistBranches()
    }

    private func deletePersistedMessages(fromIndex index: Int) {
        guard let conv = currentConversation else { return }
        let sorted = conv.sortedMessages
        guard index < sorted.count else { return }
        for i in index..<sorted.count {
            modelContext.delete(sorted[i])
        }
        try? modelContext.save()
    }

    private func updateActiveBranchSnapshot() {
        for (index, var bp) in appState.editBranchPoints {
            guard index < appState.chatMessages.count else { continue }
            let currentMessages = Array(appState.chatMessages[index...])
            bp.branches[bp.activeBranchIndex] = EditBranch(messages: currentMessages)
            appState.editBranchPoints[index] = bp
        }
        persistBranches()
    }

    private func persistBranches() {
        guard let conv = currentConversation else { return }
        conv.branchDataJSON = BranchSerializer.serialize(appState.editBranchPoints)
        try? modelContext.save()
    }

    private func retryLastMessage() {
        guard let msg = lastFailedMessage else { return }
        chatTask?.cancel()
        appState.isChatProcessing = false
        appState.chatProcessingStartTime = nil
        if let last = appState.chatMessages.last, last.role == .error {
            appState.chatMessages.removeLast()
        }
        inputText = msg
        sendMessage()
    }

    // MARK: - Persistence

    private func persistMessage(role: String, content: String, tokenUsage: TokenUsage? = nil) {
        if currentConversation == nil {
            let title = String(content.prefix(60))
            let conv = Conversation(title: title, agentName: selectedAgent?.name)
            modelContext.insert(conv)
            currentConversation = conv
        }
        let msg = ChatMessage(role: role, content: content)
        if let usage = tokenUsage {
            msg.inputTokens = usage.inputTokens
            msg.outputTokens = usage.outputTokens
            msg.cacheReadTokens = usage.cacheReadTokens
            msg.cacheCreationTokens = usage.cacheCreationTokens
            msg.costUSD = usage.costUSD
            msg.durationMs = usage.durationMs
        }
        msg.conversation = currentConversation
        modelContext.insert(msg)
        currentConversation?.updatedAt = Date()
        try? modelContext.save()
    }

    private func loadConversation(_ conversation: Conversation) {
        showHistory = false
        currentConversation = conversation
        appState.chatMessages = conversation.sortedMessages.map { msg in
            AIMessage(
                role: msg.isUser ? .user : (msg.isError ? .error : .assistant),
                content: msg.content,
                timestamp: msg.timestamp,
                tokenUsage: msg.tokenUsage
            )
        }
        if let branchData = conversation.branchDataJSON {
            appState.editBranchPoints = BranchSerializer.deserialize(branchData)
        } else {
            appState.editBranchPoints.removeAll()
        }
        if let agentName = conversation.agentName {
            appState.selectedAgentPath = agentService.agents.first { $0.name == agentName }?.filePath.path
        }
    }

    private func deleteConversation(_ conversation: Conversation) {
        if currentConversation?.id == conversation.id {
            appState.chatMessages.removeAll()
            appState.editBranchPoints.removeAll()
            currentConversation = nil
        }
        modelContext.delete(conversation)
        try? modelContext.save()
    }

    private func autoTitleConversation(_ conv: Conversation, userMessage: String, assistantMessage: String) async {
        let prompt = "Generate a 3-5 word title for this conversation. Output ONLY the title, nothing else.\n\nUser: \(userMessage.prefix(200))\nAssistant: \(assistantMessage.prefix(300))"
        if let title = try? await ClaudeService.shared.query(prompt, systemPrompt: "Output only a short title. No quotes, no punctuation, no explanation.") {
            let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
            if !cleaned.isEmpty, cleaned.count < 60 {
                await MainActor.run {
                    conv.title = cleaned
                    try? modelContext.save()
                }
            }
        }
    }

    private func saveConversationToKnowledge() {
        isSavingKnowledge = true
        let messages = appState.chatMessages
        Task {
            let success = await KnowledgeExtractionService.shared.extractFromConversation(messages: messages)
            await MainActor.run {
                isSavingKnowledge = false
                if success { showSaveToKnowledge = true }
            }
        }
    }

    // MARK: - Follow-Up Suggestions

    private func generateFollowUps(userMessage: String, assistantMessage: String) {
        followUpTask?.cancel()
        suggestedFollowUps = []

        followUpTask = Task {
            let prompt = "Based on this conversation exchange, suggest exactly 3 short follow-up questions the user might ask next. Each must be under 60 characters. Output ONLY the 3 questions, one per line, no numbering, no bullets, no quotes.\n\nUser: \(userMessage.prefix(300))\nAssistant: \(assistantMessage.prefix(500))"

            guard let result = try? await ClaudeService.shared.query(
                prompt,
                systemPrompt: "Output exactly 3 short follow-up questions, one per line. Nothing else."
            ) else { return }

            let suggestions = result
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.count < 80 }
                .prefix(3)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(DS.Animation.standard) {
                    suggestedFollowUps = Array(suggestions)
                }
            }
        }
    }
}

// MARK: - Follow-Up Chips

struct FollowUpChipsView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: DS.IconSize.sm, weight: .medium))
                .foregroundStyle(DS.Colors.accent.opacity(0.6))
                .padding(.top, DS.Spacing.xs)

            FlowLayout(spacing: DS.Spacing.xs) {
                ForEach(suggestions, id: \.self) { suggestion in
                    FollowUpChip(text: suggestion) { onSelect(suggestion) }
                }
            }

            Spacer(minLength: 40)
        }
    }
}

private struct FollowUpChip: View {
    let text: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(DS.Font.caption)
                .foregroundStyle(isHovered ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs + 1)
                .background(isHovered ? DS.Colors.fillSecondary : DS.Colors.fill, in: Capsule())
                .overlay(Capsule().strokeBorder(isHovered ? DS.Colors.borderHover : DS.Colors.border, lineWidth: 0.5))
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}
