import SwiftUI
import SwiftData

struct AIChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<MCPServer> { $0.isEnabled }) private var activeServers: [MCPServer]
    @Query private var notes: [Note]
    @Query private var tasks: [TaskItem]

    @State private var inputText = ""
    @State private var useMCP = true
    @State private var showSaveToKnowledge = false
    @State private var isSavingKnowledge = false
    @State private var currentConversation: Conversation?
    @State private var chatTask: Task<Void, Never>?
    @State private var lastFailedMessage: String?
    @FocusState private var inputFocused: Bool

    // Slash commands
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
        VStack(spacing: 0) {
            // MARK: - Toolbar
            HStack(spacing: DS.Spacing.sm) {
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
                        ZStack {
                            Circle()
                                .fill(DS.Colors.accent.opacity(0.12))
                                .frame(width: 26, height: 26)
                            Image(systemName: selectedAgent?.icon ?? "brain.head.profile")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DS.Colors.accent)
                        }
                        Text(selectedAgent?.name ?? "Default Assistant")
                            .font(DS.Font.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.trailing, DS.Spacing.sm)
                    .padding(.leading, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                if let agent = selectedAgent {
                    Text(agent.role)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                ActiveRulesBar(
                    rules: RuleFileService.shared.matchingRules(for: appState.activeContextDictionary),
                    disabledRuleIDs: Bindable(appState).disabledRuleIDs
                )

                if !activeServers.isEmpty {
                    Toggle(isOn: $useMCP) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "wrench.and.screwdriver")
                            Text("MCP (\(activeServers.count))")
                        }
                        .font(DS.Font.caption)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }

                if !appState.chatMessages.isEmpty {
                    Button {
                        saveConversationToKnowledge()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            if isSavingKnowledge {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: "brain.head.profile.fill")
                                    .font(.system(size: 9))
                            }
                            Text("Save")
                                .font(DS.Font.small)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(DS.Colors.accent)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs + 1)
                        .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plainPointer)
                    .disabled(isSavingKnowledge)
                    .help("Save insights to Knowledge")
                }

                DSToolbarButton(icon: "arrow.counterclockwise", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                    appState.chatMessages.removeAll()
                    currentConversation = nil
                }
                .help("New conversation")
            }
            .frame(height: DS.Layout.toolbarHeight)
            .padding(.horizontal, DS.Spacing.xl)
            .background(.bar)

            Divider()

            // MARK: - Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if appState.chatMessages.isEmpty && !appState.isChatProcessing {
                            WelcomePrompts { prompt in
                                inputText = prompt
                                sendMessage()
                            }
                            .padding(.top, 60)
                        }

                        LazyVStack(spacing: 0) {
                            ForEach(appState.chatMessages) { message in
                                ChatBubble(message: message, onRetry: message.role == .error ? retryLastMessage : nil)
                                    .id(message.id)
                            }

                            if appState.isChatProcessing {
                                ThinkingIndicator(startTime: appState.chatProcessingStartTime ?? Date())
                                    .id("thinking")
                                    .padding(.horizontal, DS.Spacing.xl)
                                    .padding(.vertical, DS.Spacing.md)
                            }
                        }
                    }
                    .padding(.bottom, DS.Spacing.lg)
                }
                .onChange(of: appState.chatMessages.count) {
                    scrollToEnd(proxy)
                }
                .onChange(of: appState.isChatProcessing) {
                    scrollToEnd(proxy)
                }
            }

            // MARK: - Input Area
            VStack(spacing: 0) {
                Divider()

                ZStack(alignment: .bottomLeading) {
                    if showSlashMenu {
                        SlashCommandMenu(
                            skills: skillService.skills,
                            filter: slashFilter,
                            selectedIndex: $slashSelectedIndex
                        ) { skill in
                            showSlashMenu = false
                            inputText = "/\(skill.commandName) "
                        }
                        .offset(y: -8)
                        .zIndex(10)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    VStack(spacing: DS.Spacing.sm) {
                        HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
                            TextField("Message DeepThink — type / for skills", text: $inputText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(1...8)
                                .font(.system(size: 13))
                                .focused($inputFocused)
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

                            if appState.isChatProcessing {
                                Button {
                                    chatTask?.cancel()
                                    appState.isChatProcessing = false
                                    appState.chatProcessingStartTime = nil
                                } label: {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(DS.Colors.danger)
                                }
                                .buttonStyle(.plainPointer)
                                .help("Stop generating")
                            } else {
                                Button(action: sendMessage) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? DS.Colors.textTertiary.opacity(0.5) : DS.Colors.accent)
                                }
                                .buttonStyle(.plainPointer)
                                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .strokeBorder(inputFocused ? DS.Colors.accent.opacity(0.3) : DS.Colors.border, lineWidth: 1)
                    )
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.md)
            }
            .background(.bar)
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

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        if appState.isChatProcessing {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("thinking", anchor: .bottom) }
        } else if let last = appState.chatMessages.last {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

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
        if servers.contains(where: { $0.name == "DeepThink Workspace" }) {
            return servers
        }
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

    private func activeRulesSystemPrompt() -> String? {
        let rules = appState.activeRules
        guard !rules.isEmpty else { return nil }
        return rules.map { "## Rule: \($0.name)\n\($0.instruction)" }.joined(separator: "\n\n")
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
        if isWorkspace {
            servers = ensureWorkspaceServer(in: servers)
        }

        // Smart context: query-relevant workspace + TF-IDF RAG
        let ctx = smartWorkspaceContext(for: text)
        let projectScope = notes.first { $0.id == appState.selectedNoteID }?.project?.name
        let agentScope = selectedAgent?.knowledgeScope
        let ragContext = KnowledgeService.shared.ragContext(for: text, projectScope: projectScope, agentScope: agentScope)

        // Conversation summary for long chats (saves tokens)
        var conversationContext: String? = nil
        if appState.chatMessages.count > 10 {
            let older = Array(appState.chatMessages.prefix(appState.chatMessages.count - 4))
            if let convID = currentConversation?.id, let cached = ContextEngine.shared.getCachedSummary(for: convID) {
                conversationContext = "# Previous conversation summary\n\(cached)"
            }
        }

        chatTask = Task {
            // Background: summarize long conversations for future token savings
            if appState.chatMessages.count > 10, let convID = currentConversation?.id,
               ContextEngine.shared.getCachedSummary(for: convID) == nil {
                let older = Array(appState.chatMessages.prefix(appState.chatMessages.count - 4))
                if let summary = await ContextEngine.shared.summarizeConversation(messages: older, maxTokens: 400) {
                    ContextEngine.shared.cacheSummary(summary, for: convID)
                }
            }

            do {
                let response: String

                var contextParts: [String] = []
                if let convCtx = conversationContext { contextParts.append(convCtx) }
                if let rag = ragContext { contextParts.append(rag) }
                if !ctx.isEmpty { contextParts.append("# Workspace Context\n\n\(ctx)") }

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
                    response = try await ClaudeService.shared.query(fullPrompt, systemPrompt: systemPrompt)
                } else {
                    response = try await MCPService.shared.queryWithMCP(
                        prompt: fullPrompt,
                        servers: servers,
                        systemPrompt: systemPrompt
                    )
                }

                try Task.checkCancellation()

                await MainActor.run {
                    appState.chatMessages.append(AIMessage(role: .assistant, content: response))
                    persistMessage(role: "assistant", content: response)
                    appState.isChatProcessing = false
                    appState.chatProcessingStartTime = nil
                    lastFailedMessage = nil
                }

                // Auto-extract knowledge every 6 messages
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

    private func retryLastMessage() {
        guard let msg = lastFailedMessage else { return }
        if let last = appState.chatMessages.last, last.role == .error {
            appState.chatMessages.removeLast()
        }
        inputText = msg
        sendMessage()
    }

    // MARK: - Persistence (Feature 5)

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

    // MARK: - Save to Knowledge (Feature 11)

    private func saveConversationToKnowledge() {
        isSavingKnowledge = true
        let messages = appState.chatMessages
        Task {
            let success = await KnowledgeExtractionService.shared.extractFromConversation(messages: messages)
            await MainActor.run {
                isSavingKnowledge = false
                if success {
                    showSaveToKnowledge = true
                }
            }
        }
    }
}

// MARK: - Thinking Indicator

private struct ThinkingIndicator: View {
    let startTime: Date
    @State private var elapsedSeconds: Int = 0
    @State private var dotPhase: Int = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let dotTimer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    private let thinkingPhrases = [
        "Thinking", "Reasoning", "Analyzing", "Processing", "Reflecting"
    ]

    private var currentPhrase: String {
        let index = (elapsedSeconds / 8) % thinkingPhrases.count
        return thinkingPhrases[index]
    }

    private var dots: String {
        String(repeating: ".", count: (dotPhase % 3) + 1)
    }

    private var elapsedText: String {
        if elapsedSeconds < 60 {
            return "\(elapsedSeconds)s"
        }
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        return "\(mins)m \(secs)s"
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            ThinkingOrb()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.sm) {
                    Text(currentPhrase + dots)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(minWidth: 100, alignment: .leading)
                        .contentTransition(.numericText())

                    Text(elapsedText)
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .contentTransition(.numericText())
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            }

            Spacer(minLength: 80)
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                elapsedSeconds = Int(Date().timeIntervalSince(startTime))
            }
        }
        .onReceive(dotTimer) { _ in
            dotPhase += 1
        }
    }
}

