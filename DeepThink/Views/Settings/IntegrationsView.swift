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
        .dsPage()
        .onAppear { consumePendingTab() }
        .onChange(of: appState.agentConfigTab) { _, _ in
            consumePendingTab()
        }
    }

    // Callers set `agentConfigTab` before navigating here, so the view doesn't exist yet
    // when it changes — the request has to be consumed on appear too, and cleared so a
    // later plain navigation doesn't re-apply a stale tab.
    private func consumePendingTab() {
        guard let requested = appState.agentConfigTab else { return }
        switch requested {
        case .agents: selectedTab = .agents
        case .skills: selectedTab = .skills
        case .rules: selectedTab = .rules
        }
        appState.agentConfigTab = nil
    }
}
