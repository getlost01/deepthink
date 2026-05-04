import SwiftUI

struct SkillsRulesView: View {
    @State private var mode: SRMode = .skills
    @State private var selectedSkill: SkillFile?
    @State private var selectedRule: RuleFile?
    @State private var showRunSheet = false
    @State private var skillToRun: SkillFile?
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: String = ""

    private var skillService: SkillFileService { SkillFileService.shared }
    private var ruleService: RuleFileService { RuleFileService.shared }

    enum SRMode: String, CaseIterable {
        case skills = "Skills"
        case rules = "Rules"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                HStack(spacing: 0) {
                    ForEach(SRMode.allCases, id: \.self) { m in
                        Button {
                            withAnimation(DS.Animation.quick) { mode = m }
                        } label: {
                            Text(m.rawValue)
                                .font(DS.Font.small)
                                .fontWeight(mode == m ? .semibold : .regular)
                                .foregroundStyle(mode == m ? DS.Colors.onAccent : DS.Colors.textSecondary)
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.vertical, DS.Spacing.sm)
                                .background(mode == m ? DS.Colors.accent : .clear, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
                .padding(2)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)

            Divider()

            if mode == .skills {
                skillsSplit
            } else {
                rulesSplit
            }
        }
        .onAppear {
            skillService.reload()
            ruleService.reload()
        }
        .sheet(isPresented: $showRunSheet) {
            if let skill = skillToRun {
                SkillRunSheet(skill: skill)
            }
        }
        .confirmationDialog("Delete \"\(deleteTarget)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if mode == .skills, let skill = selectedSkill {
                    skillService.delete(skill: skill)
                    selectedSkill = nil
                } else if mode == .rules, let rule = selectedRule {
                    ruleService.delete(rule: rule)
                    selectedRule = nil
                }
            }
        } message: {
            Text("This will permanently delete this \(mode == .skills ? "skill" : "rule").")
        }
    }

    // MARK: - Skills Split

    @ViewBuilder
    private var skillsSplit: some View {
        ResizableSplitView(minLeftWidth: 260, minRightWidth: 380) {
            VStack(spacing: 0) {
                HStack {
                    Text("\(skillService.skills.count) skills")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                    Spacer()
                    Button {
                        createNewSkill()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: DS.IconSize.sm, weight: .medium))
                            .foregroundStyle(DS.Colors.accent)
                    }
                    .buttonStyle(.plainPointer)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)

                Divider()

                if skillService.skills.isEmpty {
                    DSEmptyState(
                        icon: "sparkles",
                        title: "No Skills Yet",
                        subtitle: "Skills are reusable AI actions — like saved prompts you can run anytime with one click.",
                        hint: "Example: \"Summarize this text\", \"Write a thank-you email\", \"Extract key points\"",
                        action: { createNewSkill() },
                        actionTitle: "Create Skill"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(skillService.skills) { skill in
                                SkillRow(skill: skill, isSelected: selectedSkill?.id == skill.id) {
                                    selectedSkill = skill
                                }
                                if skill.id != skillService.skills.last?.id {
                                    Divider().padding(.leading, 48)
                                }
                            }
                        }
                    }
                }
            }
        } right: {
            if let skill = selectedSkill {
                SkillInlineEditor(skill: skill) {
                    skillToRun = skill
                    showRunSheet = true
                } onDelete: {
                    deleteTarget = skill.name
                    showDeleteConfirm = true
                }
            } else {
                DSEmptyState(
                    icon: "sparkles",
                    title: "Select a Skill",
                    subtitle: "Pick a skill from the list to customize what it does. Changes save automatically."
                )
            }
        }
    }

    // MARK: - Rules Split

    @ViewBuilder
    private var rulesSplit: some View {
        ResizableSplitView(minLeftWidth: 260, minRightWidth: 380) {
            VStack(spacing: 0) {
                HStack {
                    Text("\(ruleService.rules.count) rules")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                    Spacer()
                    Button {
                        createNewRule()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: DS.IconSize.sm, weight: .medium))
                            .foregroundStyle(DS.Colors.accent)
                    }
                    .buttonStyle(.plainPointer)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)

                Divider()

                if ruleService.rules.isEmpty {
                    DSEmptyState(
                        icon: "bolt",
                        title: "No Rules Yet",
                        subtitle: "Rules are automatic instructions for AI — they kick in when certain conditions are met, so you don't have to repeat yourself.",
                        hint: "Example: \"Always use bullet points\" or \"Keep replies under 200 words\"",
                        action: { createNewRule() },
                        actionTitle: "Create Rule"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(ruleService.rules) { rule in
                                RuleRow(rule: rule, isSelected: selectedRule?.id == rule.id) {
                                    selectedRule = rule
                                }
                                if rule.id != ruleService.rules.last?.id {
                                    Divider().padding(.leading, 48)
                                }
                            }
                        }
                    }
                }
            }
        } right: {
            if let rule = selectedRule {
                RuleInlineEditor(rule: rule) {
                    deleteTarget = rule.name
                    showDeleteConfirm = true
                }
            } else {
                DSEmptyState(
                    icon: "bolt",
                    title: "Select a Rule",
                    subtitle: "Pick a rule from the list to edit when it activates and what it tells AI to do. Changes save automatically."
                )
            }
        }
    }

    private func createNewSkill() {
        let countBefore = skillService.skills.count
        SkillFileService.shared.create(
            name: "New Skill",
            category: "General",
            icon: "sparkles",
            systemPrompt: "",
            promptTemplate: "{{input}}"
        )
        if skillService.skills.count > countBefore {
            selectedSkill = skillService.skills.last
        }
    }

    private func createNewRule() {
        let countBefore = ruleService.rules.count
        RuleFileService.shared.create(
            name: "New Rule",
            trigger: "always",
            icon: "bolt",
            category: "General",
            instruction: ""
        )
        if ruleService.rules.count > countBefore {
            selectedRule = ruleService.rules.last
        }
    }
}

