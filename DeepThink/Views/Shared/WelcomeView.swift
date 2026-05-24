import SwiftUI

struct WelcomeView: View {
    let onComplete: () -> Void
    @Environment(InstallationManager.self) private var installer
    @State private var currentStep = 0
    @FocusState private var isFocused: Bool

    private let steps: [WelcomeStep] = [
        WelcomeStep(
            icon: "brain.head.profile",
            title: "Welcome to DeepThink",
            subtitle: "A local-first AI workspace for macOS. Projects, notes, knowledge, and AI — all in one place, all on your machine.",
            features: [],
            tag: nil,
            color: DS.Colors.accent
        ),
        WelcomeStep(
            icon: "square.grid.2x2",
            title: "Organize Your Work",
            subtitle: "Everything lives in your Workspace — structured so AI always knows what you're working on.",
            features: [
                Feature(icon: "folder", title: "Projects", description: "Group notes, tasks, and context by project"),
                Feature(icon: "doc.text", title: "Rich Notes", description: "Markdown editor with backlinks, versions, and AI commands"),
                Feature(icon: "checklist", title: "Task Board", description: "Kanban board with priorities, story points, and due dates"),
                Feature(icon: "bell", title: "Reminders", description: "Timed reminders with native macOS notifications")
            ],
            tag: "Workspace",
            color: DS.Colors.info
        ),
        WelcomeStep(
            icon: "brain",
            title: "Build Your Knowledge Base",
            subtitle: "Feed DeepThink anything. It indexes everything and retrieves the right context when you need it.",
            features: [
                Feature(icon: "globe", title: "Web & URLs", description: "Save articles, docs, and pages from any URL"),
                Feature(icon: "folder.badge.plus", title: "Files & Folders", description: "Import local documents, codebases, and data"),
                Feature(icon: "arrow.down.circle", title: "Obsidian Import", description: "One-click vault import with wiki-link conversion"),
                Feature(icon: "network", title: "Context Graph", description: "Visual knowledge graph showing connections between your notes")
            ],
            tag: "Knowledge",
            color: DS.Colors.knowledge
        ),
        WelcomeStep(
            icon: "sparkles",
            title: "AI That Knows Your Work",
            subtitle: "Claude has full access to your workspace. Ask anything — it searches your notes, tasks, and knowledge automatically.",
            features: [
                Feature(
                    icon: "bubble.left.and.bubble.right",
                    title: "Streaming Chat",
                    description: "Claude with conversation history, edit branching, and auto-compaction"
                ),
                Feature(icon: "person.2.circle", title: "AI Agents", description: "Custom personas with knowledge scopes and model selection"),
                Feature(icon: "bolt", title: "Skills", description: "Slash-command automations with template variables and context injection"),
                Feature(icon: "text.quote", title: "Rules", description: "Context-aware instructions that apply automatically based on what you're doing")
            ],
            tag: "AI",
            color: DS.Colors.amber
        ),
        WelcomeStep(
            icon: "puzzlepiece.extension",
            title: "Connected to Your Dev Stack",
            subtitle: "DeepThink ships a full MCP server — give Claude Code, Cursor, or any AI tool direct access to your workspace.",
            features: [
                Feature(icon: "terminal", title: "Built-in Terminal", description: "Multi-tab terminal with AI-powered output analysis"),
                Feature(icon: "bolt.fill", title: "Quick Capture", description: "Option+Space from any app — save notes, knowledge, or tasks in seconds"),
                Feature(icon: "magnifyingglass", title: "Command Palette", description: "Cmd+K — navigate, run skills, and find anything instantly"),
                Feature(icon: "server.rack", title: "MCP Server", description: "Bundled MCP server for Claude Code, Cursor, VS Code, and any MCP client")
            ],
            tag: "Tools",
            color: DS.Colors.success
        ),
        WelcomeStep(
            icon: "key.fill",
            title: "One Prerequisite: Claude CLI",
            subtitle: "DeepThink uses the Claude CLI for all AI features. You'll need it installed and logged in before the AI chat works.",
            features: [
                Feature(icon: "1.circle", title: "Install Claude CLI", description: "Visit claude.ai/code — download the macOS installer and run it"),
                Feature(icon: "2.circle", title: "Log in", description: "Run `claude login` in Terminal and follow the prompts"),
                Feature(icon: "3.circle", title: "That's it", description: "DeepThink will find Claude automatically after installation")
            ],
            tag: "Setup",
            color: DS.Colors.purple
        )
    ]

    private var isSetupStep: Bool {
        currentStep == steps.count
    }

    private var totalSteps: Int {
        steps.count + 1
    }

    private var currentColor: Color {
        isSetupStep ? DS.Colors.success : steps[currentStep].color
    }

