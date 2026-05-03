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
    @FocusState private var inputFocused: Bool

    private var agentService: AgentFileService { AgentFileService.shared }

    private var selectedAgent: AgentFile? {
        guard let path = appState.selectedAgentPath else { return nil }
        return agentService.agents.first { $0.filePath.path == path }
    }

    private var workspaceContext: String {
        var ctx: [String] = []
        let recentNotes = notes.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(5)
        if !recentNotes.isEmpty {
            ctx.append("Recent Notes:\n" + recentNotes.map { "- \($0.title): \($0.content.prefix(200))" }.joined(separator: "\n"))
        }
        let active = tasks.filter { $0.status == .inProgress || $0.status == .todo }.prefix(10)
        if !active.isEmpty {
            ctx.append("Active Tasks:\n" + active.map { "- [\($0.status.rawValue)] \($0.title)" }.joined(separator: "\n"))
        }
        return ctx.joined(separator: "\n\n")
    }

    var body: some View {
        VStack(spacing: 0) {
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
                            .font(.system(size: DS.IconSize.sm, weight: .medium))
                            .foregroundStyle(DS.Colors.accent)
                        Text(selectedAgent?.name ?? "Default Assistant")
                            .font(DS.Font.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs + 1)
                    .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
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
                            Text("Save to Knowledge")
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
                    .help("Extract knowledge from this conversation")
                }

                DSToolbarButton(icon: "trash", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                    appState.chatMessages.removeAll()
                    currentConversation = nil
                }
                .help("Clear chat")
            }
            .frame(height: DS.Layout.toolbarHeight)
            .padding(.horizontal, DS.Spacing.xl)
            .background(.bar)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.lg) {
                        if appState.chatMessages.isEmpty && !appState.isChatProcessing {
                            WelcomePrompts { prompt in
                                inputText = prompt
                                sendMessage()
                            }
                            .padding(.top, DS.Spacing.xxl)
                        }

                        ForEach(appState.chatMessages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }

                        if appState.isChatProcessing {
                            ThinkingIndicator(startTime: appState.chatProcessingStartTime ?? Date())
                                .id("thinking")
                        }
                    }
                    .padding(DS.Spacing.xl)
                }
                .onChange(of: appState.chatMessages.count) {
                    if appState.isChatProcessing {
                        withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                    } else if let last = appState.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: appState.isChatProcessing) {
                    if appState.isChatProcessing {
                        withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                    } else if let last = appState.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(alignment: .bottom, spacing: DS.Spacing.md) {
                TextField("Ask anything — AI searches your knowledge automatically...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .font(DS.Font.body)
                    .focused($inputFocused)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: DS.IconSize.xl))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? DS.Colors.textTertiary : DS.Colors.accent)
                }
                .buttonStyle(.plainPointer)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || appState.isChatProcessing)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(.bar)
        }
        .onAppear {
            inputFocused = true
            if let pending = appState.pendingChatMessage {
                inputText = pending
                appState.pendingChatMessage = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { sendMessage() }
            }
        }
        .alert("Saved to Knowledge", isPresented: $showSaveToKnowledge) {
            Button("OK") {}
        } message: {
            Text("Key insights from this conversation have been extracted and saved to your knowledge base.")
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

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        appState.chatMessages.append(AIMessage(role: .user, content: text))
        persistMessage(role: "user", content: text)
        inputText = ""
        appState.isChatProcessing = true
        appState.chatProcessingStartTime = Date()

        let ctx = workspaceContext
        let isWorkspace = isWorkspaceRequest(text)
        var servers = useMCP ? Array(activeServers) : []
        if isWorkspace {
            servers = ensureWorkspaceServer(in: servers)
        }

        let ragContext = KnowledgeService.shared.ragContext(for: text)

        Task {
            do {
                let response: String

                var contextParts: [String] = []
                if let rag = ragContext { contextParts.append(rag) }
                if !ctx.isEmpty { contextParts.append("# Workspace Context\n\n\(ctx)") }

                let fullPrompt: String
                if contextParts.isEmpty {
                    fullPrompt = text
                } else {
                    fullPrompt = contextParts.joined(separator: "\n\n") + "\n\nUser: \(text)"
                }

                let systemPrompt: String
                if let agent = selectedAgent {
                    systemPrompt = AgentFileService.shared.buildSystemPrompt(for: agent)
                } else if isWorkspace {
                    systemPrompt = "You are DeepThink AI, a workspace assistant with tools to create, update, delete, and list tasks, notes, and projects. When the user asks to create or modify workspace items, USE the workspace tools to do it — don't just describe what you would do. After using a tool, confirm what was done. Be concise. Use markdown formatting."
                } else {
                    systemPrompt = "You are DeepThink AI, a powerful knowledge assistant. You have access to the user's knowledge base which is automatically searched for relevant context. You help with analysis, research, writing, coding, and organization. Be concise and helpful. Use markdown formatting. When your answer draws on knowledge base entries, mention which sources informed it."
                }

                if servers.isEmpty {
                    response = try await ClaudeService.shared.query(fullPrompt, systemPrompt: systemPrompt)
                } else {
                    response = try await MCPService.shared.queryWithMCP(
                        prompt: fullPrompt,
                        servers: servers,
                        systemPrompt: systemPrompt
                    )
                }
                await MainActor.run {
                    appState.chatMessages.append(AIMessage(role: .assistant, content: response))
                    persistMessage(role: "assistant", content: response)
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
        ("Summarize my recent notes", "doc.text.magnifyingglass", "Get a quick overview of your latest writing"),
        ("What tasks need attention?", "exclamationmark.triangle", "Find overdue or high-priority tasks"),
        ("Help me write a design doc", "pencil.and.outline", "Draft documents with AI assistance"),
        ("Analyze my project progress", "chart.bar", "Review how your projects are tracking"),
        ("What do I know about...", "brain", "Search your knowledge base with AI"),
        ("Break down this task", "list.bullet.indent", "Split complex work into actionable steps"),
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(DS.Colors.accent)
                    .padding(.bottom, DS.Spacing.sm)
                Text("How can I help?")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("I have access to your notes, tasks, and knowledge base. Ask me anything or pick a suggestion.")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                ForEach(suggestions, id: \.0) { title, icon, hint in
                    Button {
                        onSelect(title)
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: icon)
                                .font(.system(size: DS.IconSize.md, weight: .medium))
                                .foregroundStyle(DS.Colors.accent)
                                .frame(width: 24, height: 24)
                                .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(DS.Font.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(DS.Colors.textPrimary)
                                    .lineLimit(1)
                                Text(hint)
                                    .font(DS.Font.small)
                                    .foregroundStyle(DS.Colors.textTertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(DS.Spacing.md)
                        .dsClickable()
                    }
                    .buttonStyle(.plainPointer)
                }
            }
            .frame(maxWidth: 560)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: AIMessage
    @State private var isHovered = false

    private var timeString: String {
        message.timestamp.formatted(.dateTime.hour().minute())
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            if message.role == .user {
                Spacer(minLength: 80)
            }

            if message.role != .user {
                Image(systemName: message.role == .error ? "exclamationmark.triangle" : "brain.head.profile")
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                    .foregroundStyle(message.role == .error ? DS.Colors.danger : DS.Colors.accent)
                    .frame(width: 24, height: 24)
                    .background(
                        (message.role == .error ? DS.Colors.danger : DS.Colors.accent).opacity(0.10),
                        in: Circle()
                    )
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: DS.Spacing.xs) {
                if message.role == .error {
                    Text(message.content)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.danger)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.danger.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                } else if let attributed = try? AttributedString(markdown: message.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                        .font(DS.Font.body)
                        .textSelection(.enabled)
                        .padding(DS.Spacing.md)
                        .background(
                            message.role == .user
                                ? AnyShapeStyle(DS.Colors.accent.opacity(0.08))
                                : AnyShapeStyle(DS.Colors.fillSecondary),
                            in: RoundedRectangle(cornerRadius: DS.Radius.md)
                        )
                } else {
                    Text(message.content)
                        .font(DS.Font.body)
                        .textSelection(.enabled)
                        .padding(DS.Spacing.md)
                        .background(
                            message.role == .user
                                ? AnyShapeStyle(DS.Colors.accent.opacity(0.08))
                                : AnyShapeStyle(DS.Colors.fillSecondary),
                            in: RoundedRectangle(cornerRadius: DS.Radius.md)
                        )
                }

                Text(timeString)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .opacity(isHovered ? 1 : 0)
            }

            if message.role != .user {
                Spacer(minLength: 80)
            }
        }
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}
