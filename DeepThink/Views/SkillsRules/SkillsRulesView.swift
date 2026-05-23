import SwiftUI

// MARK: - Skills List View

struct SkillsListView: View {
    @State private var selectedSkill: SkillFile?
    @State private var skillToRun: SkillFile?
    @State private var showDeleteConfirm = false
    @State private var searchText = ""

    private var skillService: SkillFileService {
        SkillFileService.shared
    }

    private var filteredSkills: [SkillFile] {
        if searchText.isEmpty { return skillService.skills }
        let q = searchText.lowercased()
        return skillService.skills.filter {
            $0.name.lowercased().contains(q) || $0.category.lowercased().contains(q)
        }
    }

    var body: some View {
        ResizableSplitView(minLeftWidth: 260, minRightWidth: 380) {
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.sm) {
                    DSSearchField(text: $searchText, placeholder: "Search skills...")
                    DSAddButton {
                        createNewSkill()
                    }
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
                } else if filteredSkills.isEmpty {
                    DSEmptyState(
                        icon: "magnifyingglass",
                        title: "No Results",
                        subtitle: "No skills match \"\(searchText)\""
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredSkills) { skill in
                                SkillRow(
                                    skill: skill,
                                    isSelected: selectedSkill?.id == skill.id,
                                    action: { selectedSkill = skill },
                                    onRun: { skillToRun = skill },
                                    onDelete: {
                                        selectedSkill = skill
                                        showDeleteConfirm = true
                                    }
                                )
                                if skill.id != filteredSkills.last?.id {
                                    Divider()
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
                } onDelete: {
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
        .onAppear { skillService.reload() }
        .sheet(item: $skillToRun) { skill in
            SkillRunSheet(skill: skill)
        }
        .confirmationDialog("Delete Skill?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let skill = selectedSkill {
                    skillService.delete(skill: skill)
                    selectedSkill = nil
                }
            }
        } message: {
            Text("This will permanently delete \"\(selectedSkill?.name ?? "")\".")
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
}

// MARK: - Rules List View

struct RulesListView: View {
    @State private var selectedRule: RuleFile?
    @State private var showDeleteConfirm = false
    @State private var searchText = ""

    private var ruleService: RuleFileService {
        RuleFileService.shared
    }

    private var filteredRules: [RuleFile] {
        if searchText.isEmpty { return ruleService.rules }
        let q = searchText.lowercased()
        return ruleService.rules.filter {
            $0.name.lowercased().contains(q) || $0.trigger.lowercased().contains(q) || $0.category.lowercased().contains(q)
        }
    }

    var body: some View {
        ResizableSplitView(minLeftWidth: 260, minRightWidth: 380) {
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.sm) {
                    DSSearchField(text: $searchText, placeholder: "Search rules...")
                    DSAddButton {
                        createNewRule()
                    }
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
                } else if filteredRules.isEmpty {
                    DSEmptyState(
                        icon: "magnifyingglass",
                        title: "No Results",
                        subtitle: "No rules match \"\(searchText)\""
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredRules) { rule in
                                RuleRow(
                                    rule: rule,
                                    isSelected: selectedRule?.id == rule.id,
                                    action: { selectedRule = rule },
                                    onDelete: {
                                        selectedRule = rule
                                        showDeleteConfirm = true
                                    }
                                )
                                if rule.id != filteredRules.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
        } right: {
            if let rule = selectedRule {
                RuleInlineEditor(rule: rule) {
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
        .onAppear { ruleService.reload() }
        .confirmationDialog("Delete Rule?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let rule = selectedRule {
                    ruleService.delete(rule: rule)
                    selectedRule = nil
                }
            }
        } message: {
            Text("This will permanently delete \"\(selectedRule?.name ?? "")\".")
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
    var onRun: (() -> Void)?
    var onDelete: (() -> Void)?
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                DSIconBadge(
                    icon: skill.icon,
                    color: isSelected ? DS.Colors.accent : DS.Colors.textTertiary,
                    background: isSelected ? DS.Colors.accentFill : DS.Colors.fill
                )

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
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
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
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
        .contextMenu {
            if let onRun {
                Button { onRun() } label: { Label("Run", systemImage: "play.fill") }
            }
            Button {
                SkillFileService.shared.create(
                    name: "\(skill.name) Copy", category: skill.category,
                    icon: skill.icon, systemPrompt: skill.systemPrompt,
                    promptTemplate: skill.promptTemplate
                )
            } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            if !skill.isBuiltIn, let onDelete {
                Divider()
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }
}

// MARK: - Rule Row

private struct RuleRow: View {
    let rule: RuleFile
    let isSelected: Bool
    let action: () -> Void
    var onDelete: (() -> Void)?
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                DSIconBadge(
                    icon: rule.icon,
                    color: isSelected ? DS.Colors.accent : DS.Colors.textTertiary,
                    background: isSelected ? DS.Colors.accentFill : DS.Colors.fill
                )

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(rule.name)
                        .font(DS.Font.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(rule.isDisabled ? DS.Colors.textTertiary : DS.Colors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: DS.Spacing.xs) {
                        DSPill(text: rule.trigger, color: rule.isDisabled ? DS.Colors.textTertiary : DS.Colors.info)
                            .lineLimit(1)
                        Text(rule.category)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                            .lineLimit(1)
                    }
                    .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { !rule.isDisabled },
                    set: { newValue in
                        let updated = RuleFile(
                            name: rule.name, trigger: rule.trigger, icon: rule.icon,
                            category: rule.category, instruction: rule.instruction,
                            filePath: rule.filePath, isBuiltIn: rule.isBuiltIn,
                            isDisabled: !newValue
                        )
                        RuleFileService.shared.save(rule: updated)
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .pointerOnHover()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + 2)
            .opacity(rule.isDisabled ? 0.6 : 1.0)
            .background(isSelected ? DS.Colors.accentFill : (isHovered ? DS.Colors.fillSecondary : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
        .contextMenu {
            Button {
                let updated = RuleFile(
                    name: rule.name, trigger: rule.trigger, icon: rule.icon,
                    category: rule.category, instruction: rule.instruction,
                    filePath: rule.filePath, isBuiltIn: rule.isBuiltIn,
                    isDisabled: !rule.isDisabled
                )
                RuleFileService.shared.save(rule: updated)
            } label: {
                Label(rule.isDisabled ? "Enable" : "Disable", systemImage: rule.isDisabled ? "checkmark.circle" : "pause.circle")
            }
            if !rule.isBuiltIn, let onDelete {
                Divider()
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }
}

// MARK: - Skill Inline Editor

private struct SkillInlineEditor: View {
    let skill: SkillFile
    let onRun: () -> Void
    let onDelete: () -> Void

    @State private var name: String = ""
    @State private var icon: String = ""
    @State private var category: String = ""
    @State private var systemPrompt: String = ""
    @State private var promptTemplate: String = ""
    @State private var command: String = ""
    @State private var hasLoaded = false
    @State private var saveTask: Task<Void, Never>?
    @State private var showIconPicker = false
    @State private var duplicated = false

    private let categories = [
        "General",
        "Writing",
        "Productivity",
        "Development",
        "Communication",
        "Organization",
        "Analysis",
        "Knowledge",
        "Research",
        "Finance",
        "Design",
        "Data"
    ]

    private let icons = [
        "sparkles", "wand.and.stars", "text.bubble", "doc.text",
        "pencil.circle", "magnifyingglass.circle", "list.bullet.rectangle",
        "chart.bar.xaxis", "brain", "lightbulb", "globe",
        "envelope", "paperplane", "bookmark", "tag"
    ]

    var body: some View {
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
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plainPointer)
                .popover(isPresented: $showIconPicker, arrowEdge: .bottom) {
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

                TextField("Skill name", text: $name)
                    .textFieldStyle(.plain)
                    .font(DS.Font.heading)
                    .onChange(of: name) { scheduleSave() }

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    DSToolbarButton(
                        icon: duplicated ? "checkmark" : "plus.square.on.square",
                        color: duplicated ? DS.Colors.success : DS.Colors.textSecondary,
                        size: DS.IconSize.sm
                    ) {
                        onDuplicate()
                        duplicated = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            await MainActor.run { duplicated = false }
                        }
                    }
                    .help("Duplicate skill")
                    .animation(DS.Animation.quick, value: duplicated)

                    if !skill.isBuiltIn {
                        DSToolbarButton(icon: "trash", color: DS.Colors.danger, size: DS.IconSize.sm) {
                            onDelete()
                        }
                    }

                    Divider().frame(height: 16)

                    Picker("", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 110)
                    .pointerOnHover()
                    .onChange(of: category) { scheduleSave() }

                    Button(action: onRun) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "play.fill")
                                .font(.system(size: DS.IconSize.xs))
                            Text("Run")
                                .font(DS.Font.small)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(DS.Colors.onAccent)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs + 2)
                        .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plainPointer)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.surfaceElevated)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    DSFieldLabel(label: "Background Instructions", hint: "Hidden context the AI reads before responding")
                    Spacer()
                    HStack(spacing: 2) {
                        Text("/")
                            .font(DS.Font.monoSmall)
                            .foregroundStyle(DS.Colors.textTertiary)
                        TextField(skill.commandName, text: $command)
                            .textFieldStyle(.plain)
                            .font(DS.Font.monoSmall)
                            .foregroundStyle(DS.Colors.textTertiary)
                            .lineLimit(1)
                            .frame(maxWidth: 130)
                            .onChange(of: command) { scheduleSave() }
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xs)

                Divider()

                TextEditor(text: $systemPrompt)
                    .font(DS.Font.monoSmall)
                    .scrollContentBackground(.hidden)
                    .frame(height: 80)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .onChange(of: systemPrompt) { scheduleSave() }

                Divider()

                DSFieldLabel(label: "Prompt Template", hint: "Optional — use {{input}} as placeholder for user input")
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.xs)

                MarkdownEditorWithToggle(
                    text: $promptTemplate,
                    placeholder: "Write what the skill should do with {{input}}...",
                    onSave: { saveSkill() }
                )
                .id(skill.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadSkill() }
        .onChange(of: skill.id) { loadSkill() }
    }

    private func loadSkill() {
        name = skill.name
        icon = skill.icon
        category = skill.category
        systemPrompt = skill.systemPrompt
        promptTemplate = skill.promptTemplate
        command = skill.command
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
            name: name, trigger: skill.trigger, icon: icon, model: skill.model,
            category: category, systemPrompt: systemPrompt, promptTemplate: promptTemplate,
            filePath: skill.filePath, isBuiltIn: skill.isBuiltIn, isPinned: skill.isPinned,
            command: command
        )
        SkillFileService.shared.save(skill: updated)
    }

    private func onDuplicate() {
        SkillFileService.shared.create(
            name: "\(name) Copy",
            category: category,
            icon: icon,
            systemPrompt: systemPrompt,
            promptTemplate: promptTemplate
        )
    }
}

// MARK: - Rule Inline Editor

private struct RuleInlineEditor: View {
    let rule: RuleFile
    let onDelete: () -> Void

    @State private var name: String = ""
    @State private var icon: String = ""
    @State private var trigger: String = ""
    @State private var category: String = ""
    @State private var instruction: String = ""
    @State private var isDisabled: Bool = false
    @State private var hasLoaded = false
    @State private var saveTask: Task<Void, Never>?
    @State private var showIconPicker = false

    private let categories = [
        "General",
        "Writing",
        "Productivity",
        "Development",
        "Communication",
        "Organization",
        "Analysis",
        "Knowledge",
        "Research",
        "Finance",
        "Design",
        "Data"
    ]

    private let icons = [
        "bolt", "bolt.circle", "exclamationmark.triangle", "checkmark.shield",
        "text.alignleft", "list.bullet", "doc.plaintext",
        "person.circle", "globe", "lock", "bell",
        "flag", "star", "heart", "tag"
    ]

    var body: some View {
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
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plainPointer)
                .popover(isPresented: $showIconPicker, arrowEdge: .bottom) {
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
                .pointerOnHover()
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

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(alignment: .center, spacing: DS.Spacing.xs) {
                    DSFieldLabel(label: "Trigger", hint: "When should this rule activate?")
                    Spacer()
                    TriggerHelpButton()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)

                TextField("e.g. always, tag:meeting, content:web", text: $trigger)
                    .textFieldStyle(.plain)
                    .font(DS.Font.mono)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xs)
                    .onChange(of: trigger) { scheduleSave() }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(TriggerHelpButton.quickPicks, id: \.value) { pick in
                            TriggerPickChip(label: pick.value) {
                                trigger = pick.value
                                scheduleSave()
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xs)
                }
            }
            .padding(.bottom, DS.Spacing.sm)

            Divider()

            MarkdownEditorWithToggle(
                text: $instruction,
                placeholder: "Write the instruction for Claude when this rule triggers...",
                onSave: { saveRule() }
            )
            .id(rule.id)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadRule() }
        .onChange(of: rule.id) { loadRule() }
    }

    private func loadRule() {
        name = rule.name
        icon = rule.icon
        trigger = rule.trigger
        category = rule.category
        instruction = rule.instruction
        isDisabled = rule.isDisabled
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
            name: name, trigger: trigger, icon: icon, category: category,
            instruction: instruction, filePath: rule.filePath, isBuiltIn: rule.isBuiltIn,
            isDisabled: isDisabled
        )
        RuleFileService.shared.save(rule: updated)
    }
}

// MARK: - Trigger Help

private struct TriggerHelpButton: View {
    @State private var showHelp = false

