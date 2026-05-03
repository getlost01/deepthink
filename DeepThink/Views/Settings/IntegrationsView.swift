import SwiftUI

enum IntegrationsTab: String, CaseIterable, Identifiable {
    case mcpServers = "MCP Servers"
    case agents = "Assistants"
    case skillsAndRules = "Automations"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .mcpServers: "puzzlepiece.extension"
        case .agents: "person.2.circle"
        case .skillsAndRules: "sparkles"
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
                case .skillsAndRules:
                    SkillsRulesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: appState.agentConfigTab) { _, newTab in
            if appState.selectedSection == .integrations {
                selectedTab = newTab == .agents ? .agents : .skillsAndRules
            }
        }
    }
}
