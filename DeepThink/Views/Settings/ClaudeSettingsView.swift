import SwiftUI

struct ClaudeSettingsView: View {
    @State private var claude = ClaudeService.shared
    @State private var mcp = MCPService.shared

    @State private var showCLIDetails = false
    @State private var animateStatus = false
    @State private var commandsExpanded = false

    private struct CLICommandEntry {
        let name: String
        let path: String
        let description: String
    }

    private let cliCommands = [
        CLICommandEntry(
            name: "/deepthink",
            path: "~/.claude/commands/deepthink.md",
            description: "Universal assistant — routes any query to the right tool. Handles search, capture, " +
                "tasks, notes, projects, reminders, agents, skills, rules, and AI reasoning in one command."
        ),
        CLICommandEntry(
            name: "/deepthink:sync-session",
            path: "~/.claude/commands/deepthink/sync-session.md",
            description: "Capture the current Claude Code session to DeepThink. Reads git context, summarizes what " +
                "was worked on, decisions made, files changed, and open items, then stores it in the knowledge base."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                if !claude.isAvailable {
                    setupBanner
                }
                if claude.lastErrorKind == .rateLimited {
                    rateLimitBanner
                } else if claude.lastErrorKind == .noCredits {
                    noCreditsBanner
                }
                statusHero
                usageDashboard
                configurationSection

                cliSection
            }
            .padding(DS.Spacing.xl)
        }
        .dsPage()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animateStatus = true
            }
            mcp.checkGlobalMCPStatus()
        }
        .onDisappear {
            animateStatus = false
        }
    }

    // MARK: - Setup Banner

    private var setupBanner: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DS.Colors.warningFill)
                    .frame(width: 36, height: 36)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: DS.IconSize.lg))
                    .foregroundStyle(DS.Colors.warning)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Claude CLI Required")
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("Install to enable AI features.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            Spacer()

            Button {
                if let url = URL(string: "https://claude.ai/code") { NSWorkspace.shared.open(url) }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: DS.IconSize.sm))
                    Text("Install")
                        .font(DS.Font.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(DS.Colors.onAccent)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plainPointer)

            Button { selectCLIPath() } label: {
                Text("Browse...")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .buttonStyle(.plainPointer)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.warning.opacity(DS.Opacity.hover), in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.badgeBorder(DS.Colors.warning), lineWidth: 1))
    }

    // MARK: - Rate Limit Banner

    private var rateLimitBanner: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DS.Colors.warningFill)
                    .frame(width: 36, height: 36)
                Image(systemName: "timer")
                    .font(.system(size: DS.IconSize.lg))
                    .foregroundStyle(DS.Colors.warning)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Rate Limit Reached")
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("You've exceeded the Claude API rate limit. Wait a moment, then retry. Consider upgrading your plan for higher limits.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                if let url = URL(string: "https://console.anthropic.com/settings/limits") { NSWorkspace.shared.open(url) }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "gauge.with.needle")
                        .font(.system(size: DS.IconSize.sm))
                    Text("View Limits")
                        .font(DS.Font.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(DS.Colors.warning)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.warningFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.badgeBorder(DS.Colors.warning), lineWidth: 1))
            }
            .buttonStyle(.plainPointer)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.warning.opacity(DS.Opacity.hover), in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.badgeBorder(DS.Colors.warning), lineWidth: 1))
    }

    // MARK: - No Credits Banner

    private var noCreditsBanner: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DS.Colors.badgeFill(DS.Colors.danger))
                    .frame(width: 36, height: 36)
                Image(systemName: "creditcard.trianglebadge.exclamationmark")
                    .font(.system(size: DS.IconSize.lg))
                    .foregroundStyle(DS.Colors.danger)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Insufficient Credits")
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("Your Claude API account has run out of credits. Add credits at console.anthropic.com to resume AI features.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(spacing: DS.Spacing.xs) {
                Button {
                    if let url = URL(string: "https://console.anthropic.com/settings/billing") { NSWorkspace.shared.open(url) }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: DS.IconSize.sm))
                        Text("Add Credits")
                            .font(DS.Font.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(DS.Colors.onAccent)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plainPointer)

                Button {
                    if let url = URL(string: "https://console.anthropic.com/settings/plans") { NSWorkspace.shared.open(url) }
                } label: {
                    Text("View Plans")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(.plainPointer)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.danger.opacity(DS.Opacity.hover), in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.badgeBorder(DS.Colors.danger), lineWidth: 1))
    }

    // MARK: - Status Hero

    @ViewBuilder
    private var statusHero: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(claude.isAvailable ? DS.Colors.badgeFill(DS.Colors.success) : DS.Colors.badgeFill(DS.Colors.danger))
                    .frame(width: 44, height: 44)

                if claude.isAvailable {
                    Circle()
                        .fill(DS.Colors.success.opacity(animateStatus ? 0.2 : 0.06))
                        .frame(width: 44, height: 44)
                        .scaleEffect(animateStatus ? 1.2 : 1.0)
                }

                Image(systemName: claude.isAvailable ? "sparkles" : "xmark.circle.fill")
                    .font(.system(size: DS.IconSize.xl, weight: .medium))
                    .foregroundStyle(claude.isAvailable ? DS.Colors.success : DS.Colors.danger)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.sm) {
                    Text(claude.isAvailable ? "Claude Connected" : "Claude Not Found")
                        .font(DS.Font.heading)
                        .foregroundStyle(DS.Colors.textPrimary)

                    if claude.isProcessing {
                        HStack(spacing: 3) {
                            ProgressView().controlSize(.mini)
                            Text("Processing")
                                .font(DS.Font.micro)
                        }
                        .foregroundStyle(DS.Colors.warning)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(DS.Colors.warningFill, in: Capsule())
                    }
                }

                if claude.isAvailable {
                    HStack(spacing: DS.Spacing.md) {
                        HStack(spacing: 3) {
                            Image(systemName: "cpu")
                                .font(.system(size: DS.IconSize.xs))
                            Text(claude.modelDisplayName)
                                .font(DS.Font.caption)
                        }
                        .foregroundStyle(DS.Colors.accent)

                        if let version = claude.cliVersion {
                            HStack(spacing: 3) {
                                Image(systemName: "terminal")
                                    .font(.system(size: DS.IconSize.xs))
                                Text("CLI \(version)")
                                    .font(DS.Font.caption)
                            }
                            .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                } else {
                    Text("Install CLI from claude.ai/code")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }

            Spacer()

            if claude.isAvailable {
                Button { claude.rescan() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: DS.IconSize.sm, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: DS.Layout.iconButtonSize, height: DS.Layout.iconButtonSize)
                        .background(DS.Colors.fill, in: Circle())
                }
                .buttonStyle(.plainPointer)
                .help("Re-scan CLI")
            }
        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(
                    LinearGradient(
                        colors: [(claude.isAvailable ? DS.Colors.success : DS.Colors.danger).opacity(0.03), DS.Colors.transparent],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
        }
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))

        if let error = claude.lastError {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(DS.Colors.danger)
                Text(error)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.danger)
                    .lineLimit(2)
                Spacer()
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.danger.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }

    // MARK: - CLI Section (Path + Install + MCP)

    private var cliSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSectionHeader(title: "Claude CLI")
            cliPathRow
            mcpStatusSection
            troubleshootHints
        }
    }

    @State private var showTroubleshoot = false

    // MARK: - CLI Path (compact inline)

    private var cliPathRow: some View {
        VStack(spacing: DS.Spacing.sm) {
            Button {
                withAnimation(DS.Animation.standard) { showCLIDetails.toggle() }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "terminal")
                        .font(.system(size: DS.IconSize.sm, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)

                    Text(claude.claudePath.isEmpty ? "No CLI path" : claude.claudePath)
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: DS.IconSize.xs, weight: .bold))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .rotationEffect(.degrees(showCLIDetails ? 90 : 0))
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plainPointer)

            if showCLIDetails {
                HStack(spacing: DS.Spacing.sm) {
                    Button("Browse...") { selectCLIPath() }
                        .font(DS.Font.caption)
                        .buttonStyle(.dsSecondary)
                        .controlSize(.small)

                    Button("Re-scan") { claude.rescan() }
                        .font(DS.Font.caption)
                        .buttonStyle(.dsSecondary)
                        .controlSize(.small)

                    Spacer()

                    Text("~/.local/bin · /usr/local/bin · /opt/homebrew/bin")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - MCP Status

    private var mcpStatusSection: some View {
        VStack(spacing: 0) {
            installPathRow(
                icon: "terminal",
                iconColor: DS.Colors.accent,
                label: "CLI",
                path: MCPService.cliInstallPath,
                isInstalled: mcp.isCLIInstalled,
                version: mcp.cliVersion
            )

            Divider()

            installPathRow(
                icon: "puzzlepiece.extension",
                iconColor: DS.Colors.knowledge,
                label: "MCP",
                path: MCPService.mcpInstallPath,
                isInstalled: mcp.isMCPInstalled,
                version: mcp.mcpVersion
            )

            Divider()

            // Commands (collapsible)
            VStack(spacing: 0) {
                Button {
                    withAnimation(DS.Animation.standard) { commandsExpanded.toggle() }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "terminal")
                            .font(.system(size: DS.IconSize.sm, weight: .medium))
                            .foregroundStyle(DS.Colors.knowledge)
                            .frame(width: 20)
                        Text("Commands")
                            .font(DS.Font.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text("\(cliCommands.count)")
                            .font(DS.Font.micro)
                            .padding(.horizontal, DS.Spacing.xs4)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(DS.Colors.fillSecondary, in: Capsule())
                            .foregroundStyle(DS.Colors.textTertiary)
                        Spacer()
                        if mcp.isGlobalSkillInstalled {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: DS.IconSize.sm))
                                Text("Installed")
                                    .font(DS.Font.small)
                            }
                            .foregroundStyle(DS.Colors.success)
                        } else {
                            Button {
                                mcp.installGlobalSkill()
                            } label: {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: DS.IconSize.xs))
                                    Text("Install")
                                        .font(DS.Font.small)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(DS.Colors.onAccent)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                            }
                            .buttonStyle(.plainPointer)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: DS.IconSize.xs, weight: .bold))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .rotationEffect(.degrees(commandsExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plainPointer)

                if commandsExpanded {
                    ForEach(Array(cliCommands.enumerated()), id: \.offset) { _, entry in
                        Divider().padding(.leading, DS.Spacing.md)
                        commandRow(name: entry.name, path: entry.path, description: entry.description)
                    }
                }
            }

            Divider()

            // Global MCP registration row
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "globe")
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                    .foregroundStyle(DS.Colors.success)
                    .frame(width: 20)
                Text("Global")
                    .font(DS.Font.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .frame(width: 36, alignment: .leading)

                if mcp.isCheckingGlobalMCP {
                    Text("Checking…")
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                    Spacer()
                    ProgressView()
                        .controlSize(.mini)
                } else if mcp.isGlobalMCPRegistered {
                    Text("~/.claude.json")
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: DS.IconSize.sm))
                        Text("Registered")
                            .font(DS.Font.small)
                    }
                    .foregroundStyle(DS.Colors.success)
                } else {
                    Text("Not registered with Claude CLI")
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(DS.Colors.warning)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        mcp.registerGlobalMCP()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: DS.IconSize.xs))
                            Text("Register")
                                .font(DS.Font.small)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(DS.Colors.onAccent)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plainPointer)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
    }

    // MARK: - Troubleshoot Hints

    private var troubleshootHints: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Button {
                withAnimation(DS.Animation.standard) { showTroubleshoot.toggle() }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: DS.IconSize.xs))
                    Text("Troubleshooting")
                        .font(DS.Font.small)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.right")
                        .font(DS.Font.badge)
                        .rotationEffect(.degrees(showTroubleshoot ? 90 : 0))
                }
                .foregroundStyle(DS.Colors.textTertiary)
            }
            .buttonStyle(.plainPointer)

            if showTroubleshoot {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    TroubleshootRow(command: "claude --version", hint: "Verify CLI installed")
                    TroubleshootRow(command: "claude mcp list", hint: "Check registered MCP servers")
                    TroubleshootRow(command: "which deepthink-mcp", hint: "Verify MCP binary in PATH")
                    TroubleshootRow(command: "deepthink-mcp", hint: "Test MCP server runs (Ctrl+C to stop)")
                    TroubleshootRow(command: "cat ~/.claude.json | grep -A5 deepthink", hint: "Check MCP config entry")
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    // MARK: - Configuration (Model + Version + Tokens)

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSectionHeader(title: "Configuration")

            // Model family row
            HStack(spacing: DS.Spacing.sm) {
                ForEach(ClaudeService.ModelFamily.allCases) { family in
                    CompactModelCard(
                        family: family,
                        isSelected: claude.selectedModelFamily == family
                    ) {
                        withAnimation(DS.Animation.standard) {
                            claude.selectedModelFamily = family
                            claude.selectedModelVersion = family.latestVersion
                        }
                    }
                }
            }

            // Version + Specs + Tokens in one card
            VStack(spacing: 0) {
                // Version pills
                HStack(spacing: DS.Spacing.sm) {
                    Text("VERSION")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Colors.textTertiary)

                    ForEach(claude.selectedModelFamily.versions) { version in
                        VersionPill(
                            version: version,
                            isSelected: claude.selectedModelVersion == version
                        ) {
                            withAnimation(DS.Animation.quick) {
                                claude.selectedModelVersion = version
                            }
                        }
                    }

                    Spacer()

                    Button {
                        if let url = URL(string: "https://docs.anthropic.com/en/docs/about-claude/pricing") { NSWorkspace.shared.open(url) }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: DS.IconSize.xs))
                            Text(claude.fullModelID)
                                .font(DS.Font.monoSmall)
                        }
                        .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plainPointer)
                    .help("View pricing at docs.anthropic.com")
                }
                .padding(DS.Spacing.md)

                Divider()

                // Specs row
                HStack(spacing: 0) {
                    SpecChip(label: "Context", value: claude.selectedModelVersion.contextWindow, color: DS.Colors.textSecondary)
                    SpecChip(label: "Output", value: claude.selectedModelVersion.maxOutput, color: DS.Colors.textSecondary)
                    SpecChip(label: "In $/1M", value: claude.selectedModelVersion.inputCostPer1M, color: DS.Colors.textSecondary)
                    SpecChip(label: "Out $/1M", value: claude.selectedModelVersion.outputCostPer1M, color: DS.Colors.textSecondary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)

                Divider()

                // Max tokens
                HStack(spacing: DS.Spacing.md) {
                    Text("MAX TOKENS")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Colors.textTertiary)

                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(ClaudeService.maxTokenOptions, id: \.self) { option in
                            TokenOptionButton(
                                value: option,
                                isSelected: claude.maxTokens == option
                            ) {
                                withAnimation(DS.Animation.quick) {
                                    claude.maxTokens = option
                                }
                            }
                        }
                    }

                    Spacer()

                    Text(tokenDescription(claude.maxTokens))
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(DS.Spacing.md)
            }
            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
        }
    }

    // MARK: - Usage Dashboard

    private var usageDashboard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionHeader(title: "Usage")

            HStack(alignment: .top, spacing: DS.Spacing.md) {
                // Cost & performance
                VStack(spacing: 0) {
                    usageRow(
                        icon: "dollarsign.circle",
                        color: DS.Colors.success,
                        label: "Total Cost",
                        value: formatCost(claude.totalCostUSD),
                        note: claude.lastQueryCostUSD.map { "last \(formatCost($0))" }
                    )
                    Divider().padding(.leading, DS.Layout.settingsDividerInset)
                    usageRow(
                        icon: "bubble.left.and.bubble.right",
                        color: DS.Colors.accent,
                        label: "Queries",
                        value: "\(claude.totalQueries)",
                        note: claude.totalQueries > 0 ? "avg \(formatCost(claude.totalCostUSD / Double(claude.totalQueries)))" : nil
                    )
                    Divider().padding(.leading, DS.Layout.settingsDividerInset)
                    usageRow(
                        icon: "clock",
                        color: DS.Colors.warning,
                        label: "Avg Duration",
                        value: claude.totalQueries > 0 ? formatDuration(claude.totalDurationMs / Double(claude.totalQueries)) : "--",
                        note: claude.totalQueries > 0 ? {
                            let avg = claude.totalDurationMs / Double(claude.totalQueries)
                            return avg > 10000 ? "slow" : avg > 4000 ? "moderate" : "fast"
                        }() : nil
                    )
                    Divider().padding(.leading, DS.Layout.settingsDividerInset)
                    usageRow(
                        icon: "creditcard",
                        color: DS.Colors.knowledge,
                        label: "Cost / 1K Tokens",
                        value: (claude.totalInputTokens + claude.totalOutputTokens) > 0
                            ? formatCost(claude.totalCostUSD / Double(claude.totalInputTokens + claude.totalOutputTokens) * 1000)
                            : "--",
                        note: nil
                    )
                }
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))

                // Tokens
                VStack(spacing: 0) {
                    usageRow(
                        icon: "arrow.down.circle",
                        color: DS.Colors.knowledge,
                        label: "Input Tokens",
                        value: formatTokens(claude.totalInputTokens),
                        note: "all time"
                    )
                    Divider().padding(.leading, DS.Layout.settingsDividerInset)
                    usageRow(
                        icon: "arrow.up.circle",
                        color: DS.Colors.accent,
                        label: "Output Tokens",
                        value: formatTokens(claude.totalOutputTokens),
                        note: claude
                            .totalInputTokens > 0 ? "ratio \(String(format: "%.1f", Double(claude.totalOutputTokens) / Double(claude.totalInputTokens)))x" :
                            nil
                    )
                    Divider().padding(.leading, DS.Layout.settingsDividerInset)
                    usageRow(
                        icon: "bolt.circle",
                        color: DS.Colors.success,
                        label: "Cache Read",
                        value: formatTokens(claude.totalCacheReadTokens),
                        note: (claude.totalInputTokens + claude.totalCacheReadTokens) > 0
                            ? "\(Int(Double(claude.totalCacheReadTokens) / Double(claude.totalInputTokens + claude.totalCacheReadTokens) * 100))% hit rate"
                            : "no cache yet"
                    )
                    Divider().padding(.leading, DS.Layout.settingsDividerInset)
                    usageRow(
                        icon: "circle.grid.2x2",
                        color: DS.Colors.textSecondary,
                        label: "Total Tokens",
                        value: formatTokens(claude.totalInputTokens + claude.totalOutputTokens + claude.totalCacheReadTokens),
                        note: claude
                            .totalQueries > 0 ?
                            "\(formatTokens((claude.totalInputTokens + claude.totalOutputTokens) / max(1, claude.totalQueries)))/query avg" : nil
                    )
                }
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
            }
        }
    }

    private func usageRow(icon: String, color: Color, label: String, value: String, note: String?) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.xs, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.textSecondary)
            Spacer()
            if let note {
                Text(note)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            Text(value)
                .font(DS.Font.caption)
                .fontWeight(.medium)
                .foregroundStyle(DS.Colors.textPrimary)
                .monospacedDigit()
                .frame(minWidth: 48, alignment: .trailing)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Helpers

    private func installPathRow(icon: String, iconColor: Color, label: String, path: String, isInstalled: Bool, version: String? = nil) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.sm, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 20)
            Text(label)
                .font(DS.Font.caption)
                .fontWeight(.medium)
                .foregroundStyle(DS.Colors.textPrimary)
                .frame(width: 36, alignment: .leading)
            Text(path)
                .font(DS.Font.monoSmall)
                .foregroundStyle(isInstalled ? DS.Colors.textSecondary : DS.Colors.danger)
                .lineLimit(1)
            Spacer()
            if isInstalled {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: DS.IconSize.sm))
                    if let version {
                        Text("v\(version)")
                            .font(DS.Font.small)
                    } else {
                        Text("Installed")
                            .font(DS.Font.small)
                    }
                }
                .foregroundStyle(DS.Colors.success)
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: DS.IconSize.sm))
                    Text("Not Found")
                        .font(DS.Font.small)
                }
                .foregroundStyle(DS.Colors.danger)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }

    private func commandRow(name: String, path: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Text(name)
                    .font(DS.Font.monoSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.accent)
                Spacer()
                Text(path)
                    .font(DS.Font.monoSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .lineLimit(1)
            }
            Text(description)
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.fillSecondary.opacity(DS.Opacity.disabled))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func selectCLIPath() {
        let panel = NSOpenPanel()
        panel.title = "Select Claude CLI Binary"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            claude.customCLIPath = url.path
        }
    }

    private func formatCost(_ cost: Double) -> String {
        cost < 0.01 ? String(format: "$%.4f", cost) : String(format: "$%.2f", cost)
    }

    private func formatDuration(_ ms: Double) -> String {
        ms < 1000 ? String(format: "%.0fms", ms) : String(format: "%.1fs", ms / 1000)
    }

    private func formatTokens(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n) / 1_000_000)
            : n >= 1000 ? String(format: "%.1fK", Double(n) / 1000)
            : "\(n)"
    }

    private func tokenDescription(_ tokens: Int) -> String {
        switch tokens {
        case ...1024: "Quick answers"
        case ...4096: "Standard tasks"
        case ...8192: "Detailed analysis"
        default: "Full documents"
        }
    }
}

