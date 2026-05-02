import SwiftUI

struct SkillsRulesView: View {
    @State private var mode: SRMode = .skills
    @State private var showSkillEditor = false
    @State private var showRuleEditor = false
    @State private var selectedSkill: SkillFile?
    @State private var selectedRule: RuleFile?
    @State private var showRunSheet = false
    @State private var skillToRun: SkillFile?

    private var skillService: SkillFileService { SkillFileService.shared }
    private var ruleService: RuleFileService { RuleFileService.shared }

    enum SRMode: String, CaseIterable {
        case skills = "Skills"
        case rules = "Rules"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented control + actions
            HStack(spacing: DS.Spacing.md) {
                HStack(spacing: 0) {
                    ForEach(SRMode.allCases, id: \.self) { m in
                        Button {
                            withAnimation(DS.Animation.quick) { mode = m }
                        } label: {
                            Text(m.rawValue)
                                .font(DS.Font.small)
                                .fontWeight(mode == m ? .semibold : .regular)
                                .foregroundStyle(mode == m ? .white : DS.Colors.textSecondary)
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

                if mode == .skills {
                    DSActionButton(title: "New Skill", icon: "plus") {
                        selectedSkill = nil
                        showSkillEditor = true
                    }
                } else {
                    DSActionButton(title: "New Rule", icon: "plus") {
                        selectedRule = nil
                        showRuleEditor = true
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)

            Divider()

            if mode == .skills {
                skillsList
            } else {
                rulesList
            }
        }
        .onAppear {
            skillService.reload()
            ruleService.reload()
        }
        .sheet(isPresented: $showSkillEditor) {
            SkillFileEditorView(skill: selectedSkill)
        }
        .sheet(isPresented: $showRuleEditor) {
            RuleFileEditorView(rule: selectedRule)
        }
        .sheet(isPresented: $showRunSheet) {
            if let skill = skillToRun {
                SkillRunSheet(skill: skill)
            }
        }
    }

    // MARK: - Skills List

    @ViewBuilder
    private var skillsList: some View {
        if skillService.skills.isEmpty {
            DSEmptyState(
                icon: "sparkles",
                title: "No Skills",
                subtitle: "Skills are markdown prompt templates that enhance Claude.",
                action: { showSkillEditor = true },
                actionTitle: "Create Skill"
            )
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: DS.Spacing.md)], spacing: DS.Spacing.md) {
                    ForEach(skillService.skills) { skill in
                        SkillCard(skill: skill) {
                            skillToRun = skill
                            showRunSheet = true
                        } onEdit: {
                            selectedSkill = skill
                            showSkillEditor = true
                        } onDelete: {
                            skillService.delete(skill: skill)
                        }
                    }
                }
                .padding(DS.Spacing.lg)
            }
        }
    }

    // MARK: - Rules List

