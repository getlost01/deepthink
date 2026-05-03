import SwiftUI

struct AgentListView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedAgent: AgentFile?

    private var agentService: AgentFileService { AgentFileService.shared }

    var body: some View {
        ResizableSplitView(minLeftWidth: 280, minRightWidth: 400) {
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.md) {
                    DSStatChip(label: "Agents", value: "\(agentService.agents.count)", icon: "person.2.circle")
                    Spacer()
                    DSActionButton(title: "New", icon: "plus") {
                        createNewAgent()
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)

                Divider()

                if agentService.agents.isEmpty {
                    DSEmptyState(
                        icon: "person.2.circle",
                        title: "Create Your First Agent",
                        subtitle: "Agents are specialized AI personas — give them a role, pick which knowledge they can access, and chat with them in AI Bot.",
                        action: { createNewAgent() },
                        actionTitle: "Create Agent"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(agentService.agents) { agent in
                                AgentRow(
                                    agent: agent,
                                    isSelected: selectedAgent?.id == agent.id
                                ) {
                                    selectedAgent = agent
                                }
                                if agent.id != agentService.agents.last?.id {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                    }
                }
            }
        } right: {
            if let agent = selectedAgent {
                AgentDetailEditor(agent: agent) {
                    appState.selectedAgentPath = agent.filePath.path
                    appState.selectedSection = .ai
                } onDelete: {
                    agentService.delete(agent: agent)
                    selectedAgent = nil
                }
            } else {
                DSEmptyState(
                    icon: "person.2.circle",
                    title: "Select an Agent",
                    subtitle: "Choose an agent from the list to edit its system prompt, role, and knowledge scope. Changes auto-save."
                )
            }
        }
        .onAppear { agentService.reload() }
    }

    private func createNewAgent() {
        agentService.create(
            name: "New Agent",
            role: "Describe this agent's role",
            icon: "person.circle",
            model: nil,
            systemPrompt: "You are a helpful assistant.",
            knowledgeScope: []
        )
        selectedAgent = agentService.agents.first { $0.name == "New Agent" }
    }
}

// MARK: - Agent Row

private struct AgentRow: View {
    let agent: AgentFile
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(isSelected ? DS.Colors.accent.opacity(0.15) : DS.Colors.accentFill)
                        .frame(width: 32, height: 32)
                    Image(systemName: agent.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(agent.name)
                            .font(DS.Font.body)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundStyle(DS.Colors.textPrimary)
                        if agent.isBuiltIn {
                            Text("Built-in")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(DS.Colors.textTertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(DS.Colors.fill, in: Capsule())
                        }
                    }
                    Text(agent.role)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if let _ = agent.model {
                    Text(agent.modelDisplayName)
                        .font(DS.Font.small)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.08), in: Capsule())
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background(isSelected ? DS.Colors.accentFill : (isHovered ? DS.Colors.fillSecondary : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Agent Detail Editor

private struct AgentDetailEditor: View {
    let agent: AgentFile
    let onChat: () -> Void
    let onDelete: () -> Void

    @State private var name: String = ""
    @State private var role: String = ""
    @State private var icon: String = ""
    @State private var knowledgeScope: String = ""
    @State private var model: String?
    @State private var editablePrompt: String = ""
    @State private var hasLoaded = false
    @State private var saveTask: Task<Void, Never>?

    private let icons = [
        "person.circle", "magnifyingglass.circle", "chevron.left.forwardslash.chevron.right",
        "list.bullet.rectangle", "pencil.circle", "chart.bar.xaxis",
        "brain", "lightbulb", "wrench.and.screwdriver", "globe"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar: icon picker, chat, delete
            HStack(spacing: DS.Spacing.sm) {
                ForEach(icons, id: \.self) { ic in
                    Button {
                        icon = ic
                        scheduleSave()
                    } label: {
                        Image(systemName: ic)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(icon == ic ? .white : DS.Colors.textTertiary)
                            .frame(width: 22, height: 22)
                            .background(icon == ic ? DS.Colors.accent : DS.Colors.fill, in: Circle())
                    }
                    .buttonStyle(.plainPointer)
                }

                Spacer()

                Picker("", selection: Binding(
                    get: { model ?? "default" },
                    set: { model = $0 == "default" ? nil : $0; scheduleSave() }
                )) {
                    Text("Default").tag("default")
                    Text("Haiku").tag("claude-haiku-4-5-20251001")
                    Text("Sonnet").tag("claude-sonnet-4-6")
                    Text("Opus").tag("claude-opus-4-6")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Button(action: onChat) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 9))
                        Text("Chat")
                            .font(DS.Font.small)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs + 2)
                    .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plainPointer)

                if !agent.isBuiltIn {
                    DSToolbarButton(icon: "trash", color: DS.Colors.danger, size: DS.IconSize.sm) {
                        onDelete()
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(.bar)

            Divider()

            // Inline fields
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: DS.IconSize.lg, weight: .medium))
                        .foregroundStyle(DS.Colors.accent)
                        .frame(width: 24)
                    TextField("Agent name", text: $name)
                        .textFieldStyle(.plain)
                        .font(DS.Font.title)
                        .onChange(of: name) { scheduleSave() }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)

                TextField("Describe what this agent does...", text: $role)
                    .textFieldStyle(.plain)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.leading, 24 + DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .onChange(of: role) { scheduleSave() }

                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "book")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Colors.textTertiary)
                    TextField("Knowledge scope tags (comma-separated)", text: $knowledgeScope)
                        .textFieldStyle(.plain)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .onChange(of: knowledgeScope) { scheduleSave() }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
            }

            Divider()

            // System prompt editor
            MarkdownEditorWithToggle(
                text: $editablePrompt,
                placeholder: "Write agent system prompt...",
                onSave: { saveAgent() },
                autoSaveInterval: 10
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadAgent() }
        .onChange(of: agent.id) { loadAgent() }
    }

    private func loadAgent() {
        name = agent.name
        role = agent.role
        icon = agent.icon
        model = agent.model
        knowledgeScope = agent.knowledgeScope.joined(separator: ", ")
        editablePrompt = agent.systemPrompt
        hasLoaded = true
    }

    private func scheduleSave() {
        guard hasLoaded else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await MainActor.run { saveAgent() }
        }
    }

    private func saveAgent() {
        guard hasLoaded else { return }
        let scope = knowledgeScope.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let updated = AgentFile(
            name: name, role: role, icon: icon, model: model,
            systemPrompt: editablePrompt, skills: agent.skills, knowledgeScope: scope,
            filePath: agent.filePath, isBuiltIn: agent.isBuiltIn
        )
        AgentFileService.shared.save(agent: updated)
    }
}
