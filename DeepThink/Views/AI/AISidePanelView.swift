import SwiftUI

struct AISidePanelView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText: String = ""
    @State private var messages: [AIPanelMessage] = []
    @State private var isQuerying: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: DS.IconSize.md, weight: .medium))
                    .foregroundStyle(DS.Colors.accent)

                Text("AI Assistant")
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)

                Spacer()

                DSToolbarButton(icon: "xmark", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                    appState.toggleAIPanel()
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .frame(height: DS.Layout.headerHeight)
            .background(.bar)

            Divider()

            // Context display
            if !appState.aiPanelContext.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Context")
                        .font(DS.Font.tiny)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .textCase(.uppercase)

                    Text(appState.aiPanelContext.prefix(200) + (appState.aiPanelContext.count > 200 ? "..." : ""))
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(3)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.subtleBg)
                .overlay(
                    Rectangle()
                        .fill(DS.Colors.borderSubtle)
                        .frame(height: 1),
                    alignment: .bottom
                )
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.md) {
                        if messages.isEmpty {
                            emptyState
                                .padding(.top, DS.Spacing.xxxl)
                        }

                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                        if isQuerying {
                            HStack(spacing: DS.Spacing.sm) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Thinking...")
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DS.Spacing.lg)
                            .id("loading")
                        }
                    }
                    .padding(.vertical, DS.Spacing.md)
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input bar
            HStack(spacing: DS.Spacing.sm) {
                TextField("Ask about this content...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(DS.Font.body)
                    .onSubmit {
                        sendMessage()
                    }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: DS.IconSize.xl, weight: .medium))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? DS.Colors.textTertiary : DS.Colors.accent)
                }
                .buttonStyle(.plainPointer)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isQuerying)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.inputBg, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Colors.borderSubtle, lineWidth: 1)
            )
            .padding(DS.Spacing.md)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(DS.Colors.textTertiary)

            VStack(spacing: DS.Spacing.sm) {
                Text("Ask AI anything")
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)

                Text("Ask questions about what you're currently viewing or get help with your work.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(_ message: AIPanelMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: DS.Spacing.xxl) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: DS.Spacing.xs) {
                Text(message.role == .user ? "You" : "AI")
                    .font(DS.Font.tiny)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textTertiary)

                Text(message.content)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .textSelection(.enabled)
                    .padding(DS.Spacing.md)
                    .background(
                        message.role == .user
                            ? DS.Colors.accent.opacity(0.1)
                            : DS.Colors.subtleBg,
                        in: RoundedRectangle(cornerRadius: DS.Radius.md)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .strokeBorder(
                                message.role == .user
                                    ? DS.Colors.accent.opacity(0.15)
                                    : DS.Colors.borderSubtle,
                                lineWidth: 1
                            )
                    )
            }

            if message.role == .assistant { Spacer(minLength: DS.Spacing.xxl) }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Send

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isQuerying else { return }

        let userMessage = AIPanelMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        inputText = ""
        isQuerying = true

        Task {
            do {
                let contextPrefix = appState.aiPanelContext.isEmpty
                    ? ""
                    : "Context:\n\(appState.aiPanelContext)\n\n"
                let fullPrompt = contextPrefix + trimmed

                let response = try await ClaudeService.shared.query(
                    fullPrompt,
                    systemPrompt: "You are a helpful AI assistant embedded in the DeepThink app. Answer concisely and helpfully based on any provided context."
                )
                let assistantMessage = AIPanelMessage(role: .assistant, content: response)
                await MainActor.run {
                    messages.append(assistantMessage)
                    isQuerying = false
                }
            } catch {
                let errorMessage = AIPanelMessage(role: .assistant, content: "Error: \(error.localizedDescription)")
                await MainActor.run {
                    messages.append(errorMessage)
                    isQuerying = false
                }
            }
        }
    }
}

// MARK: - Message Model

struct AIPanelMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role {
        case user
        case assistant
    }
}