    @ViewBuilder
    private var rulesList: some View {
        if ruleService.rules.isEmpty {
            DSEmptyState(
                icon: "bolt",
                title: "No Rules",
                subtitle: "Rules are markdown instruction files that guide Claude's behavior.",
                action: { showRuleEditor = true },
                actionTitle: "Create Rule"
            )
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(ruleService.rules) { rule in
                        RuleRow(rule: rule) {
                            selectedRule = rule
                            showRuleEditor = true
                        } onDelete: {
                            ruleService.delete(rule: rule)
                        }

                        if rule.id != ruleService.rules.last?.id {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .dsCard(padding: 0)
                .padding(DS.Spacing.lg)
            }
        }
    }
}

// MARK: - Skill Card

private struct SkillCard: View {
    let skill: SkillFile
    let onRun: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onRun) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: DS.Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(DS.Colors.accentFill)
                            .frame(width: 30, height: 30)
                        Image(systemName: skill.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.Colors.accent)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(skill.name)
                            .font(DS.Font.body)
                            .fontWeight(.medium)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: DS.Spacing.xs) {
                            Text(skill.category)
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.textTertiary)
                            if skill.isBuiltIn {
                                Text("Built-in")
                                    .font(DS.Font.small)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                        }
                    }

                    Spacer()

                    if !skill.isBuiltIn {
                        HStack(spacing: 2) {
                            DSToolbarButton(icon: "pencil", size: DS.IconSize.sm) { onEdit() }
                            DSToolbarButton(icon: "trash", color: DS.Colors.danger, size: DS.IconSize.sm) { onDelete() }
                        }
                    }
                }
                .padding(DS.Spacing.md)

                Divider()

                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "play.fill").font(.system(size: 8))
                    Text("Run").font(DS.Font.small)
                    Spacer()
                    Text(skill.filename).font(DS.Font.monoSmall)
                }
                .foregroundStyle(DS.Colors.textTertiary)
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
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DS.Colors.accentFill)
                    .frame(width: 30, height: 30)
                Image(systemName: rule.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.Colors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(DS.Font.body)
                    .fontWeight(.medium)

                HStack(spacing: DS.Spacing.sm) {
                    DSPill(text: rule.trigger, color: .blue)
                    Text(rule.category)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }

            Spacer()

            Text(rule.filename)
                .font(DS.Font.monoSmall)
                .foregroundStyle(DS.Colors.textTertiary)

            HStack(spacing: 2) {
                DSToolbarButton(icon: "pencil", size: DS.IconSize.sm) { onEdit() }
                if !rule.isBuiltIn {
                    DSToolbarButton(icon: "trash", color: DS.Colors.danger, size: DS.IconSize.sm) { onDelete() }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm + 2)
        .background(isHovered ? DS.Colors.fillSecondary : .clear)
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .onHover { isHovered = $0 }
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
            .background(.bar)

            Divider()

            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    DSLabeledTextEditor(label: "Input", text: $input, minHeight: 100)

                    Button {
                        Task { await run() }
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            if isRunning { ProgressView().controlSize(.small).tint(.white) }
                            Text(isRunning ? "Running..." : "Run")
                                .font(DS.Font.body).fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
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

// MARK: - Skill Editor

struct SkillFileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let skill: SkillFile?

    @State private var name = ""
    @State private var icon = "sparkles"
    @State private var category = "General"
    @State private var systemPrompt = ""
    @State private var promptTemplate = ""
    @State private var trigger = "manual"
    @State private var model: String?

    private let categories = ["General", "Writing", "Productivity", "Development", "Communication", "Organization", "Analysis"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(skill == nil ? "New Skill" : "Edit Skill")
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
                VStack(spacing: DS.Spacing.lg) {
                    HStack(spacing: DS.Spacing.lg) {
                        DSLabeledTextField(label: "Name", text: $name, placeholder: "Skill name")
                        DSLabeledPicker(label: "Category", selection: $category) {
                            ForEach(categories, id: \.self) { Text($0) }
                        }
                        .frame(width: 150)
                    }

                    DSLabeledTextEditor(label: "System Prompt", text: $systemPrompt, minHeight: 60)
                    DSLabeledTextEditor(label: "Prompt Template (use {{input}})", text: $promptTemplate, minHeight: 120)

                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "info.circle").font(.system(size: 10))
                        Text("Saved as .md file in ~/Documents/DeepThink/configs/skills/")
                            .font(DS.Font.caption)
                    }
                    .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(DS.Spacing.xl)
            }
        }
        .frame(width: 580, height: 520)
        .onAppear {
            if let skill {
                name = skill.name
                icon = skill.icon
                category = skill.category
                systemPrompt = skill.systemPrompt
                promptTemplate = skill.promptTemplate
                trigger = skill.trigger
                model = skill.model
            }
        }
    }

    private func save() {
        if let skill {
            let updated = SkillFile(
                name: name, trigger: trigger, icon: icon, model: model,
                category: category, systemPrompt: systemPrompt, promptTemplate: promptTemplate,
                filePath: skill.filePath, isBuiltIn: skill.isBuiltIn
            )
            SkillFileService.shared.save(skill: updated)
        } else {
            SkillFileService.shared.create(name: name, category: category, icon: icon, systemPrompt: systemPrompt, promptTemplate: promptTemplate, trigger: trigger, model: model)
        }
        dismiss()
    }
}

// MARK: - Rule Editor

struct RuleFileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let rule: RuleFile?

    @State private var name = ""
    @State private var trigger = "always"
    @State private var icon = "bolt"
    @State private var category = "General"
    @State private var instruction = ""

    private let categories = ["General", "Productivity", "Development", "Writing", "Communication"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(rule == nil ? "New Rule" : "Edit Rule")
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
                VStack(spacing: DS.Spacing.lg) {
                    HStack(spacing: DS.Spacing.lg) {
                        DSLabeledTextField(label: "Name", text: $name, placeholder: "Rule name")
                        DSLabeledPicker(label: "Category", selection: $category) {
                            ForEach(categories, id: \.self) { Text($0) }
                        }
                        .frame(width: 150)
                    }

                    DSLabeledTextField(label: "Trigger", text: $trigger, placeholder: "always, note.tagged.meeting, task.created")

                    DSLabeledTextEditor(label: "Instruction (what should Claude do?)", text: $instruction, minHeight: 180)

                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "info.circle").font(.system(size: 10))
                        Text("Saved as .md file in ~/Documents/DeepThink/configs/rules/")
                            .font(DS.Font.caption)
                    }
                    .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(DS.Spacing.xl)
            }
        }
        .frame(width: 550, height: 480)
        .onAppear {
            if let rule {
                name = rule.name
                trigger = rule.trigger
                icon = rule.icon
                category = rule.category
                instruction = rule.instruction
            }
        }
    }

    private func save() {
        if let rule {
            let updated = RuleFile(name: name, trigger: trigger, icon: icon, category: category, instruction: instruction, filePath: rule.filePath, isBuiltIn: rule.isBuiltIn)
            RuleFileService.shared.save(rule: updated)
        } else {
            RuleFileService.shared.create(name: name, trigger: trigger, icon: icon, category: category, instruction: instruction)
        }
        dismiss()
    }
}
