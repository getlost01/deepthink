import SwiftUI

struct ClaudeSettingsView: View {
    private var claude: ClaudeService { ClaudeService.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                if !claude.isAvailable {
                    setupBanner
                }
                statusCard
                cliPathSection
                modelSection
                configSection
                usageSection
            }
            .padding(DS.Spacing.xl)
        }
        .dsPage()
    }

    // MARK: - Setup Banner

    @ViewBuilder
    private var setupBanner: some View {
        VStack(spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: DS.IconSize.xxl))
                    .foregroundStyle(DS.Colors.warning)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Claude CLI Required")
                        .font(DS.Font.heading)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("DeepThink needs Claude CLI to power AI chat, knowledge extraction, auto-tagging, and search. Install it or select the path below.")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: DS.Spacing.md) {
                Button {
                    NSWorkspace.shared.open(URL(string: "https://claude.ai/code")!)
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: DS.IconSize.sm))
                        Text("Install Claude CLI")
                            .font(DS.Font.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(DS.Colors.onAccent)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plainPointer)

                Button {
                    selectCLIPath()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "folder")
                            .font(.system(size: DS.IconSize.sm))
                        Text("Select CLI Path")
                            .font(DS.Font.body)
                    }
                    .foregroundStyle(DS.Colors.textPrimary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plainPointer)

                Button {
                    claude.rescan()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: DS.IconSize.sm))
                        Text("Re-scan")
                            .font(DS.Font.body)
                    }
                    .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plainPointer)

                Spacer()
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.warning.opacity(0.3), lineWidth: 1))
    }

    // MARK: - CLI Path

    @ViewBuilder
    private var cliPathSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSectionHeader(title: "CLI Path")

            DSCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack {
                        Text("CURRENT PATH")
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                        Spacer()
                        if claude.isAvailable {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: DS.IconSize.sm))
                                    .foregroundStyle(DS.Colors.success)
                                Text("Found")
                                    .font(DS.Font.small)
                                    .foregroundStyle(DS.Colors.success)
                            }
                        } else {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: DS.IconSize.sm))
                                    .foregroundStyle(DS.Colors.danger)
                                Text("Not found")
                                    .font(DS.Font.small)
                                    .foregroundStyle(DS.Colors.danger)
                            }
                        }
                    }

                    Text(claude.claudePath.isEmpty ? "No CLI path configured" : claude.claudePath)
                        .font(DS.Font.mono)
                        .foregroundStyle(claude.isAvailable ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                        .textSelection(.enabled)
                        .padding(DS.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                    HStack(spacing: DS.Spacing.sm) {
                        Button("Browse...") { selectCLIPath() }
                            .font(DS.Font.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                        Button("Re-scan Default Paths") { claude.rescan() }
                            .font(DS.Font.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                        Spacer()

                        Text("Auto-checks: ~/.local/bin, /usr/local/bin, /opt/homebrew/bin")
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
            }
        }
    }

    private func selectCLIPath() {
        let panel = NSOpenPanel()
        panel.title = "Select Claude CLI Binary"
        panel.message = "Locate the 'claude' executable on your system"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            claude.customCLIPath = url.path
        }
    }

    // MARK: - Status Card

    @ViewBuilder
    private var statusCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(claude.isAvailable ? DS.Colors.success.opacity(0.15) : DS.Colors.danger.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: claude.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: DS.IconSize.lg, weight: .medium))
                            .foregroundStyle(claude.isAvailable ? DS.Colors.success : DS.Colors.danger)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: DS.Spacing.sm) {
                            Text(claude.isAvailable ? "Connected" : "Not Found")
                                .font(DS.Font.heading)
                                .foregroundStyle(DS.Colors.textPrimary)

                            if claude.isProcessing {
                                HStack(spacing: DS.Spacing.xs) {
                                    ProgressView()
                                        .controlSize(.mini)
                                    Text("Processing")
                                        .font(DS.Font.small)
                                }
                                .foregroundStyle(DS.Colors.warning)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, 2)
                                .background(DS.Colors.warning.opacity(0.1), in: Capsule())
                            }
                        }
                        Text(claude.isAvailable ? claude.modelDisplayName : "Install CLI from https://claude.ai/code")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }

                    Spacer()

                    if let version = claude.cliVersion {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("CLI")
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.textTertiary)
                                .textCase(.uppercase)
                            Text(version)
                                .font(DS.Font.monoSmall)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                }

                if let error = claude.lastError {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: DS.IconSize.sm))
                            .foregroundStyle(DS.Colors.warning)
                        Text(error)
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.danger)
                            .lineLimit(3)
                        Spacer()
                    }
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.danger.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
            }
        }
    }

    // MARK: - Model Selection

    @ViewBuilder
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSectionHeader(title: "Model")

            HStack(spacing: DS.Spacing.md) {
                ForEach(ClaudeService.ModelFamily.allCases) { family in
                    ModelFamilyCard(
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

            DSCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack {
                        Text("Version")
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                            .textCase(.uppercase)
                        Spacer()
                        Text(claude.fullModelID)
                            .font(DS.Font.monoSmall)
                            .foregroundStyle(DS.Colors.textTertiary)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: DS.Spacing.sm) {
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
                    }

                    Divider()

                    HStack(spacing: DS.Spacing.xl) {
                        ModelSpec(label: "Context", value: claude.selectedModelVersion.contextWindow, icon: "doc.text")
                        ModelSpec(label: "Max Output", value: claude.selectedModelVersion.maxOutput, icon: "text.alignleft")
                        ModelSpec(label: "Input", value: "\(claude.selectedModelVersion.inputCostPer1M)/1M", icon: "arrow.down.circle")
                        ModelSpec(label: "Output", value: "\(claude.selectedModelVersion.outputCostPer1M)/1M", icon: "arrow.up.circle")
                    }
                }
            }
        }
    }

    // MARK: - Configuration

    @ViewBuilder
    private var configSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSectionHeader(title: "Configuration")

            DSCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("MAX TOKENS")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)

                    HStack(spacing: DS.Spacing.sm) {
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
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Usage

    @ViewBuilder
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                DSSectionHeader(title: "Session Usage")
                Spacer()
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: DS.IconSize.sm))
                    Text("Since \(claude.sessionStartDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(DS.Font.small)
                }
                .foregroundStyle(DS.Colors.textTertiary)
            }

            HStack(spacing: DS.Spacing.md) {
                UsageStatCard(
                    title: "Queries",
                    value: "\(claude.totalQueries)",
                    icon: "bubble.left.and.bubble.right",
                    color: .blue
                )
                UsageStatCard(
                    title: "Total Cost",
                    value: formatCost(claude.totalCostUSD),
                    icon: "dollarsign.circle",
                    color: .green
                )
                UsageStatCard(
                    title: "Last Duration",
                    value: claude.lastQueryDurationMs.map { formatDuration($0) } ?? "--",
                    icon: "clock",
                    color: .orange
                )
                UsageStatCard(
                    title: "Avg Cost/Query",
                    value: claude.totalQueries > 0
                        ? formatCost(claude.totalCostUSD / Double(claude.totalQueries))
                        : "--",
                    icon: "chart.bar",
                    color: .blue
                )
            }
        }
    }

    // MARK: - Helpers

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        }
        return String(format: "$%.2f", cost)
    }

    private func formatDuration(_ ms: Double) -> String {
        if ms < 1000 {
            return String(format: "%.0fms", ms)
        }
        return String(format: "%.1fs", ms / 1000)
    }
}

