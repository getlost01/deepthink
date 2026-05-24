import SwiftUI

struct AgentListView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("hint_assistants_dismissed") private var bannerDismissed = false
    @State private var selectedAgent: AgentFile?
    @State private var showDeleteConfirm = false
    @State private var showTemplates = false
    @State private var searchText = ""

    private var agentService: AgentFileService {
        AgentFileService.shared
    }

    private var filteredAgents: [AgentFile] {
        if searchText.isEmpty { return agentService.agents }
        let q = searchText.lowercased()
        return agentService.agents.filter {
            $0.name.lowercased().contains(q) || $0.role.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !bannerDismissed {
                DSSectionBanner(
                    icon: "person.2.circle",
                    title: "Assistants",
                    subtitle: "Custom AI personas with tailored knowledge and personality",
                    color: DS.Colors.purple,
                    onDismiss: { bannerDismissed = true }
                )
                Divider()
            }
            ResizableSplitView(minLeftWidth: 280, minRightWidth: 400) {
                VStack(spacing: 0) {
                    HStack(spacing: DS.Spacing.sm) {
                        DSSearchField(text: $searchText, placeholder: "Search assistants...")
                        DSAddButton {
                            createNewAgent()
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)

                    Divider()

                    if agentService.agents.isEmpty {
                        DSEmptyState(
                            icon: "person.2.circle",
                            title: "Create Your First Assistant",
                            subtitle: "Assistants are AI helpers tailored for specific tasks — like a writing coach, research buddy, or task planner.",
                            hint: "Try starting with a template, then customize it to fit your needs",
                            action: { showTemplates = true },
                            actionTitle: "Browse Templates"
                        )
                    } else if filteredAgents.isEmpty {
                        DSEmptyState(
                            icon: "magnifyingglass",
                            title: "No Results",
                            subtitle: "No assistants match \"\(searchText)\""
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredAgents) { agent in
                                    AgentRow(
                                        agent: agent,
                                        isSelected: selectedAgent?.id == agent.id,
                                        action: { selectedAgent = agent },
                                        onChat: {
                                            selectedAgent = agent
                                            appState.selectedAgentPath = agent.filePath.path
                                            appState.selectedSection = .aiAssistant
                                        },
                                        onDelete: {
                                            selectedAgent = agent
                                            showDeleteConfirm = true
                                        }
                                    )
                                    if agent.id != filteredAgents.last?.id {
                                        Divider()
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
                        subtitle: "Choose an assistant from the list to customize its personality, expertise, and what it knows about."
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
            name: "Research Deep-Dive",
            role: "Thorough research with knowledge base context",
            icon: "magnifyingglass.circle",
            description: "Searches your knowledge base, cross-references sources, and delivers structured findings with citations.",
            systemPrompt: """
            You are a research assistant with access to the user's knowledge base. When researching:
            1. Check existing knowledge entries first
            2. Cross-reference multiple sources
            3. Cite which entries informed your answer
            4. Flag gaps and suggest what to capture next
            5. Provide structured findings with clear sections
            """
        ),
        AgentTemplate(
            name: "Meeting Processor",
            role: "Turns raw meeting notes into structured output",
            icon: "person.2",
            description: "Takes messy meeting notes and extracts decisions, action items with owners, and follow-ups.",
            systemPrompt: """
            You are a meeting notes processor. When given meeting notes:
            1. Add a one-line summary at the top
            2. Extract key decisions in bold
            3. List action items as a checklist with owners
            4. Note unresolved questions separately
            5. Suggest follow-up items with suggested dates
            """
        ),
        AgentTemplate(
            name: "Learning Companion",
            role: "Helps you learn and retain new topics",
            icon: "brain",
            description: "Explains concepts at your level, creates flashcard-style summaries, and quizzes you on knowledge.",
            systemPrompt: """
            You are a learning companion. Help the user learn effectively:
            - Explain concepts starting from what they already know
            - Use analogies and concrete examples
            - Create concise summaries suitable for knowledge capture
            - Ask follow-up questions to test understanding
            - Suggest related topics to explore next
            """
        ),
        AgentTemplate(
            name: "Content Curator",
            role: "Captures and organizes information from any source",
            icon: "tray.and.arrow.down",
            description: "Takes raw content — articles, pastes, URLs — and turns them into clean, tagged knowledge entries.",
            systemPrompt: """
            You are a content curator for a personal knowledge base. When given raw content:
            1. Extract the key information worth keeping
            2. Rewrite into clean, scannable format with headings
            3. Suggest 3-5 specific tags
            4. Identify connections to topics the user might already have
            5. Note the source and capture date
            """
        ),
        AgentTemplate(
            name: "Weekly Reviewer",
            role: "Generates weekly reviews and planning",
            icon: "calendar",
            description: "Reviews your week's activity and helps plan the next one with priorities and goals.",
            systemPrompt: """
            You are a weekly review assistant. Help the user reflect and plan:
            1. Summarize what was accomplished this week
            2. Identify what's still in progress or blocked
            3. Review upcoming deadlines and commitments
            4. Suggest 3 priorities for next week
            5. Note any knowledge gaps or research needed
            """
        )
    ]
}

private struct AgentTemplateSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (AgentTemplate) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
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
                        .font(.system(size: DS.IconSize.md, weight: .medium))
                        .foregroundStyle(DS.Colors.accent)
                        .frame(width: 28, height: 28)
                        .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
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
    var onChat: (() -> Void)?
    var onDelete: (() -> Void)?
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                DSIconBadge(
                    icon: agent.icon,
                    color: isSelected ? DS.Colors.accent : DS.Colors.textTertiary,
                    background: isSelected ? DS.Colors.accentFill : DS.Colors.fill
                )

                HStack(spacing: DS.Spacing.xs) {
                    Text(agent.name)
                        .font(DS.Font.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(DS.Colors.textPrimary)
                    if agent.isBuiltIn {
                        Text("Built-in")
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Colors.textTertiary)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(DS.Colors.fill, in: Capsule())
                    }
                }

                Spacer()

                if agent.model != nil {
                    Text(agent.modelDisplayName)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.accent)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
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
        .contextMenu {
            if let onChat {
                Button { onChat() } label: { Label("Chat", systemImage: "bubble.left.fill") }
            }
            if !agent.isBuiltIn, let onDelete {
                Divider()
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
            }
        }
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
    @State private var showIconPicker = false
    @State private var filePath: URL?
    @State private var agentSkills: [String] = []
    @State private var isBuiltIn: Bool = false

    private let icons = [
        "person.circle", "magnifyingglass.circle", "chevron.left.forwardslash.chevron.right",
        "list.bullet.rectangle", "pencil.circle", "chart.bar.xaxis",
        "brain", "lightbulb", "wrench.and.screwdriver", "globe",
        "person.2", "star", "heart", "bolt", "leaf"
    ]

    var body: some View {
        VStack(spacing: 0) {
            editorToolbar
            Divider()
            editorFields
            Divider()

            MarkdownEditorWithToggle(
                text: $editablePrompt,
                placeholder: "Write instructions for how this assistant should behave...",
                onSave: { saveAgent() }
            )
            .id(agent.id)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadAgent() }
        .onChange(of: agent.id) {
            saveTask?.cancel()
            saveAgent()
            loadAgent()
        }
    }

    private var editorToolbar: some View {
        HStack(spacing: DS.Spacing.md) {
            Button(action: onChat) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: DS.IconSize.xs))
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
            .pickerStyle(.menu)
            .font(DS.Font.caption)
            .foregroundStyle(DS.Colors.textSecondary)
            .frame(width: 120)
            .pointerOnHover()

            if !agent.isBuiltIn {
                DSToolbarButton(icon: "trash", color: DS.Colors.danger, size: DS.IconSize.sm) {
                    onDelete()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.surfaceElevated)
    }

    private var editorFields: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Button {
                    showIconPicker.toggle()
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: DS.IconSize.md, weight: .medium))
                        .foregroundStyle(DS.Colors.accent)
                        .frame(width: 28, height: 28)
                        .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .strokeBorder(DS.Colors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plainPointer)
                .help("Change icon")
                .popover(isPresented: $showIconPicker, arrowEdge: .bottom) {
                    iconPickerPopover
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    TextField("Assistant name", text: $name)
                        .textFieldStyle(.plain)
                        .font(DS.Font.title)
                        .onChange(of: name) { scheduleSave() }
                    TextField("What does this assistant help with?", text: $role)
                        .textFieldStyle(.plain)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .onChange(of: role) { scheduleSave() }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)

            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "book")
                    .font(.system(size: DS.IconSize.xs))
                    .foregroundStyle(DS.Colors.textTertiary)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Knowledge")
                        .font(DS.Font.small)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Colors.textSecondary)
                    TextField("e.g. Swift, macOS, UI design", text: $knowledgeScope)
                        .textFieldStyle(.plain)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .onChange(of: knowledgeScope) { scheduleSave() }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
        }
    }

    private var iconPickerPopover: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: DS.Spacing.xs), count: 5), spacing: DS.Spacing.xs) {
            ForEach(icons, id: \.self) { ic in
                Button {
                    icon = ic
                    showIconPicker = false
                    scheduleSave()
                } label: {
                    Image(systemName: ic)
                        .font(.system(size: DS.IconSize.sm, weight: .medium))
                        .foregroundStyle(icon == ic ? DS.Colors.onAccent : DS.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(icon == ic ? DS.Colors.accent : DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plainPointer)
            }
        }
        .padding(DS.Spacing.md)
    }

    private func loadAgent() {
        name = agent.name
        role = agent.role
        icon = agent.icon
        model = agent.model
        knowledgeScope = agent.knowledgeScope.joined(separator: ", ")
        editablePrompt = agent.systemPrompt
        filePath = agent.filePath
        agentSkills = agent.skills
        isBuiltIn = agent.isBuiltIn
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
        guard hasLoaded, let fp = filePath else { return }
        let scope = knowledgeScope.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let updated = AgentFile(
            name: name, role: role, icon: icon, model: model,
            systemPrompt: editablePrompt, skills: agentSkills, knowledgeScope: scope,
            filePath: fp, isBuiltIn: isBuiltIn
        )
        AgentFileService.shared.save(agent: updated)
    }
}
