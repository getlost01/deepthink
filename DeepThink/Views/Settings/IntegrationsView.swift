import SwiftUI

enum IntegrationsTab: String, CaseIterable, Identifiable {
    case mcpServers = "MCP Servers"
    case agents = "Assistants"
    case skills = "Skills"
    case rules = "Rules"

    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .mcpServers: "puzzlepiece.extension"
        case .agents: "person.2.circle"
        case .skills: "sparkles"
        case .rules: "bolt"
        }
    }
}

struct IntegrationsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: IntegrationsTab = .mcpServers

    var body: some View {
        VStack(spacing: 0) {
            DSToolbarBar {
                ForEach(IntegrationsTab.allCases) { tab in
                    DSTabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(DS.Animation.quick) {
                            selectedTab = tab
                        }
                    }
                }
                Spacer()
            }

            Divider()

            Group {
                switch selectedTab {
                case .mcpServers:
                    ToolsHubView()
                case .agents:
                    AgentListView()
                case .skills:
                    SkillsListView()
                case .rules:
                    RulesListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: appState.agentConfigTab) { _, newTab in
            if appState.selectedSection == .integrations {
                switch newTab {
                case .agents: selectedTab = .agents
                case .skills: selectedTab = .skills
                case .rules: selectedTab = .rules
                }
            }
        }
    }
}