// MARK: - Model Family Card

private struct ModelFamilyCard: View {
    let family: ClaudeService.ModelFamily
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: family.icon)
                    .font(.system(size: DS.IconSize.xxl, weight: .medium))
                    .foregroundStyle(isSelected ? family.color : DS.Colors.textSecondary)
                    .frame(height: 28)

                Text(family.rawValue)
                    .font(DS.Font.heading)
                    .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)

                Text(family.tagline)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
            .padding(.horizontal, DS.Spacing.sm)
            .background(
                isSelected
                    ? family.color.opacity(0.10)
                    : (isHovered ? DS.Colors.fill : DS.Colors.fillSecondary),
                in: RoundedRectangle(cornerRadius: DS.Radius.md)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(
                        isSelected ? family.color.opacity(0.4) : DS.Colors.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
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
            HStack(spacing: DS.Spacing.xs) {
                Text("v\(version.version)")
                    .font(DS.Font.caption)
                    .fontWeight(isSelected ? .semibold : .regular)

                if version.isLatest {
                    Text("Latest")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DS.Colors.onAccent)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 1)
                        .background(version.family.color, in: Capsule())
                }

                if let suffix = version.suffix {
                    Text(suffix)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(DS.Colors.warning)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(DS.Colors.warning.opacity(0.15), in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? version.family.color : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                isSelected
                    ? version.family.color.opacity(0.10)
                    : (isHovered ? DS.Colors.fill : DS.Colors.fillSecondary),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(
                        isSelected ? version.family.color.opacity(0.3) : DS.Colors.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Model Spec

private struct ModelSpec: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.sm))
                .foregroundStyle(DS.Colors.textTertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .textCase(.uppercase)
                Text(value)
                    .font(DS.Font.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
            }
        }
    }
}

// MARK: - Token Option Button

private struct TokenOptionButton: View {
    let value: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var label: String {
        if value >= 1024 {
            return "\(value / 1024)K"
        }
        return "\(value)"
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DS.Font.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    isSelected
                        ? DS.Colors.accent.opacity(0.10)
                        : (isHovered ? DS.Colors.fill : DS.Colors.fillSecondary),
                    in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .strokeBorder(
                            isSelected ? DS.Colors.accent.opacity(0.3) : DS.Colors.border,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Usage Stat Card

private struct UsageStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                    .foregroundStyle(color)
                Text(title)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .textCase(.uppercase)
            }

            Text(value)
                .font(DS.Font.heading)
                .foregroundStyle(DS.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Colors.border, lineWidth: 1)
        )
    }
}
