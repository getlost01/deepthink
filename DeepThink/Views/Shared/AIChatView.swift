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
                            .padding(.top, DS.Spacing.xxxl)
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

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(AIMessage(role: .user, content: text))
        inputText = ""
        isProcessing = true

        let ctx = workspaceContext
        let servers = useMCP ? Array(activeServers) : []

        Task {
            do {
                let response: String
                let fullPrompt = ctx.isEmpty ? text : "Workspace context:\n\(ctx)\n\nUser: \(text)"
                let systemPrompt = "You are DeepThink AI, a powerful knowledge assistant. You help with analysis, research, writing, coding, and organization. Be concise and helpful. Use markdown formatting."

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
                    .foregroundStyle(message.role == .error ? DS.Colors.error : DS.Colors.accent)
                    .frame(width: 24, height: 24)
                    .background(
                        (message.role == .error ? DS.Colors.error : DS.Colors.accent).opacity(0.10),
                        in: Circle()
                    )
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: DS.Spacing.xs) {
                if message.role == .error {
                    Text(message.content)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.error)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.error.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                } else if let attributed = try? AttributedString(markdown: message.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                        .font(DS.Font.body)
                        .textSelection(.enabled)
                        .padding(DS.Spacing.md)
                        .background(
                            message.role == .user
                                ? AnyShapeStyle(DS.Colors.accent.opacity(0.08))
                                : AnyShapeStyle(DS.Colors.inputBg),
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
                                : AnyShapeStyle(DS.Colors.inputBg),
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