private struct ThinkingOrb: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 2

            for i in 0..<3 {
                let offset = CGFloat(i) * .pi * 2 / 3
                let x = center.x + cos(phase + offset) * radius * 0.4
                let y = center.y + sin(phase + offset) * radius * 0.4
                let dotRadius = radius * 0.22

                let opacity = 0.4 + 0.6 * (1 + cos(phase * 2 + offset)) / 2

                context.opacity = opacity
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )),
                    with: .color(Color.accentColor)
                )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Welcome Prompts

private struct WelcomePrompts: View {
    let onSelect: (String) -> Void

    private let suggestions = [
        ("Summarize my recent notes", "doc.text.magnifyingglass"),
        ("What tasks need attention?", "exclamationmark.triangle"),
        ("Help me write a design doc", "pencil.and.outline"),
        ("Analyze my project progress", "chart.bar"),
        ("Search my knowledge base", "brain"),
        ("Break down a complex task", "list.bullet.indent"),
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            VStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DS.Colors.accent.opacity(0.08))
                        .frame(width: 64, height: 64)
                    Circle()
                        .fill(DS.Colors.accent.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DS.Colors.accent)
                }

                Text("How can I help?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)

                Text("Your notes, tasks, and knowledge are always in context.")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            HStack(spacing: DS.Spacing.sm) {
                ForEach(Array(suggestions.prefix(3)), id: \.0) { title, icon in
                    SuggestionChip(title: title, icon: icon) { onSelect(title) }
                }
            }
            HStack(spacing: DS.Spacing.sm) {
                ForEach(Array(suggestions.suffix(3)), id: \.0) { title, icon in
                    SuggestionChip(title: title, icon: icon) { onSelect(title) }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SuggestionChip: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Colors.accent)
                Text(title)
                    .font(DS.Font.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + 1)
            .background(
                isHovered ? DS.Colors.fillSecondary : DS.Colors.fill,
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isHovered ? DS.Colors.borderHover : DS.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: AIMessage
    var onRetry: (() -> Void)? = nil
    @State private var isHovered = false
    @State private var copied = false

    var body: some View {
        if message.role == .user {
            userBubble
        } else if message.role == .error {
            errorBubble
        } else {
            assistantBubble
        }
    }

    // MARK: - User Message

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 120)
            Text(message.content)
                .font(.system(size: 13))
                .foregroundStyle(DS.Colors.textPrimary)
                .textSelection(.enabled)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .background(DS.Colors.accent.opacity(0.08), in: BubbleShape(isUser: true))
                .overlay(BubbleShape(isUser: true).strokeBorder(DS.Colors.accent.opacity(0.12), lineWidth: 1))
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.xs)
    }

    // MARK: - Assistant Message

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DS.Colors.accent.opacity(0.15), DS.Colors.accent.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.accent)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                if let attributed = try? AttributedString(
                    markdown: message.content,
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                ) {
                    Text(attributed)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                } else {
                    Text(message.content)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                }

                HStack(spacing: DS.Spacing.sm) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 9, weight: .medium))
                            Text(copied ? "Copied" : "Copy")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(copied ? DS.Colors.success : DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plainPointer)

                    Text(message.timestamp.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .opacity(isHovered ? 1 : 0)
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.sm)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }

    // MARK: - Error Message

    private var errorBubble: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DS.Colors.danger.opacity(0.10))
                    .frame(width: 28, height: 28)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Colors.danger)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Colors.danger.opacity(0.9))

                if let onRetry {
                    Button(action: onRetry) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Retry")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(DS.Colors.accent)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs + 1)
                        .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plainPointer)
                }
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - Bubble Shape

private struct BubbleShape: Shape, InsettableShape {
    let isUser: Bool
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 16
        let small: CGFloat = 4
        return RoundedRectangle(cornerRadius: r)
            .path(in: rect.insetBy(dx: insetAmount, dy: insetAmount))
    }

    func inset(by amount: CGFloat) -> BubbleShape {
        BubbleShape(isUser: isUser, insetAmount: insetAmount + amount)
    }
}