    static let quickPicks: [(value: String, label: String)] = [
        ("always", "Always active"),
        ("tag:meeting", "Tagged: meeting"),
        ("tag:work", "Tagged: work"),
        ("content:web", "Web content"),
        ("event:note_opened", "Note opened"),
        ("section:tasks", "Tasks section"),
        ("agent:researcher", "Agent: researcher")
    ]

    private let patterns: [(pattern: String, description: String, example: String)] = [
        ("always", "Applies in every AI conversation, no conditions.", "always"),
        ("tag:<name>", "Fires when a note is tagged with the given name.", "tag:meeting"),
        ("event:<name>", "Fires when a named event occurs in the app.", "event:note_opened"),
        ("agent:<name>", "Applies when a specific agent is active.", "agent:researcher"),
        ("content:<type>", "Targets a specific content type.", "content:web"),
        ("section:<name>", "Applies when you're inside a named section.", "section:tasks")
    ]

    var body: some View {
        Button { showHelp.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: DS.IconSize.sm))
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .buttonStyle(.plainPointer)
        .help("View trigger reference")
        .popover(isPresented: $showHelp, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Trigger Reference")
                    .font(DS.Font.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.textPrimary)

                ForEach(patterns, id: \.pattern) { item in
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack(spacing: DS.Spacing.sm) {
                            Text(item.pattern)
                                .font(DS.Font.monoSmall)
                                .foregroundStyle(DS.Colors.info)
                            Text("e.g. \(item.example)")
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        Text(item.description)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .frame(width: 340)
        }
    }
}

private struct TriggerPickChip: View {
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DS.Font.monoSmall)
                .foregroundStyle(isHovered ? DS.Colors.accent : DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xxs + 1)
                .background(isHovered ? DS.Colors.accentFill : DS.Colors.fill, in: Capsule())
                .overlay(Capsule().strokeBorder(isHovered ? DS.Colors.accent.opacity(0.3) : DS.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Skill Run Sheet

struct SkillRunSheet: View {
    @Environment(\.dismiss) private var dismiss
    let skill: SkillFile

    @State private var input = ""
    @State private var result: String?
    @State private var isRunning = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(DS.Colors.accentFill)
                        .frame(width: 28, height: 28)
                    Image(systemName: skill.icon)
                        .font(.system(size: DS.IconSize.sm, weight: .medium))
                        .foregroundStyle(DS.Colors.accent)
                }
                Text(skill.name)
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.IconSize.xs, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plainPointer)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.surfaceElevated)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    DSLabeledTextEditor(label: "Input", text: $input, minHeight: 90)

