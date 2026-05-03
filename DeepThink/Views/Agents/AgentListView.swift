import SwiftUI

struct AgentListView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedAgent: AgentFile?
    @State private var showDeleteConfirm = false
    @State private var showTemplates = false

    private var agentService: AgentFileService { AgentFileService.shared }

    var body: some View {
        ResizableSplitView(minLeftWidth: 280, minRightWidth: 400) {
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.md) {
                    DSStatChip(label: "Assistants", value: "\(agentService.agents.count)", icon: "person.2.circle")
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
                        title: "Create Your First Assistant",
                        subtitle: "Assistants are AI helpers tailored for specific tasks — like a writing coach, research buddy, or task planner. Pick a template to get started quickly.",
                        hint: "Try starting with a template, then customize it to fit your needs",
                        action: { showTemplates = true },
                        actionTitle: "Browse Templates"
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
                    appState.selectedSection = .aiAssistant
                } onDelete: {
                    showDeleteConfirm = true
                }
            } else {
                DSEmptyState(
                    icon: "person.2.circle",
                    title: "Select an Assistant",
                    subtitle: "Choose an assistant from the list to customize its personality, expertise, and what it knows about. Changes save automatically."
                )
            }
        }
        .onAppear { agentService.reload() }
        .confirmationDialog("Delete Assistant?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let agent = selectedAgent {
                    agentService.delete(agent: agent)
                    selectedAgent = nil
                }
            }
        } message: {
            Text("This will permanently delete \"\(selectedAgent?.name ?? "")\".")
        }
        .sheet(isPresented: $showTemplates) {
            AgentTemplateSheet { template in
                createFromTemplate(template)
            }
        }
    }

    private func createNewAgent() {
        let countBefore = agentService.agents.count
        agentService.create(
            name: "New Assistant",
            role: "Describe what this assistant helps with",
            icon: "person.circle",
            model: nil,
            systemPrompt: "You are a helpful assistant.",
            knowledgeScope: []
        )
        if agentService.agents.count > countBefore {
            selectedAgent = agentService.agents.last
        }
    }

    private func createFromTemplate(_ template: AgentTemplate) {
        let countBefore = agentService.agents.count
        agentService.create(
            name: template.name,
            role: template.role,
            icon: template.icon,
            model: nil,
            systemPrompt: template.systemPrompt,
            knowledgeScope: []
        )
        if agentService.agents.count > countBefore {
            selectedAgent = agentService.agents.last
        }
    }
}

// MARK: - Agent Templates

struct AgentTemplate: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let icon: String
    let description: String
    let systemPrompt: String

    static let templates: [AgentTemplate] = [
        AgentTemplate(
            name: "Research Assistant",
            role: "Finds and summarizes information",
            icon: "magnifyingglass.circle",
            description: "Helps you dig into topics, summarize articles, and gather insights from your knowledge base.",
            systemPrompt: "You are a research assistant. Help the user explore topics thoroughly. When answering questions, cite relevant sources from the knowledge base. Break down complex topics into digestible summaries. Ask clarifying questions when the research direction is unclear."
        ),
        AgentTemplate(
            name: "Writing Coach",
            role: "Helps improve your writing",
            icon: "pencil.circle",
            description: "Reviews drafts, suggests improvements, helps with tone and clarity, and assists with any kind of writing.",
            systemPrompt: "You are a writing coach. Help the user improve their writing by suggesting clearer phrasing, better structure, and more engaging tone. When reviewing drafts, be constructive and specific. Offer alternatives rather than just pointing out issues. Adapt your suggestions to the intended audience and purpose."
        ),
        AgentTemplate(
            name: "Task Planner",
            role: "Breaks work into actionable steps",
            icon: "list.bullet.rectangle",
            description: "Takes big goals and breaks them into manageable tasks with priorities and deadlines.",
            systemPrompt: "You are a task planner. Help the user break down large goals into concrete, actionable tasks. Suggest priorities, estimate effort, and identify dependencies. When creating plans, be specific and realistic. Ask about deadlines and constraints to make better suggestions."
        ),
        AgentTemplate(
            name: "Meeting Notes",
            role: "Summarizes discussions and action items",
            icon: "person.2",
            description: "Turns messy meeting notes into clean summaries with key decisions and next steps.",
            systemPrompt: "You are a meeting notes assistant. Help the user organize meeting notes into clear summaries. Extract key decisions, action items (with owners if mentioned), and follow-up topics. Use bullet points for clarity. If notes are rough or incomplete, ask clarifying questions."
        ),
        AgentTemplate(
            name: "Idea Brainstormer",
            role: "Generates and explores creative ideas",
            icon: "lightbulb",
            description: "Helps brainstorm solutions, explore possibilities, and think through ideas from different angles.",
            systemPrompt: "You are a creative brainstorming partner. Help the user generate ideas by exploring different angles, asking provocative questions, and building on their thoughts. Use techniques like analogies, reversals, and 'what if' scenarios. Be enthusiastic but also help evaluate which ideas have the most potential."
        ),
        AgentTemplate(
            name: "Code Explainer",
            role: "Makes technical concepts easy to understand",
            icon: "chevron.left.forwardslash.chevron.right",
            description: "Explains code, technical docs, and programming concepts in plain language.",
            systemPrompt: "You are a code explainer. Help the user understand technical concepts by explaining them in simple, accessible language. Use analogies to everyday concepts when helpful. When explaining code, walk through it step by step. Avoid jargon unless the user is comfortable with it — ask about their experience level."
        ),
    ]
}

private struct AgentTemplateSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (AgentTemplate) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose a Template")
                        .font(DS.Font.heading)
                    Text("Pick a starting point — you can customize everything later")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(DS.Font.body)
                    .buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surfaceElevated)

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: DS.Spacing.md)], spacing: DS.Spacing.md) {
                    ForEach(AgentTemplate.templates) { template in
                        TemplateCard(template: template) {
                            onSelect(template)
                            dismiss()
                        }
                    }
                }
                .padding(DS.Spacing.xl)
            }
        }
        .frame(width: 640, height: 480)
    }
}

private struct TemplateCard: View {
    let template: AgentTemplate
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: template.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DS.Colors.accent)
                        .frame(width: 36, height: 36)
                        .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name)
                            .font(DS.Font.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text(template.role)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }

                Text(template.description)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? DS.Colors.fillSecondary : DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(isHovered ? DS.Colors.borderHover : DS.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
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
                        .foregroundStyle(DS.Colors.accent)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(DS.Colors.accentFill, in: Capsule())
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background(isSelected ? DS.Colors.accentFill : (isHovered ? DS.Colors.fillSecondary : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
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
                            .foregroundStyle(icon == ic ? DS.Colors.onAccent : DS.Colors.textTertiary)
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
                    .foregroundStyle(DS.Colors.onAccent)
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
            .background(DS.Colors.surfaceElevated)

            Divider()

            // Inline fields
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: DS.IconSize.lg, weight: .medium))
                        .foregroundStyle(DS.Colors.accent)
                        .frame(width: 24)
                    TextField("Assistant name", text: $name)
                        .textFieldStyle(.plain)
                        .font(DS.Font.title)
                        .onChange(of: name) { scheduleSave() }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)

                TextField("Describe what this assistant helps with...", text: $role)
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
                    TextField("Topics this assistant knows about (comma-separated)", text: $knowledgeScope)
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
                placeholder: "Write instructions for how this assistant should behave...",
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
