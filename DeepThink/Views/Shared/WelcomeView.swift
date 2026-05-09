import SwiftUI

struct WelcomeView: View {
    let onComplete: () -> Void
    @Environment(InstallationManager.self) private var installer
    @State private var currentStep = 0

    private let infoSteps: [WelcomeStep] = [
        WelcomeStep(
            icon: "brain.head.profile",
            title: "Welcome to DeepThink",
            subtitle: "A local-first AI workspace for macOS. Your projects, notes, knowledge, and AI — all in one place, all on your machine.",
            features: [],
            tag: nil
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
            tag: "Workspace"
        ),
        WelcomeStep(
            icon: "brain",
            title: "Build Your Knowledge Base",
            subtitle: "Feed DeepThink anything. It indexes everything and retrieves the right context when you need it.",
            features: [
                Feature(icon: "globe", title: "Web & URLs", description: "Save articles, docs, and pages from any URL"),
                Feature(icon: "folder.badge.plus", title: "Files & Folders", description: "Import local documents, codebases, and data"),
                Feature(icon: "arrow.down.circle", title: "Obsidian Import", description: "One-click vault import with wiki-link conversion"),
                Feature(icon: "timer", title: "Auto-collection", description: "RSS feeds, scripts, and folder watches — on a schedule")
            ],
            tag: "Knowledge"
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
            tag: "AI"
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
            tag: "Tools"
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
            tag: "Setup"
        )
    ]

    private var isSetupStep: Bool {
        currentStep == infoSteps.count
    }

    private var totalSteps: Int {
        infoSteps.count + 1
    }

    var body: some View {
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
                    InfoStepView(step: infoSteps[currentStep])
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
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index == currentStep ? DS.Colors.accent : DS.Colors.border)
                        .frame(width: index == currentStep ? 20 : 8, height: 8)
                        .animation(DS.Animation.quick, value: currentStep)
                }
            }

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
                    Button {
                        onComplete()
                    } label: {
                        Text("Get Started")
                            .font(DS.Font.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Colors.onAccent)
                            .padding(.horizontal, DS.Spacing.xxl)
                            .padding(.vertical, DS.Spacing.md)
                            .background(
                                installer.isComplete ? DS.Colors.accent : DS.Colors.border,
                                in: RoundedRectangle(cornerRadius: DS.Radius.md)
                            )
                    }
                    .buttonStyle(.plainPointer)
                    .disabled(!installer.isComplete)
                    .animation(DS.Animation.standard, value: installer.isComplete)
                } else {
                    Button {
                        withAnimation { currentStep += 1 }
                        if currentStep == infoSteps.count {
                            installer.install()
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(currentStep == infoSteps.count - 1 ? "Continue to Setup" : "Next")
                                .font(DS.Font.body)
                                .fontWeight(.semibold)
                            if currentStep < infoSteps.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: DS.IconSize.xs, weight: .bold))
                            }
                        }
                        .foregroundStyle(DS.Colors.onAccent)
                        .padding(.horizontal, DS.Spacing.xxl)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plainPointer)
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
            } else if let tag = infoSteps[min(currentStep, infoSteps.count - 1)].tag, !isSetupStep {
                Text(tag.uppercased())
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .tracking(1.2)
            } else {
                Color.clear.frame(height: 13)
            }
        }
        .padding(.bottom, DS.Spacing.xxl)
    }
}

// MARK: - Info Step

private struct InfoStepView: View {
    let step: WelcomeStep

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Image(systemName: step.icon)
                .font(DS.Font.hero)
                .foregroundStyle(DS.Colors.accent)
                .frame(height: 60)

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

            if !step.features.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(step.features.enumerated()), id: \.element.id) { index, feature in
                        if index > 0 {
                            Divider().padding(.leading, DS.Spacing.lg + 32 + DS.Spacing.lg)
                        }
                        HStack(spacing: DS.Spacing.lg) {
                            Image(systemName: feature.icon)
                                .font(.system(size: DS.IconSize.md, weight: .medium))
                                .foregroundStyle(DS.Colors.accent)
                                .frame(width: 32, height: 32)
                                .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

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
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm + 2)
                    }
                }
                .frame(maxWidth: 420)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.border, lineWidth: 0.5))
            }
        }
        .padding(.horizontal, DS.Spacing.xxl)
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

                Text(installer.isComplete
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
                Divider().padding(.leading, 52)
                InstallRow(label: "MCP server  →  ~/.local/bin/deepthink-mcp", state: installer.mcpState)
                Divider().padding(.leading, 52)
                InstallRow(label: "Register MCP with Claude", state: installer.mcpRegisterState)
                Divider().padding(.leading, 52)
                InstallRow(label: "Add ~/.local/bin to shell PATH", state: installer.pathState)
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
            stateIcon
                .frame(width: 20, height: 20)

            Text(label)
                .font(DS.Font.caption)
                .foregroundStyle(rowTextTone)
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

    private var rowTextTone: Color {
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
            ProgressView()
                .controlSize(.small)
                .frame(width: 20, height: 20)
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
}

private struct Feature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}