// MARK: - Skill Row

private struct SkillRow: View {
    let skill: SkillFile
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(isSelected ? DS.Colors.accent.opacity(0.15) : DS.Colors.accentFill)
                        .frame(width: 28, height: 28)
                    Image(systemName: skill.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(DS.Font.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)
                    Text(skill.category)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Spacer()

                if skill.isBuiltIn {
                    Text("Built-in")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(DS.Colors.fill, in: Capsule())
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

// MARK: - Rule Row

private struct RuleRow: View {
    let rule: RuleFile
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(isSelected ? DS.Colors.accent.opacity(0.15) : DS.Colors.accentFill)
                        .frame(width: 28, height: 28)
                    Image(systemName: rule.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.name)
                        .font(DS.Font.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: DS.Spacing.xs) {
                        DSPill(text: rule.trigger, color: DS.Colors.info)
                        Text(rule.category)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }

                Spacer()
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

// MARK: - Skill Inline Editor

private struct SkillInlineEditor: View {
    let skill: SkillFile
    let onRun: () -> Void
    let onDelete: () -> Void

    @State private var name: String = ""
    @State private var category: String = ""
    @State private var systemPrompt: String = ""
    @State private var promptTemplate: String = ""
    @State private var hasLoaded = false
    @State private var saveTask: Task<Void, Never>?

    private let categories = ["General", "Writing", "Productivity", "Development", "Communication", "Organization", "Analysis"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: skill.icon)
                    .font(.system(size: DS.IconSize.md))
                    .foregroundStyle(DS.Colors.accent)

                TextField("Skill name", text: $name)
                    .textFieldStyle(.plain)
                    .font(DS.Font.heading)
                    .onChange(of: name) { scheduleSave() }

                Spacer()

                Picker("", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
                .onChange(of: category) { scheduleSave() }

                Text("/\(skill.commandName)")
                    .font(DS.Font.mono)
                    .foregroundStyle(DS.Colors.textTertiary)

                DSToolbarButton(
                    icon: skill.isPinned ? "pin.fill" : "pin",
                    color: skill.isPinned ? DS.Colors.warning : DS.Colors.textSecondary,
                    size: DS.IconSize.sm
                ) {
                    SkillFileService.shared.togglePin(skill: skill)
                }
                .help(skill.isPinned ? "Unpin from sidebar" : "Pin to sidebar")

                Button(action: onRun) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                        Text("Run")
                            .font(DS.Font.small)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(DS.Colors.onAccent)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs + 2)
                    .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plainPointer)

                if !skill.isBuiltIn {
                    DSToolbarButton(icon: "trash", color: DS.Colors.danger, size: DS.IconSize.sm) {
                        onDelete()
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surfaceElevated)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                Text("BACKGROUND INSTRUCTIONS")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.xs)

                TextEditor(text: $systemPrompt)
                    .font(DS.Font.monoSmall)
                    .scrollContentBackground(.hidden)
                    .frame(height: 80)
                    .padding(.horizontal, DS.Spacing.md)
                    .onChange(of: systemPrompt) { scheduleSave() }

                Divider().padding(.horizontal, DS.Spacing.lg)

                Text("WHAT TO DO")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.xs)

                MarkdownEditorWithToggle(
                    text: $promptTemplate,
                    placeholder: "Use {{input}} for template variables...",
                    onSave: { saveSkill() },
                    autoSaveInterval: 10
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadSkill() }
        .onChange(of: skill.id) { loadSkill() }
    }

    private func loadSkill() {
        name = skill.name
        category = skill.category
        systemPrompt = skill.systemPrompt
        promptTemplate = skill.promptTemplate
        hasLoaded = true
    }

    private func scheduleSave() {
        guard hasLoaded else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await MainActor.run { saveSkill() }
        }
    }