// MARK: - Compact Model Card

private struct CompactModelCard: View {
    let family: ClaudeService.ModelFamily
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: family.icon)
                    .font(.system(size: DS.IconSize.md, weight: .medium))
                    .foregroundStyle(isSelected ? family.color : DS.Colors.textSecondary)
                    .frame(width: DS.IconSize.xxl, height: DS.IconSize.xxl)

                VStack(alignment: .leading, spacing: 1) {
                    Text(family.rawValue)
                        .font(DS.Font.caption)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                    Text(family.tagline)
                        .font(DS.Font.micro)
                        .fontWeight(.regular)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                isSelected ? family.color.opacity(DS.Opacity.hover) : (isHovered ? DS.Colors.fillSecondary : DS.Colors.fill),
                in: RoundedRectangle(cornerRadius: DS.Radius.md)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(
                        isSelected ? family.color.opacity(0.35) : (isHovered ? DS.Colors.borderHover : DS.Colors.border),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
        .animation(DS.Animation.standard, value: isSelected)
    }
}

// MARK: - Version Pill

private struct VersionPill: View {
    let version: ClaudeService.ModelVersion
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text("v\(version.version)")
                    .font(DS.Font.small)
                    .fontWeight(isSelected ? .semibold : .regular)

                if version.isLatest {
                    Text("Latest")
                        .font(DS.Font.badge)
                        .foregroundStyle(DS.Colors.onAccent)
                        .padding(.horizontal, DS.Spacing.xs3)
                        .padding(.vertical, 1)
                        .background(version.family.color, in: Capsule())
                }

