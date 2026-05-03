import SwiftUI
import SwiftData

struct AIChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<MCPServer> { $0.isEnabled }) private var activeServers: [MCPServer]
    @Query private var notes: [Note]
    @Query private var tasks: [TaskItem]
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

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

    private var skillService: SkillFileService { SkillFileService.shared }
    private var agentService: AgentFileService { AgentFileService.shared }

    private var selectedAgent: AgentFile? {
        guard let path = appState.selectedAgentPath else { return nil }
        return agentService.agents.first { $0.filePath.path == path }
    }

    private func smartWorkspaceContext(for query: String) -> String {
        let recentNotes: [any WorkspaceItem] = notes.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(15).map { $0 }
        let activeTasks: [any WorkspaceItem] = tasks.filter { $0.status == .inProgress || $0.status == .todo }.prefix(10).map { $0 }
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
                        currentConversation = nil
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
                } label: {
                    Label("Default Assistant", systemImage: "brain.head.profile")
                }
                Divider()
                ForEach(agentService.agents) { agent in
                    Button {
                        appState.selectedAgentPath = agent.filePath.path
                        appState.chatMessages.removeAll()
                    } label: {
                        Label(agent.name, systemImage: agent.icon)
                    }
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: selectedAgent?.icon ?? "brain.head.profile")
                        .font(.system(size: 11, weight: .semibold))
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

            ActiveRulesBar(
                rules: RuleFileService.shared.matchingRules(for: appState.activeContextDictionary),
                disabledRuleIDs: Bindable(appState).disabledRuleIDs
            )

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                if !appState.chatMessages.isEmpty {
                    Button {
                        saveConversationToKnowledge()
                    } label: {
                        if isSavingKnowledge {
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.mini)
                                Text("Saving...")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(DS.Colors.textTertiary)
                        } else {
                            Text("Save to Knowledge")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DS.Colors.accent)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .buttonStyle(.plainPointer)
                    .disabled(isSavingKnowledge)
                }

                if let onShowConfig {
                    Menu {
                        Button {
                            onShowConfig(.agents)
                        } label: {
                            Label("Assistants", systemImage: "person.2.circle")
                        }
                        Button {
                            onShowConfig(.skillsAndRules)
                        } label: {
                            Label("Automations", systemImage: "gearshape.2")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: DS.IconSize.sm, weight: .medium))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .frame(width: 28, height: 28)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                    .help("Assistants & Automations")
                }

                DSToolbarButton(icon: "square.and.pencil", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                    appState.chatMessages.removeAll()
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
        .background(.bar)
    }

    // MARK: - Messages

    private var chatMessages: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if appState.chatMessages.isEmpty && !appState.isChatProcessing {
                            WelcomePrompts { prompt in
                                inputText = prompt
                                sendMessage()
                            }
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
                                    onSaveAsNote: message.role == .assistant ? { content in
                                        saveAsNote(content)
                                    } : nil,
                                    onCreateTask: message.role == .assistant ? { content in
                                        createTaskFromChat(content)
                                    } : nil
                                )
                                .id(message.id)
                                .padding(.top, index == 0 ? DS.Spacing.xl : 0)
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
                    scrollToEnd(proxy)
                }
                .onChange(of: appState.isChatProcessing) {
                    scrollToEnd(proxy)
                }
                .overlay(alignment: .bottomTrailing) {
                    if isScrolledUp && !appState.chatMessages.isEmpty {
                        Button {
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        } label: {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(DS.Colors.border, lineWidth: 1))
                                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
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

    private var chatInput: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                TextField("Message DeepThink...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...3)
                    .font(.system(size: 13))
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
                        .font(.system(size: 9))
                        .foregroundStyle(DS.Colors.textTertiary)

                    if !activeServers.isEmpty {
                        Toggle(isOn: $useMCP) {
                            HStack(spacing: 2) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.system(size: 8))
                                Text("MCP")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(useMCP ? DS.Colors.accent : DS.Colors.textTertiary)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    }

                    Spacer()
                    if appState.isChatProcessing {
                        Button {
                            chatTask?.cancel()
                            appState.isChatProcessing = false
                            appState.chatProcessingStartTime = nil
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(DS.Colors.danger)
                        }
                        .buttonStyle(.plainPointer)
                        .help("Stop generating")
                    } else {
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? DS.Colors.textTertiary.opacity(0.4) : DS.Colors.accent)
                        }
                        .buttonStyle(.plainPointer)
                        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
        .background(.bar)
    }

    // MARK: - Actions

    private func saveAsNote(_ content: String) {
        let title = String(content.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
        let note = Note(title: title, content: content)
        modelContext.insert(note)
        try? modelContext.save()
    }

    private func createTaskFromChat(_ content: String) {
        let title = String(content.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
        let task = TaskItem(title: title)
        task.detail = content
        modelContext.insert(task)
        try? modelContext.save()
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
    }

    // MARK: - Slash Commands

    private var filteredSlashSkills: [SkillFile] {
        if slashFilter.isEmpty { return skillService.skills }
        return skillService.skills.filter {
            $0.commandName.contains(slashFilter.lowercased()) || $0.name.lowercased().contains(slashFilter.lowercased())
        }
    }

    private func updateSlashMenu(_ text: String) {
        if text.hasPrefix("/") && !text.contains(" ") && text.count > 0 {
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
        let resolvedInput: String
        if !input.isEmpty {
            resolvedInput = input
        } else if let selected = appState.selectedText, !selected.isEmpty {
            resolvedInput = selected
        } else if let noteContent = appState.currentNoteContent, !noteContent.isEmpty {
            resolvedInput = noteContent
        } else {
            resolvedInput = ""
        }

        appState.chatMessages.append(AIMessage(role: .user, content: "/\(skill.commandName) \(resolvedInput.prefix(100))..."))
        persistMessage(role: "user", content: "/\(skill.commandName)")
        appState.isChatProcessing = true
        appState.chatProcessingStartTime = Date()

        chatTask = Task {
            let result = await skillService.execute(skill: skill, context: ["input": resolvedInput])
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
           let summary = ContextEngine.shared.getCachedSummary(for: convID) {
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
                    var prompt = toSummarize.map { $0 }
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

                let fullPrompt: String
                if contextParts.isEmpty {
                    fullPrompt = text
                } else {
                    fullPrompt = contextParts.joined(separator: "\n\n") + "\n\nUser: \(text)"
                }

                var systemPrompt: String
                if let agent = selectedAgent {
                    systemPrompt = AgentFileService.shared.buildSystemPrompt(for: agent, query: text)
                } else if isWorkspace {
                    systemPrompt = "You are DeepThink AI, a workspace assistant with tools to create, update, delete, and list tasks, notes, and projects. When the user asks to create or modify workspace items, USE the workspace tools to do it — don't just describe what you would do. After using a tool, confirm what was done. Be concise. Use markdown formatting."
                } else {
                    systemPrompt = "You are DeepThink AI, a powerful knowledge assistant. You have access to the user's knowledge base which is automatically searched for relevant context. You help with analysis, research, writing, coding, and organization. Be concise and helpful. Use markdown formatting. When your answer draws on knowledge base entries, mention which sources informed it."
                }

                if selectedAgent == nil, let rulesPrompt = activeRulesSystemPrompt() {
                    systemPrompt += "\n\n# Active Rules\n\n" + rulesPrompt
                }

                try Task.checkCancellation()

                if servers.isEmpty {
                    await MainActor.run {
                        appState.chatMessages.append(AIMessage(role: .assistant, content: "", isStreaming: true))
                        appState.isChatProcessing = false
                        appState.chatProcessingStartTime = nil
                    }
                    let streamIdx = appState.chatMessages.count - 1
                    response = try await ClaudeService.shared.streamQuery(fullPrompt, systemPrompt: systemPrompt) { token in
                        DispatchQueue.main.async {
                            if streamIdx < appState.chatMessages.count {
                                appState.chatMessages[streamIdx].content += token
                            }
                        }
                    }
                    await MainActor.run {
                        if streamIdx < appState.chatMessages.count {
                            appState.chatMessages[streamIdx].content = response
                            appState.chatMessages[streamIdx].isStreaming = false
                        }
                    }
                } else {
                    response = try await MCPService.shared.queryWithMCP(
                        prompt: fullPrompt, servers: servers, systemPrompt: systemPrompt
                    )
                    await MainActor.run {
                        appState.chatMessages.append(AIMessage(role: .assistant, content: response))
                        appState.isChatProcessing = false
                        appState.chatProcessingStartTime = nil
                    }
                }

                try Task.checkCancellation()

                await MainActor.run {
                    persistMessage(role: "assistant", content: response)
                    lastFailedMessage = nil
                }

                if appState.chatMessages.count == 2, let conv = currentConversation {
                    Task.detached(priority: .background) {
                        await autoTitleConversation(conv, userMessage: text, assistantMessage: response)
                    }
                }

                if appState.chatMessages.count > 0 && appState.chatMessages.count % 6 == 0 {
                    let msgs = appState.chatMessages
                    Task.detached(priority: .background) {
                        _ = await KnowledgeExtractionService.shared.extractFromConversation(messages: msgs)
                        ContextEngine.shared.rebuildIndex()
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
        appState.chatMessages.removeSubrange(index...)
        inputText = newText
        sendMessage()
    }

    private func retryLastMessage() {
        guard let msg = lastFailedMessage else { return }
        if let last = appState.chatMessages.last, last.role == .error {
            appState.chatMessages.removeLast()
        }
        inputText = msg
        sendMessage()
    }

    // MARK: - Persistence

    private func persistMessage(role: String, content: String) {
        if currentConversation == nil {
            let title = String(content.prefix(60))
            let conv = Conversation(title: title, agentName: selectedAgent?.name)
            modelContext.insert(conv)
            currentConversation = conv
        }
        let msg = ChatMessage(role: role, content: content)
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
                content: msg.content
            )
        }
        if let agentName = conversation.agentName {
            appState.selectedAgentPath = agentService.agents.first { $0.name == agentName }?.filePath.path
        }
    }

    private func deleteConversation(_ conversation: Conversation) {
        if currentConversation?.id == conversation.id {
            appState.chatMessages.removeAll()
            currentConversation = nil
        }
        modelContext.delete(conversation)
        try? modelContext.save()
    }

    private func autoTitleConversation(_ conv: Conversation, userMessage: String, assistantMessage: String) async {
        let prompt = "Generate a 3-5 word title for this conversation. Output ONLY the title, nothing else.\n\nUser: \(userMessage.prefix(200))\nAssistant: \(assistantMessage.prefix(300))"
        if let title = try? await ClaudeService.shared.query(prompt, systemPrompt: "Output only a short title. No quotes, no punctuation, no explanation.") {
            let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
            if !cleaned.isEmpty && cleaned.count < 60 {
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
}
