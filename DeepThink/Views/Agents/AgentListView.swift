import SwiftUI

struct AgentListView: View {
    @Environment(AppState.self) private var appState
    @State private var showEditor = false
    @State private var selectedAgent: AgentFile?

    private var agentService: AgentFileService { AgentFileService.shared }

    var body: some View {
        VStack(spacing: 0) {
            if agentService.agents.isEmpty {
                DSEmptyState(
                    icon: "person.2.circle",
                    title: "Create Your First Agent",
                    subtitle: "Agents are specialized AI personas — give them a role, pick which knowledge they can access, and chat with them in AI Bot. Try a Researcher, Code Reviewer, or Writer.",
                    action: { showEditor = true },
                    actionTitle: "Create Agent"
                )
            } else {
                HStack(spacing: DS.Spacing.md) {
                    DSStatChip(label: "Agents", value: "\(agentService.agents.count)", icon: "person.2.circle")
                    Spacer()
                    DSActionButton(title: "New Agent", icon: "plus") {
                        selectedAgent = nil
                        showEditor = true
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)

                Divider()

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: DS.Spacing.md)], spacing: DS.Spacing.md) {
                        ForEach(agentService.agents) { agent in
                            AgentCard(agent: agent) {
                                appState.selectedAgentPath = agent.filePath.path
                                appState.selectedSection = .ai
                            } onEdit: {
                                selectedAgent = agent
                                showEditor = true
                            } onDelete: {
                                agentService.delete(agent: agent)
                            }
                        }
                    }
                    .padding(DS.Spacing.lg)
                }
            }
        }
        .onAppear { agentService.reload() }
        .sheet(isPresented: $showEditor) {
            AgentEditorView(agent: selectedAgent)
        }
    }
}

// MARK: - Agent Card

private struct AgentCard: View {
    let agent: AgentFile
    let onChat: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DS.Colors.accentFill)
                        .frame(width: 36, height: 36)
                    Image(systemName: agent.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DS.Colors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(DS.Font.body)
                        .fontWeight(.semibold)

                    Text(agent.role)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    if agent.isBuiltIn {
                        DSPill(text: "Built-in", color: DS.Colors.textTertiary)
                    }
                    if let _ = agent.model {
                        DSPill(text: agent.modelDisplayName, color: .blue)
                    }
                }
            }
            .padding(DS.Spacing.md)

            // Info chips
            if !agent.skills.isEmpty || !agent.knowledgeScope.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    if !agent.skills.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                            Text("\(agent.skills.count) skills")
                        }
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }

                    if !agent.knowledgeScope.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "book")
                                .font(.system(size: 8))
                            Text(agent.knowledgeScope.joined(separator: ", "))
                        }
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)
            }

            Divider()

            // Actions
            HStack(spacing: DS.Spacing.sm) {
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

                Spacer()

                DSToolbarButton(icon: "pencil", size: DS.IconSize.sm) { onEdit() }
                if !agent.isBuiltIn {
                    DSToolbarButton(icon: "trash", color: DS.Colors.danger, size: DS.IconSize.sm) { onDelete() }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(isHovered ? DS.Colors.fillSecondary : DS.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(isHovered ? DS.Colors.borderHover : DS.Colors.border, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Agent Editor

struct AgentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let agent: AgentFile?

    @State private var name = ""
    @State private var role = ""
    @State private var icon = "person.circle"
    @State private var model: String?
    @State private var systemPrompt = ""
    @State private var knowledgeScope = ""

    private let icons = [
        "person.circle", "magnifyingglass.circle", "chevron.left.forwardslash.chevron.right",
        "list.bullet.rectangle", "pencil.circle", "chart.bar.xaxis",
        "brain", "lightbulb", "wrench.and.screwdriver", "globe",
        "shield.checkered", "doc.text.magnifyingglass"
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DS.Colors.accentFill)
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.Colors.accent)
                }

                Text(agent == nil ? "New Agent" : "Edit Agent")
                    .font(DS.Font.heading)
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(DS.Font.body).buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.textSecondary)
                Button(action: save) {
                    Text("Save")
                        .font(DS.Font.body).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(name.isEmpty ? DS.Colors.accent.opacity(0.5) : DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plainPointer)
                .disabled(name.isEmpty)
            }
            .padding(DS.Spacing.lg)
            .background(.bar)

            Divider()

            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    DSCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                            HStack(spacing: DS.Spacing.lg) {
                                DSLabeledTextField(label: "Name", text: $name, placeholder: "e.g. Research Assistant")
                                    .frame(maxWidth: .infinity)

                                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                    Text("MODEL")
                                        .font(DS.Font.small)
                                        .foregroundStyle(DS.Colors.textTertiary)
                                    Picker("", selection: Binding(
                                        get: { model ?? "default" },
                                        set: { model = $0 == "default" ? nil : $0 }
                                    )) {
                                        Text("Default").tag("default")
                                        Text("Haiku").tag("claude-haiku-4-5-20251001")
                                        Text("Sonnet").tag("claude-sonnet-4-6")
                                        Text("Opus").tag("claude-opus-4-6")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 220)
                                }
                            }

                            DSLabeledTextField(label: "Role", text: $role, placeholder: "Short description of what this agent does")

                            // Icon picker
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                Text("ICON")
                                    .font(DS.Font.small)
                                    .foregroundStyle(DS.Colors.textTertiary)
                                HStack(spacing: DS.Spacing.xs) {
                                    ForEach(icons, id: \.self) { ic in
                                        Button {
                                            icon = ic
                                        } label: {
                                            Image(systemName: ic)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(icon == ic ? .white : DS.Colors.textSecondary)
                                                .frame(width: 28, height: 28)
                                                .background(icon == ic ? DS.Colors.accent : DS.Colors.fill, in: Circle())
                                        }
                                        .buttonStyle(.plainPointer)
                                    }
                                }
                            }
                        }
                    }

                    DSCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                            DSSectionHeader(title: "System Prompt")
                            DSLabeledTextEditor(label: "Instructions for this agent", text: $systemPrompt, minHeight: 180)
                        }
                    }

                    DSCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                            DSSectionHeader(title: "Knowledge Scope")
                            DSLabeledTextField(label: "Scope tags (comma-separated)", text: $knowledgeScope, placeholder: "web, code, analytics")

                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "info.circle").font(.system(size: 10))
                                Text("Agent sees knowledge entries matching these source types or tags")
                                    .font(DS.Font.caption)
                            }
                            .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }

                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "doc.text").font(.system(size: 10))
                        Text("Saved as .md in ~/Documents/DeepThink/configs/agents/")
                            .font(DS.Font.caption)
                    }
                    .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(DS.Spacing.xl)
            }
        }
        .frame(width: 620, height: 680)
        .onAppear {
            if let agent {
                name = agent.name
                role = agent.role
                icon = agent.icon
                model = agent.model
                systemPrompt = agent.systemPrompt
                knowledgeScope = agent.knowledgeScope.joined(separator: ", ")
            }
        }
    }

    private func save() {
        let scope = knowledgeScope.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        if let agent {
            let updated = AgentFile(
                name: name, role: role, icon: icon, model: model,
                systemPrompt: systemPrompt, skills: agent.skills, knowledgeScope: scope,
                filePath: agent.filePath, isBuiltIn: agent.isBuiltIn
            )
            AgentFileService.shared.save(agent: updated)
        } else {
            AgentFileService.shared.create(name: name, role: role, icon: icon, model: model, systemPrompt: systemPrompt, knowledgeScope: scope)
        }
        dismiss()
    }
}