                    Button {
                        Task { await run() }
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            if isRunning {
                                ProgressView().controlSize(.small).tint(DS.Colors.onAccent)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: DS.IconSize.xs))
                            }
                            Text(isRunning ? "Running..." : "Run Skill")
                                .font(DS.Font.body).fontWeight(.semibold)
                        }
                        .foregroundStyle(DS.Colors.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm + 2)
                        .background(
                            (isRunning || input.isEmpty) ? DS.Colors.accent.opacity(0.5) : DS.Colors.accent,
                            in: RoundedRectangle(cornerRadius: DS.Radius.md)
                        )
                    }
                    .buttonStyle(.plainPointer)
                    .disabled(isRunning || input.isEmpty)

                    if let result {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack {
                                Text("Result")
                                    .font(DS.Font.small)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DS.Colors.textSecondary)
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(result, forType: .string)
                                    copied = true
                                    Task {
                                        try? await Task.sleep(for: .seconds(1.5))
                                        await MainActor.run { copied = false }
                                    }
                                } label: {
                                    HStack(spacing: DS.Spacing.xxs) {
                                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: DS.IconSize.xs))
                                        Text(copied ? "Copied" : "Copy")
                                            .font(DS.Font.small)
                                    }
                                    .foregroundStyle(copied ? DS.Colors.success : DS.Colors.textSecondary)
                                }
                                .buttonStyle(.plainPointer)
                                .animation(DS.Animation.quick, value: copied)
                            }

                            ChatMarkdownView(markdown: result)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
                    }
                }
                .padding(DS.Spacing.lg)
            }
        }
        .frame(width: 540, height: 580)
        .background(DS.Colors.surface)
    }

    @MainActor
    private func run() async {
        isRunning = true
        result = await SkillFileService.shared.execute(skill: skill, context: ["input": input])
        isRunning = false
    }
}