                if let suffix = version.suffix, suffix != "Latest" {
                    Text(suffix)
                        .font(.system(size: DS.IconSize.micro, weight: .medium))
                        .foregroundStyle(DS.Colors.warning)
                        .padding(.horizontal, DS.Spacing.xs3)
                        .padding(.vertical, 1)
                        .background(DS.Colors.warningFill, in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? version.family.color : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isSelected ? DS.Colors.badgeFill(version.family.color) : (isHovered ? DS.Colors.fill : DS.Colors.transparent),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(
                        isSelected ? DS.Colors.badgeBorder(version.family.color) : DS.Colors.transparent,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Spec Chip

private struct SpecChip: View {
    let label: String
    let value: String
    var color: Color = DS.Colors.textSecondary

    var body: some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(value)
                .font(DS.Font.heading)
                .foregroundStyle(color)
            Text(label)
                .font(DS.Font.micro)
                .fontWeight(.regular)
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Token Option Button

private struct TokenOptionButton: View {
    let value: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var label: String {
        value >= 1024 ? "\(value / 1024)K" : "\(value)"
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DS.Font.small)
                .foregroundStyle(isSelected ? DS.Colors.onAccent : DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    isSelected ? DS.Colors.accent : (isHovered ? DS.Colors.fillSecondary : DS.Colors.fill),
                    in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
        .animation(DS.Animation.quick, value: isSelected)
    }
}

// MARK: - Usage Stat Card

private struct UsageStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String?
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.sm, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(DS.Font.heading)
                .foregroundStyle(DS.Colors.textPrimary)
                .contentTransition(.numericText())

            Text(title)
                .font(DS.Font.micro)
                .fontWeight(.regular)
                .foregroundStyle(DS.Colors.textTertiary)
                .textCase(.uppercase)

            if let subtitle {
                Text(subtitle)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(
            isHovered ? DS.Colors.fillSecondary : DS.Colors.fill,
            in: RoundedRectangle(cornerRadius: DS.Radius.md)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(isHovered ? DS.Colors.borderHover : DS.Colors.border, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Troubleshoot Row

private struct TroubleshootRow: View {
    let command: String
    let hint: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(command)
                .font(DS.Font.monoSmall)
                .foregroundStyle(DS.Colors.accent)
                .textSelection(.enabled)
            Spacer()
            Text(hint)
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)
        }
    }
}