    var body: some View {
        ZStack {
            currentColor
                .opacity(DS.Opacity.decorative)
                .ignoresSafeArea()
                .animation(DS.Animation.standard, value: currentStep)

            VStack(spacing: 0) {
                Spacer()

                Group {
                    if isSetupStep {
                        SetupStepView(installer: installer)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity
                            ))
                    } else {
                        InfoStepView(step: steps[currentStep])
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                            .id(currentStep)
                    }
                }
                .animation(.easeInOut(duration: 0.28), value: currentStep)

                Spacer()

                bottomBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DS.Colors.page)
        .focusable()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.leftArrow) {
            if currentStep > 0 { withAnimation { currentStep -= 1 } }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard currentStep < totalSteps - 1 else { return .handled }
            withAnimation { currentStep += 1 }
            if currentStep == steps.count { installer.install() }
            return .handled
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < -40 {
                        guard currentStep < totalSteps - 1 else { return }
                        withAnimation { currentStep += 1 }
                        if currentStep == steps.count { installer.install() }
                    } else if value.translation.width > 40 {
                        if currentStep > 0 { withAnimation { currentStep -= 1 } }
                    }
                }
        )
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Button {
                        withAnimation { currentStep = index }
                        if index == steps.count { installer.install() }
                    } label: {
                        Capsule()
                            .fill(index == currentStep ? currentColor : DS.Colors.border)
                            .frame(width: index == currentStep ? 20 : 8, height: 8)
                    }
                    .buttonStyle(.plainPointer)
                    .animation(DS.Animation.quick, value: currentStep)
                }
            }

            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Colors.textTertiary)

            HStack(spacing: DS.Spacing.lg) {
                if currentStep > 0, !isSetupStep {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .buttonStyle(.plainPointer)
                }

                if isSetupStep {
                    Button { onComplete() } label: {
                        Text("Get Started")
                            .font(DS.Font.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Colors.onAccent)
                            .padding(.horizontal, DS.Spacing.xxl)
                            .padding(.vertical, DS.Spacing.md)
                            .background(
                                installer.isComplete ? DS.Colors.success : DS.Colors.border,
                                in: RoundedRectangle(cornerRadius: DS.Radius.md)
                            )
                    }
                    .buttonStyle(.plainPointer)
                    .disabled(!installer.isComplete)
                    .animation(DS.Animation.standard, value: installer.isComplete)
                } else {
                    Button {
                        withAnimation { currentStep += 1 }
                        if currentStep == steps.count { installer.install() }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(currentStep == steps.count - 1 ? "Continue to Setup" : "Next")
                                .font(DS.Font.body)
                                .fontWeight(.semibold)
                            if currentStep < steps.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: DS.IconSize.xs, weight: .bold))
                            }
                        }
                        .foregroundStyle(DS.Colors.onAccent)
                        .padding(.horizontal, DS.Spacing.xxl)
                        .padding(.vertical, DS.Spacing.md)
                        .background(currentColor, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plainPointer)
                    .animation(DS.Animation.standard, value: currentStep)
                }
            }

            if currentStep == 0 {
                Button("Skip intro") {
                    installer.install()
                    onComplete()
                }
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.textTertiary)
                .buttonStyle(.plainPointer)
            } else if let tag = steps[min(currentStep, steps.count - 1)].tag, !isSetupStep {
                HStack(spacing: DS.Spacing.xs) {
                    Text("← → to navigate")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text("·")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text(tag.uppercased())
                        .font(DS.Font.micro)
                        .foregroundStyle(currentColor.opacity(0.8))
                        .tracking(1.2)
                }
            } else {
                DS.Colors.transparent.frame(height: 13)
            }
        }
        .padding(.bottom, DS.Spacing.xxl)
    }
}

// MARK: - Info Step

