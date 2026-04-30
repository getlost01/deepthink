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
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundStyle(.purple)
                Text("AI Chat")
                    .font(.headline)

                Spacer()

                if !activeServers.isEmpty {
                    Toggle(isOn: $useMCP) {
                        HStack(spacing: 4) {
                            Image(systemName: "wrench.and.screwdriver")
                            Text("MCP (\(activeServers.count))")
                        }
                        .font(.caption)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }

                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Button {
                    messages.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Clear chat")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if messages.isEmpty {
                            WelcomePrompts { prompt in
                                inputText = prompt
                                sendMessage()
                            }
                            .padding(.top, 40)
                        }

                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(20)
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask Claude anything...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .font(.body)
                    .focused($inputFocused)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.3) : .purple)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
            }
            .padding(16)
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
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundStyle(.purple.opacity(0.4))

            Text("How can I help?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Chat with Claude, powered by your workspace context and MCP tools")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(suggestions, id: \.0) { title, icon in
                    Button {
                        onSelect(title)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: icon)
                                .font(.caption)
                                .foregroundStyle(.purple)
                                .frame(width: 20)
                            Text(title)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ChatBubble: View {
    let message: AIMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            if message.role != .user {
                Image(systemName: message.role == .error ? "exclamationmark.triangle" : "brain.head.profile")
                    .font(.caption)
                    .foregroundStyle(message.role == .error ? .red : .purple)
                    .frame(width: 24, height: 24)
                    .background(message.role == .error ? .red.opacity(0.1) : .purple.opacity(0.1), in: Circle())
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .error {
                    Text(message.content)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(12)
                        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                } else if let attributed = try? AttributedString(markdown: message.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                        .font(.callout)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(
                            message.role == .user
                                ? AnyShapeStyle(Color.purple.opacity(0.1))
                                : AnyShapeStyle(Color(nsColor: .controlBackgroundColor)),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                } else {
                    Text(message.content)
                        .font(.callout)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(
                            message.role == .user
                                ? AnyShapeStyle(Color.purple.opacity(0.1))
                                : AnyShapeStyle(Color(nsColor: .controlBackgroundColor)),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role != .user {
                Spacer(minLength: 60)
            }
        }
    }
}