    private func saveSkill() {
        guard hasLoaded else { return }
        let updated = SkillFile(
            name: name, trigger: skill.trigger, icon: skill.icon, model: skill.model,
            category: category, systemPrompt: systemPrompt, promptTemplate: promptTemplate,
            filePath: skill.filePath, isBuiltIn: skill.isBuiltIn, isPinned: skill.isPinned
        )
        SkillFileService.shared.save(skill: updated)
    }
}

// MARK: - Rule Inline Editor

private struct RuleInlineEditor: View {
    let rule: RuleFile
    let onDelete: () -> Void

    @State private var name: String = ""
    @State private var trigger: String = ""
    @State private var category: String = ""
    @State private var instruction: String = ""
    @State private var hasLoaded = false
    @State private var saveTask: Task<Void, Never>?

    private let categories = ["General", "Productivity", "Development", "Writing", "Communication"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: rule.icon)
                    .font(.system(size: DS.IconSize.md))
                    .foregroundStyle(DS.Colors.accent)

                TextField("Rule name", text: $name)
                    .textFieldStyle(.plain)
                    .font(DS.Font.heading)
                    .onChange(of: name) { scheduleSave() }

                Spacer()

                Picker("", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
                .onChange(of: category) { scheduleSave() }

                if !rule.isBuiltIn {
                    DSToolbarButton(icon: "trash", color: DS.Colors.danger, size: DS.IconSize.sm) {
                        onDelete()
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surfaceElevated)

            Divider()

            HStack(spacing: DS.Spacing.md) {
                Text("WHEN TO ACTIVATE")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                TextField("always, note.tagged.meeting, task.created", text: $trigger)
                    .textFieldStyle(.plain)
                    .font(DS.Font.mono)
                    .onChange(of: trigger) { scheduleSave() }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)

            Divider()

            MarkdownEditorWithToggle(
                text: $instruction,
                placeholder: "Write the instruction for Claude when this rule triggers...",
                onSave: { saveRule() },
                autoSaveInterval: 10
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadRule() }
        .onChange(of: rule.id) { loadRule() }
    }

    private func loadRule() {
        name = rule.name
        trigger = rule.trigger
        category = rule.category
        instruction = rule.instruction
        hasLoaded = true
    }

    private func scheduleSave() {
        guard hasLoaded else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await MainActor.run { saveRule() }
        }
    }

    private func saveRule() {
        guard hasLoaded else { return }
        let updated = RuleFile(
            name: name, trigger: trigger, icon: rule.icon, category: category,
            instruction: instruction, filePath: rule.filePath, isBuiltIn: rule.isBuiltIn
        )
        RuleFileService.shared.save(rule: updated)
    }
}

// MARK: - Skill Run Sheet

struct SkillRunSheet: View {
    @Environment(\.dismiss) private var dismiss
    let skill: SkillFile

    @State private var input = ""
    @State private var result: String?
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: skill.icon)
                    .foregroundStyle(DS.Colors.accent)
                Text("Run: \(skill.name)")
                    .font(DS.Font.heading)
                Spacer()
                Button("Close") { dismiss() }
                    .font(DS.Font.body).buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surfaceElevated)

            Divider()

            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    DSLabeledTextEditor(label: "Input", text: $input, minHeight: 100)

                    Button {
                        Task { await run() }
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            if isRunning { ProgressView().controlSize(.small).tint(DS.Colors.onAccent) }
                            Text(isRunning ? "Running..." : "Run")
                                .font(DS.Font.body).fontWeight(.semibold)
                        }
                        .foregroundStyle(DS.Colors.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plainPointer)
                    .disabled(isRunning || input.isEmpty)

                    if let result {
                        DSCard {
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                Text("Result")
                                    .font(DS.Font.heading)
                                Text(result)
                                    .font(DS.Font.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(DS.Spacing.xl)
            }
        }
        .frame(width: 520, height: 520)
    }

    @MainActor
    private func run() async {
        isRunning = true
        result = await SkillFileService.shared.execute(skill: skill, context: ["input": input])
        isRunning = false
    }
}
