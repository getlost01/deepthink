import SwiftUI

struct ClaudeSettingsView: View {
    private var claude: ClaudeService { ClaudeService.shared }
    private var mcp: MCPService { MCPService.shared }
    @State private var showCLIDetails = false
    @State private var animateStatus = false

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
                cliPathRow
                mcpStatusSection
                configurationSection
                usageDashboard
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
    }

    // MARK: - Setup Banner

    @ViewBuilder
    private var setupBanner: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DS.Colors.warning.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: DS.IconSize.lg))
                    .foregroundStyle(DS.Colors.warning)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Claude CLI Required")
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("Install to enable AI features.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            Spacer()

            Button {
                NSWorkspace.shared.open(URL(string: "https://claude.ai/code")!)
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
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.warning.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Rate Limit Banner

    @ViewBuilder
    private var rateLimitBanner: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DS.Colors.warning.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "timer")
                    .font(.system(size: DS.IconSize.lg))
                    .foregroundStyle(DS.Colors.warning)
            }

            VStack(alignment: .leading, spacing: 2) {
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
                NSWorkspace.shared.open(URL(string: "https://console.anthropic.com/settings/limits")!)
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
                .background(DS.Colors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.warning.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plainPointer)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.warning.opacity(DS.Opacity.hover), in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.warning.opacity(0.25), lineWidth: 1))
    }

    // MARK: - No Credits Banner

    @ViewBuilder
    private var noCreditsBanner: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DS.Colors.danger.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "creditcard.trianglebadge.exclamationmark")
                    .font(.system(size: DS.IconSize.lg))
                    .foregroundStyle(DS.Colors.danger)
            }

            VStack(alignment: .leading, spacing: 2) {
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
                    NSWorkspace.shared.open(URL(string: "https://console.anthropic.com/settings/billing")!)
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
                    NSWorkspace.shared.open(URL(string: "https://console.anthropic.com/settings/plans")!)
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
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.danger.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Status Hero

    @ViewBuilder
    private var statusHero: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(claude.isAvailable ? DS.Colors.success.opacity(0.12) : DS.Colors.danger.opacity(0.12))
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

            VStack(alignment: .leading, spacing: 2) {
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
                        .padding(.vertical, 2)
                        .background(DS.Colors.warning.opacity(0.1), in: Capsule())
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
                        .frame(width: 28, height: 28)
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
                        colors: [(claude.isAvailable ? DS.Colors.success : DS.Colors.danger).opacity(0.03), .clear],
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

    // MARK: - CLI Path (compact inline)

    @ViewBuilder
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
                        .font(.system(size: 8, weight: .bold))
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

    @ViewBuilder
    private var mcpStatusSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSectionHeader(title: "Installation Paths")

            VStack(spacing: DS.Spacing.sm) {
                installPathRow(
                    icon: "terminal",
                    iconColor: DS.Colors.accent,
                    label: "CLI",
                    path: MCPService.cliInstallPath,
                    isInstalled: mcp.isCLIInstalled
                )

                Divider()

                installPathRow(
                    icon: "puzzlepiece.extension",
                    iconColor: DS.Colors.knowledge,
                    label: "MCP",
                    path: MCPService.mcpInstallPath,
                    isInstalled: mcp.isMCPInstalled
                )
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))

            // Global MCP registration status
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    Text("Global MCP Registration")
                        .font(DS.Font.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Spacer()
                    if mcp.isGlobalMCPRegistered {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: DS.IconSize.sm))
                            Text("Connected")
                                .font(DS.Font.small)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(DS.Colors.success)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: DS.IconSize.sm))
                            Text("Not Connected")
                                .font(DS.Font.small)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(DS.Colors.warning)
                    }
                }

                if !mcp.isGlobalMCPRegistered {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("DeepThink MCP server is not registered with Claude CLI. Register it globally so Claude can access your workspace from any directory.")
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Manual setup:")
                                .font(DS.Font.small)
                                .fontWeight(.medium)
                                .foregroundStyle(DS.Colors.textTertiary)
                            Text("claude mcp add --transport stdio --scope user deepthink -- \(MCPService.mcpInstallPath)")
                                .font(DS.Font.monoSmall)
                                .foregroundStyle(DS.Colors.accent)
                                .textSelection(.enabled)
                                .padding(DS.Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }

                        Button {
                            mcp.registerGlobalMCP()
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "link.badge.plus")
                                    .font(.system(size: DS.IconSize.sm))
                                Text("Register Now")
                                    .font(DS.Font.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(DS.Colors.onAccent)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plainPointer)
                    }
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.warning.opacity(DS.Opacity.hover), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.warning.opacity(0.25), lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Configuration (Model + Version + Tokens)

    @ViewBuilder
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

                    Text(claude.fullModelID)
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .textSelection(.enabled)
                }
                .padding(DS.Spacing.md)

                Divider()

                // Specs row
                HStack(spacing: 0) {
                    SpecChip(label: "Context", value: claude.selectedModelVersion.contextWindow, color: DS.Colors.accent)
                    SpecChip(label: "Output", value: claude.selectedModelVersion.maxOutput, color: DS.Colors.success)
                    SpecChip(label: "In $/1M", value: claude.selectedModelVersion.inputCostPer1M, color: DS.Colors.warning)
                    SpecChip(label: "Out $/1M", value: claude.selectedModelVersion.outputCostPer1M, color: DS.Colors.danger)
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
            .background(.background, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
        }
    }

    // MARK: - Usage Dashboard

    @ViewBuilder
    private var usageDashboard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                DSSectionHeader(title: "Session Usage")
                Spacer()
                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(DS.Colors.success)
                        .frame(width: 5, height: 5)
                    Text("Since \(claude.sessionStartDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(DS.Font.small)
                }
                .foregroundStyle(DS.Colors.textTertiary)
            }

            HStack(spacing: DS.Spacing.md) {
                UsageStatCard(title: "Queries", value: "\(claude.totalQueries)", icon: "bubble.left.and.bubble.right", color: DS.Colors.accent)
                UsageStatCard(title: "Total Cost", value: formatCost(claude.totalCostUSD), icon: "dollarsign.circle", color: DS.Colors.success)
                UsageStatCard(title: "Last Duration", value: claude.lastQueryDurationMs.map { formatDuration($0) } ?? "--", icon: "clock", color: DS.Colors.warning)
                UsageStatCard(title: "Avg/Query", value: claude.totalQueries > 0 ? formatCost(claude.totalCostUSD / Double(claude.totalQueries)) : "--", icon: "chart.bar", color: DS.Colors.knowledge)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func installPathRow(icon: String, iconColor: Color, label: String, path: String, isInstalled: Bool) -> some View {
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
                    Text("Installed")
                        .font(DS.Font.small)
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

    private func tokenDescription(_ tokens: Int) -> String {
        switch tokens {
        case ...1024: return "Quick answers"
        case ...4096: return "Standard tasks"
        case ...8192: return "Detailed analysis"
        default: return "Full documents"
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
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(DS.Colors.onAccent)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(version.family.color, in: Capsule())
                }

                if let suffix = version.suffix, suffix != "Latest" {
                    Text(suffix)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(DS.Colors.warning)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(DS.Colors.warning.opacity(0.15), in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? version.family.color : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isSelected ? version.family.color.opacity(0.10) : (isHovered ? DS.Colors.fill : .clear),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(isSelected ? version.family.color.opacity(0.3) : .clear, lineWidth: 1)
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
        VStack(spacing: 2) {
            Text(value)
                .font(DS.Font.caption)
                .fontWeight(.semibold)
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
