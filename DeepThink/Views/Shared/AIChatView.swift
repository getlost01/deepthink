import SwiftUI
import SwiftData

struct AIChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<MCPServer> { $0.isEnabled }) private var activeServers: [MCPServer]
    @Query private var notes: [Note]
    @Query private var tasks: [TaskItem]

    @State private var messages: [AIMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var useMCP = true
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
                // Agent picker
                Menu {
                    Button {
                        appState.selectedAgentPath = nil
                        messages.removeAll()
                    } label: {
                        Label("Default Assistant", systemImage: "brain.head.profile")
                    }

                    Divider()

                    ForEach(agentService.agents) { agent in
                        Button {
                            appState.selectedAgentPath = agent.filePath.path
                            messages.removeAll()
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

                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                DSToolbarButton(icon: "trash", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                    messages.removeAll()
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
                        if messages.isEmpty {
                            WelcomePrompts { prompt in
                                inputText = prompt
                                sendMessage()
                            }
                            .padding(.top, DS.Spacing.xxl)
                        }

                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(DS.Spacing.xl)
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(alignment: .bottom, spacing: DS.Spacing.md) {
                TextField("Ask Claude anything...", text: $inputText, axis: .vertical)
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
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
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

        messages.append(AIMessage(role: .user, content: text))
        inputText = ""
        isProcessing = true

        let ctx = workspaceContext
        let isWorkspace = isWorkspaceRequest(text)
        var servers = useMCP ? Array(activeServers) : []
        if isWorkspace {
            servers = ensureWorkspaceServer(in: servers)
        }

        Task {
            do {
                let response: String
                let fullPrompt = ctx.isEmpty ? text : "Workspace context:\n\(ctx)\n\nUser: \(text)"

                let systemPrompt: String
                if let agent = selectedAgent {
                    systemPrompt = AgentFileService.shared.buildSystemPrompt(for: agent)
                } else if isWorkspace {
                    systemPrompt = "You are DeepThink AI, a workspace assistant with tools to create, update, delete, and list tasks, notes, and projects. When the user asks to create or modify workspace items, USE the workspace tools to do it — don't just describe what you would do. After using a tool, confirm what was done. Be concise. Use markdown formatting."
                } else {
                    systemPrompt = "You are DeepThink AI, a powerful knowledge assistant. You help with analysis, research, writing, coding, and organization. Be concise and helpful. Use markdown formatting."
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
                    messages.append(AIMessage(role: .assistant, content: response))
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    messages.append(AIMessage(role: .error, content: error.localizedDescription))
                    isProcessing = false
                }
            }
        }
    }
}

private struct WelcomePrompts: View {
    let onSelect: (String) -> Void

    private let suggestions = [
        ("Summarize my recent work", "sparkles"),
        ("What tasks need attention?", "exclamationmark.triangle"),
        ("Help me write a design doc", "doc.text"),
        ("Analyze my project progress", "chart.bar"),
        ("Search the web for...", "globe"),
        ("Query my database", "cylinder"),
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.sm) {
                Text("How can I help?")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("Ask me anything about your workspace, or try a suggestion below")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                ForEach(suggestions, id: \.0) { title, icon in
                    Button {
                        onSelect(title)
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: icon)
                                .font(.system(size: DS.IconSize.sm, weight: .medium))
                                .foregroundStyle(DS.Colors.accent)
                                .frame(width: 20)
                            Text(title)
                                .font(DS.Font.body)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(DS.Spacing.md)
                        .dsClickable()
                    }
                    .buttonStyle(.plainPointer)
                }
            }
            .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ChatBubble: View {
    let message: AIMessage
    @State private var isHovered = false

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
            }

            if message.role != .user {
                Spacer(minLength: 80)
            }
        }
    }
}