private struct InfoStepView: View {
    let step: WelcomeStep
    @State private var pulse = false
    @State private var hoveredFeature: UUID?

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            heroIcon
            heading
            if !step.features.isEmpty { featureList }
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .onAppear { pulse = true }
    }

    /// Animated orb on hero slide, plain icon on feature slides
    private var heroIcon: some View {
        ZStack {
            if step.features.isEmpty {
                Circle()
                    .fill(step.color.opacity(pulse ? 0.09 : 0.04))
                    .frame(width: pulse ? 128 : 108)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .fill(step.color.opacity(pulse ? 0.14 : 0.08))
                    .frame(width: pulse ? 92 : 78)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.4), value: pulse)
            }

            Image(systemName: step.icon)
                .font(DS.Font.hero)
                .foregroundStyle(step.color)
                .frame(height: 60)
        }
        .frame(height: 90)
    }

    private var heading: some View {
        VStack(spacing: DS.Spacing.md) {
            Text(step.title)
                .font(DS.Font.display)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(step.subtitle)
                .font(DS.Font.body)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
    }

    private var featureList: some View {
        VStack(spacing: 0) {
            ForEach(Array(step.features.enumerated()), id: \.element.id) { index, feature in
                if index > 0 {
                    Divider().padding(.leading, DS.Spacing.lg + 32 + DS.Spacing.lg)
                }
                FeatureRow(feature: feature, color: step.color, isHovered: hoveredFeature == feature.id)
                    .onHover { hovering in
                        withAnimation(DS.Animation.quick) {
                            hoveredFeature = hovering ? feature.id : nil
                        }
                    }
            }
        }
        .frame(maxWidth: 420)
        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(
                    hoveredFeature != nil ? DS.Colors.borderHover : DS.Colors.border,
                    lineWidth: 0.5
                )
        )
        .animation(DS.Animation.quick, value: hoveredFeature)
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let feature: Feature
    let color: Color
    let isHovered: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            Image(systemName: feature.icon)
                .font(.system(size: DS.IconSize.md, weight: .medium))
                .foregroundStyle(isHovered ? color : color.opacity(0.8))
                .frame(width: 32, height: 32)
                .background(
                    color.opacity(isHovered ? DS.Opacity.subtle : 0.10),
                    in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                )
                .animation(DS.Animation.quick, value: isHovered)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(feature.title)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(feature.description)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            Spacer()

            if isHovered {
                Image(systemName: "checkmark")
                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
                    .foregroundStyle(color)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm + 2)
        .background(
            isHovered ? DS.Colors.badgeFill(color) : DS.Colors.transparent,
            in: Rectangle()
        )
    }
}

// MARK: - Setup Step

private struct SetupStepView: View {
    let installer: InstallationManager

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Image(systemName: installer.isComplete ? "checkmark.circle.fill" : "gearshape.2.fill")
                .font(DS.Font.hero)
                .foregroundStyle(installer.isComplete ? DS.Colors.success : DS.Colors.accent)
                .frame(height: 60)
                .animation(DS.Animation.standard, value: installer.isComplete)

            VStack(spacing: DS.Spacing.md) {
                Text(installer.isComplete ? "You're all set!" : "Setting up DeepThink")
                    .font(DS.Font.display)
                    .foregroundStyle(DS.Colors.textPrimary)

                Text(
                    installer.isComplete
                        ? "CLI and MCP server are installed. Type `deepthink` in any terminal to get started."
                        : "Installing command-line tools to your system…"
                )
                .font(DS.Font.body)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            }

            VStack(spacing: 0) {
                InstallRow(label: "DeepThink CLI  →  ~/.local/bin/deepthink", state: installer.cliState)
                Divider().padding(.leading, DS.Layout.welcomeDividerInset)
                InstallRow(label: "MCP server  →  ~/.local/bin/deepthink-mcp", state: installer.mcpState)
                Divider().padding(.leading, DS.Layout.welcomeDividerInset)
                InstallRow(label: "Register MCP with Claude", state: installer.mcpRegisterState)
                Divider().padding(.leading, DS.Layout.welcomeDividerInset)
                InstallRow(label: "Add ~/.local/bin to shell PATH", state: installer.pathState)
                Divider().padding(.leading, DS.Layout.welcomeDividerInset)
                InstallRow(label: "Claude Code commands  →  ~/.claude/commands/deepthink/", state: installer.commandsState)
            }
            .frame(maxWidth: 440)
            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.border, lineWidth: 0.5))
        }
    }
}

// MARK: - Install Row

private struct InstallRow: View {
    let label: String
    let state: InstallationManager.StepState

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            stateIcon.frame(width: 20, height: 20)

            Text(label)
                .font(DS.Font.caption)
                .foregroundStyle(rowTextColor)
                .monospacedDigit()

            Spacer()

            if case let .failed(msg) = state {
                Text(msg)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Colors.warning)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm + 2)
        .animation(DS.Animation.standard, value: stateLabel)
    }

    private var rowTextColor: Color {
        switch state {
        case .done: DS.Colors.textPrimary
        case .failed: DS.Colors.warning
        default: DS.Colors.textSecondary
        }
    }

    private var stateLabel: String {
        switch state {
        case .pending: "pending"
        case .running: "running"
        case .done: "done"
        case .skipped: "skipped"
        case .failed: "failed"
        }
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .pending:
            Circle()
                .fill(DS.Colors.border)
                .frame(width: 8, height: 8)
                .frame(width: 20, height: 20)
        case .running:
            ProgressView().controlSize(.small).frame(width: 20, height: 20)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: DS.IconSize.sm, weight: .semibold))
                .foregroundStyle(DS.Colors.success)
        case .skipped:
            Image(systemName: "minus.circle")
                .font(.system(size: DS.IconSize.sm))
                .foregroundStyle(DS.Colors.textTertiary)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: DS.IconSize.sm))
                .foregroundStyle(DS.Colors.warning)
        }
    }
}

// MARK: - Models

private struct WelcomeStep {
    let icon: String
    let title: String
    let subtitle: String
    let features: [Feature]
    let tag: String?
    let color: Color
}

private struct Feature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}
