import SwiftUI

struct IntegrationsView: View {
    @State private var selectedSubTab: IntegrationsSubTab = .mcpServers

    enum IntegrationsSubTab: String, CaseIterable {
        case mcpServers = "MCP Servers"
        case dataSources = "Data Sources"

        var icon: String {
            switch self {
            case .mcpServers: "server.rack"
            case .dataSources: "cylinder"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sub-tab bar
            HStack(spacing: DS.Spacing.sm) {
                ForEach(IntegrationsSubTab.allCases, id: \.rawValue) { tab in
                    DSTabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedSubTab == tab,
                        action: { selectedSubTab = tab }
                    )
                }
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.fill)

            Divider()

            switch selectedSubTab {
            case .mcpServers:
                ToolsHubView()
            case .dataSources:
                DataSourcesView()
            }
        }
    }
}

// MARK: - Data Sources View

private struct DataSourcesView: View {
    private let service = ContextService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                // Discovered sources
                DSSectionHeader(title: "Discovered Sources", count: service.sources.count)

                if service.sources.isEmpty {
                    DSEmptyState(
                        icon: "cylinder",
                        title: "No Data Sources",
                        subtitle: "Use the DeepThink CLI to capture context from your integrations."
                    )
                    .frame(maxHeight: 200)
                } else {
                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(service.sources) { source in
                            HStack(spacing: DS.Spacing.md) {
                                DSIconBadge(
                                    icon: source.icon,
                                    color: source.color,
                                    size: 32
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.name)
                                        .font(DS.Font.body)
                                        .fontWeight(.medium)

                                    HStack(spacing: DS.Spacing.sm) {
                                        Text("\(source.totalItems) items")
                                            .font(DS.Font.caption)
                                            .foregroundStyle(DS.Colors.textSecondary)

                                        Text("\(source.channels.count) channels")
                                            .font(DS.Font.caption)
                                            .foregroundStyle(DS.Colors.textTertiary)
                                    }
                                }

                                Spacer()

                                if let date = source.lastUpdated {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Last sync")
                                            .font(DS.Font.small)
                                            .foregroundStyle(DS.Colors.textTertiary)
                                        Text(date.relativeFormatted)
                                            .font(DS.Font.caption)
                                            .foregroundStyle(DS.Colors.textSecondary)
                                    }
                                }
                            }
                            .padding(DS.Spacing.md)
                            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                    }
                }

                Divider()

                // CLI capture instructions
                DSSectionHeader(title: "Capture Commands")

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("Use the DeepThink CLI to capture context from your tools and services:")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textSecondary)

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        cliExample("deepthink capture slack --channel general", description: "Capture Slack messages")
                        cliExample("deepthink capture github --repo org/repo", description: "Capture GitHub activity")
                        cliExample("deepthink capture web --url https://...", description: "Capture web content")
                    }

                    Text("Data is stored in ~/Documents/DeepThink/knowledge/integrations/")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(DS.Spacing.lg)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            }
            .padding(DS.Spacing.xl)
        }
        .onAppear { service.loadSources() }
    }

    @ViewBuilder
    private func cliExample(_ command: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(description)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.textSecondary)

            Text(command)
                .font(DS.Font.mono)
                .foregroundStyle(DS.Colors.accent)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .textSelection(.enabled)
        }
    }
}
